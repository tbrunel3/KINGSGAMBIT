extends Control
##
## BATAILLE - une seule scene, trois phases : PLACEMENT, COMBAT, RESULTAT.
##
## Une scene unique plutot que trois : l'etat du placement n'a ainsi jamais a
## transiter entre deux scenes, et le moteur de combat est construit une fois.
##
## Ce fichier ne contient aucune regle de combat : il place les unites, appelle
## engine.step() en boucle, et rejoue les evenements retournes. La vitesse
## (x1 / x2 / x4 / Pause) n'agit que sur les durees d'affichage.
##

enum Phase { PLACEMENT, COMBAT, RESULT }

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const CardScene := preload("res://scenes/ui/components/card.tscn")
const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")
const SelectionChipScene := preload("res://scenes/ui/components/selection_chip.tscn")

@onready var _tour_badge: PanelContainer = $Safe/Overlay/TourBadge
@onready var _phase_prefix: Label = $Safe/Overlay/TourBadge/TourRow/PhasePrefixLabel
@onready var _phase_label: Label = $Safe/Overlay/TourBadge/TourRow/PhaseLabel
@onready var _quit_button: Button = $Safe/Overlay/QuitButton
@onready var _grid_view: Control = $Safe/Overlay/Grid
@onready var _stats_hud: PanelContainer = $Safe/Overlay/StatsHud
@onready var _stats_box: VBoxContainer = $Safe/Overlay/StatsHud/StatsBox
@onready var _bottom_panel: PanelContainer = $Safe/Overlay/BottomPanel
@onready var _bottom: VBoxContainer = $Safe/Overlay/BottomPanel/BottomBox

var _battle: Dictionary = {}
var _engine: BattleEngine = null
var _phase: int = Phase.PLACEMENT
var _turn_activations: int = 0
var _combat_unit_count: int = 1

# Placement
var _remaining: Dictionary = {}   # type -> unites encore disponibles
var _selected_type: String = ""
var _placed: Array = []           # BattleUnit du joueur poses sur la grille

# Combat
var _speed: float = 1.0
var _paused: bool = false
var _running: bool = false

# "Fin tour" (cf. Btn-EndTurn Figma 05) : avance instantanement jusqu'a la fin
# de l'activation de tour en cours, puis revient a la vitesse choisie.
var _fast_forward_target_turn: int = -1
var _speed_before_fast_forward: float = 1.0

# Elements rafraichis souvent, gardes sous la main.
var _status_label: Label = null
var _type_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _fight_button: Button = null


func _ready() -> void:
	_battle = Router.current_battle()
	if _battle.is_empty():
		Router.goto_village()
		return

	_style_stats_hud()
	_quit_button.add_theme_font_size_override("font_size", 13)
	_quit_button.pressed.connect(_on_quit)

	_engine = BattleEngine.new(int(_battle["cols"]), int(_battle["rows"]))
	_spawn_enemies()

	for type in Balance.UNIT_TYPES:
		_remaining[type] = Game.units_owned(type)

	_grid_view.setup(_engine)
	_grid_view.cell_clicked.connect(_on_cell_clicked)

	_enter_placement()


## Badge de tour (haut-gauche) : bleu "PHASE DE PLACEMENT" pendant la pose,
## or "TOUR N" pendant le combat - couleurs et tailles reprises telles quelles
## de la maquette Figma (Tour-Badge, ecrans 04 et 05), border+ombre incluses.
func _style_tour_badge(bg: Color, border: Color, radius: int, prefix_color: Color, prefix_size: int,
		main_color: Color, main_size: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	_tour_badge.add_theme_stylebox_override("panel", box)

	_phase_prefix.add_theme_color_override("font_color", prefix_color)
	_phase_prefix.add_theme_font_size_override("font_size", prefix_size)
	_phase_prefix.add_theme_font_override("font", UiTheme.font_bold())
	_phase_label.add_theme_color_override("font_color", main_color)
	_phase_label.add_theme_font_size_override("font_size", main_size)
	_phase_label.add_theme_font_override("font", UiTheme.font_bold())


func _style_placement_badge() -> void:
	_style_tour_badge(UiTheme.ACCENT, Color("1a66b2", 0.7), 12,
		Color.WHITE, 10, Color.WHITE, 13)
	_phase_prefix.text = "PHASE DE"
	_phase_label.text = "PLACEMENT"
	_tour_badge.custom_minimum_size = Vector2(169, 35)
	_tour_badge.size = Vector2(169, 35)


func _style_combat_badge() -> void:
	_style_tour_badge(UiTheme.GOLD, Color("d9a600", 0.7), 14,
		UiTheme.GOLD_TEXT, 13, Color("331a00"), 18)
	_phase_prefix.text = "TOUR"
	_tour_badge.custom_minimum_size = Vector2(86, 41)
	_tour_badge.size = Vector2(86, 41)


## Panneau lateral (Stats-HUD, ecrans 04 et 05) : meme habillage sombre
## translucide dans les deux phases, seul le contenu (Body) change.
func _style_stats_hud() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0d0f1a", 0.75)
	box.set_corner_radius_all(12)
	box.border_color = Color(1, 1, 1, 0.1)
	box.set_border_width_all(1)
	box.set_content_margin_all(10)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	_stats_hud.add_theme_stylebox_override("panel", box)


func _exit_tree() -> void:
	_running = false


# ------------------------------- MISE EN PLACE -------------------------------

func _spawn_enemies() -> void:
	var level := int(_battle["level"])
	var enemies: Dictionary = _battle["enemies"]
	var cells: Array = _engine.grid.free_enemy_cells()
	var index := 0
	for type in Balance.UNIT_TYPES:
		if not enemies.has(type):
			continue
		for i in range(int(enemies[type])):
			if index >= cells.size():
				push_warning("Zone ennemie trop petite pour la bataille %d" % int(_battle["id"]))
				return
			_engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[index])
			index += 1


# ------------------------------- PHASE PLACEMENT -----------------------------

func _enter_placement() -> void:
	_phase = Phase.PLACEMENT
	_style_placement_badge()
	_style_bottom_panel(Color("0f121f", 0.92), 16, 0)
	_bottom_panel.position = Vector2(0, 635)
	_bottom_panel.size = Vector2(393, 189)
	_grid_view.show_zones = true
	_grid_view.queue_redraw()
	_build_placement_ui()
	_refresh_placement()
	_refresh_stats_hud()


## Panneau bas (Control-Panel, ecrans 04 et 05) : coins arrondis en haut
## pendant le placement, plat pendant le combat - cf. maquettes Figma.
func _style_bottom_panel(bg: Color, radius_top: int, radius_bottom: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = radius_top
	box.corner_radius_top_right = radius_top
	box.corner_radius_bottom_left = radius_bottom
	box.corner_radius_bottom_right = radius_bottom
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 16
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, -4)
	_bottom_panel.add_theme_stylebox_override("panel", box)


func _build_placement_ui() -> void:
	_clear_bottom()

	var header := HBoxContainer.new()
	_bottom.add_child(header)

	var header_label := UiTheme.make_label("DISPONIBLES AU PLACEMENT", 11, Color("ccccd9"))
	header_label.add_theme_font_override("font", UiTheme.font_bold())
	header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(header_label)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_status_label = UiTheme.make_label("Tape pour poser", 10, Color("e5bf4d"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_status_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_bottom.add_child(row)

	_type_buttons.clear()
	for type in Balance.UNIT_TYPES:
		var chip: SelectionChip = SelectionChipScene.instantiate()
		var path := "res://assets/pieces/bleu/%s.png" % type
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		row.add_child(chip)
		chip.set_piece.call_deferred(texture, Balance.unit_name(type).to_upper(), int(_remaining[type]))
		chip.pressed.connect(_on_type_selected.bind(type))
		_type_buttons[type] = chip

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_bottom.add_child(actions)

	var auto := UiTheme.make_button("AUTO", Color(1, 1, 1, 0.08), 12)
	auto.add_theme_font_override("font", UiTheme.font_bold())
	auto.add_theme_color_override("font_color", Color("ccccd9"))
	auto.pressed.connect(_on_auto_place)
	actions.add_child(auto)

	var reset := UiTheme.make_button("REINITIALISER", Color(1, 1, 1, 0.08), 12)
	reset.add_theme_font_override("font", UiTheme.font_bold())
	reset.add_theme_color_override("font_color", Color("ccccd9"))
	reset.pressed.connect(_on_reset_placement)
	actions.add_child(reset)

	var fight_spacer := Control.new()
	fight_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(fight_spacer)

	_fight_button = UiTheme.make_button("COMBATTRE", UiTheme.GOLD, 12)
	_fight_button.add_theme_font_override("font", UiTheme.font_bold())
	_fight_button.pressed.connect(_start_combat)
	actions.add_child(_fight_button)

	# Selectionne d'office le premier type disponible.
	for type in Balance.UNIT_TYPES:
		if int(_remaining[type]) > 0:
			_selected_type = type
			break


func _refresh_placement() -> void:
	var slots := Game.deploy_slots()
	if _placed.size() >= slots:
		_status_label.text = "Effectif maximum atteint"
	else:
		_status_label.text = "Tape pour poser"

	for type in _type_buttons.keys():
		var chip: SelectionChip = _type_buttons[type]
		chip.set_count(int(_remaining[type]))
		chip.selected = (type == _selected_type)

	_fight_button.disabled = _placed.is_empty()
	_update_preview()
	_refresh_stats_hud()


## HUD lateral (cf. CLAUDE.md > Stats-HUD) : effectif pose pendant le
## placement, forces en vie de chaque camp pendant le combat.
func _refresh_stats_hud() -> void:
	for child in _stats_box.get_children():
		child.queue_free()

	if _phase == Phase.PLACEMENT:
		var label := UiTheme.make_label("Unites", 10, Color("b2b2cc"))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(label)
		_stats_box.add_child(_hud_separator())
		var count := UiTheme.make_label("%d/%d" % [_placed.size(), Game.deploy_slots()], 13, Color("99ccff"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(count)
	else:
		_stats_box.add_child(_hud_row(UiTheme.ENEMY, Color("ffb299"), _engine.living(BattleUnit.TEAM_ENEMY).size()))
		_stats_box.add_child(_hud_separator())
		_stats_box.add_child(_hud_row(UiTheme.ACCENT, Color("99ccff"), _engine.living(BattleUnit.TEAM_PLAYER).size()))


func _hud_separator() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(30, 1)
	return line


func _hud_row(dot_color: Color, text_color: Color, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	var dot := Icon.new()
	dot.icon_name = "dot"
	dot.color = dot_color
	dot.custom_minimum_size = Vector2(10, 10)
	row.add_child(dot)
	var label := UiTheme.make_label(str(count), 14, text_color)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	return row


## Apercu : ou chaque piece irait a sa premiere activation, dans la position
## actuelle. Chaque piece est evaluee independamment des autres - les fleches
## montrent les intentions d'ouverture, pas la sequence exacte du combat.
func _update_preview() -> void:
	var preview: Array = []
	for unit in _engine.units:
		if not unit.is_alive():
			continue
		var decision := BattleAI.decide(unit, _engine.grid, _engine.units)
		var destination: Vector2i = decision["move"]
		if destination == unit.cell:
			continue
		preview.append({
			"from": unit.cell,
			"to": destination,
			"team": unit.team,
			"capture": decision["capture"] != null,
		})
	_grid_view.preview_moves = preview
	_grid_view.queue_redraw()


func _on_type_selected(type: String) -> void:
	if int(_remaining[type]) <= 0:
		return
	_selected_type = type
	_refresh_placement()


func _on_cell_clicked(cell: Vector2i) -> void:
	if _phase != Phase.PLACEMENT:
		return

	# Une unite deja posee : on la retire (repositionnement).
	var existing: BattleUnit = _engine.grid.unit_at(cell)
	if existing != null:
		if existing.team == BattleUnit.TEAM_PLAYER:
			_remaining[existing.type] = int(_remaining[existing.type]) + 1
			_placed.erase(existing)
			_engine.remove_unit(existing)
			_grid_view.queue_redraw()
			_refresh_placement()
		return

	if not _engine.grid.is_player_zone(cell):
		return
	if _selected_type.is_empty() or int(_remaining[_selected_type]) <= 0:
		return
	if _placed.size() >= Game.deploy_slots():
		_status_label.text = "Chateau Nv.%d : %d unites maximum." % [
			Game.castle_level(), Game.deploy_slots()]
		return

	var unit := _engine.add_unit(_selected_type, Game.building_level(_selected_type),
		BattleUnit.TEAM_PLAYER, cell)
	_placed.append(unit)
	_remaining[_selected_type] = int(_remaining[_selected_type]) - 1
	_grid_view.queue_redraw()
	_refresh_placement()


func _on_reset_placement() -> void:
	for unit in _placed.duplicate():
		_remaining[unit.type] = int(_remaining[unit.type]) + 1
		_engine.remove_unit(unit)
	_placed.clear()
	_grid_view.queue_redraw()
	_refresh_placement()


## Formation automatique : les pions devant, les pieces lourdes derriere.
##
## Aligner tout le monde sur la meme rangee est le pire placement possible :
## les pieces se bouchent le passage et la tour ne sort jamais. Les pions
## ouvrent le contact, les pieces de valeur suivent une fois les lignes ouvertes.
func _on_auto_place() -> void:
	var slots := Game.deploy_slots()
	var order: Array = []
	while order.size() < slots:
		var type := _pick_available_type(order)
		if type.is_empty():
			break
		order.append(type)

	# Les pions passent devant, le reste garde son ordre d'alternance.
	order.sort_custom(func(a, b): return Balance.unit_value(a) < Balance.unit_value(b))

	var cells: Array = _engine.grid.free_player_cells()
	for i in range(mini(order.size(), cells.size())):
		var type: String = order[i]
		var unit := _engine.add_unit(type, Game.building_level(type),
			BattleUnit.TEAM_PLAYER, cells[i])
		_placed.append(unit)
		_remaining[type] = int(_remaining[type]) - 1

	_grid_view.queue_redraw()
	_refresh_placement()


## Alterne les types disponibles plutot que de vider la caserne la plus pleine :
## un mur de pions perd contre a peu pres tout.
##
## `taken` contient les types deja retenus pour cette formation, afin de tenir
## le compte avant que les pieces soient reellement posees.
func _pick_available_type(taken: Array = []) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(taken.size() + offset) % types.size()]
		if int(_remaining[type]) - taken.count(type) > 0:
			return type
	return ""


# ------------------------------- PHASE COMBAT --------------------------------

func _start_combat() -> void:
	if _placed.is_empty():
		return
	_phase = Phase.COMBAT
	_turn_activations = 0
	_combat_unit_count = maxi(1,
		_engine.living(BattleUnit.TEAM_PLAYER).size() + _engine.living(BattleUnit.TEAM_ENEMY).size())
	_style_combat_badge()
	_style_bottom_panel(Color("111319", 0.85), 0, 0)
	_bottom_panel.position = Vector2(0, 747)
	_bottom_panel.size = Vector2(393, 77)
	_grid_view.preview_moves = []
	_grid_view.show_zones = false
	_grid_view.selected_cell = Vector2i(-1, -1)
	_grid_view.queue_redraw()
	_build_combat_ui()
	_refresh_stats_hud()
	_run_combat()


func _build_combat_ui() -> void:
	_clear_bottom()

	var separator := ColorRect.new()
	separator.color = Color(0.18, 0.357, 1.0, 0.38)
	separator.custom_minimum_size = Vector2(0, 1)
	_bottom.add_child(separator)

	# Pas de label de statut ici : le tour et les forces en vie sont deja
	# affiches dans le badge et le HUD lateral (cf. captures Figma 05).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_bottom.add_child(row)

	var pause_label: Label = null
	var pause := _icon_button("pause", "PAUSE", Color("262c3f"), Color("3a4060"), Color("a0aabf"), 16, 11)
	pause.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_paused = not _paused
			pause_label.text = "REPRENDRE" if _paused else "PAUSE"
	)
	pause_label = pause.find_child("Label", true, false)
	row.add_child(pause)

	var pause_spacer := Control.new()
	pause_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pause_spacer)

	var toggle := PanelContainer.new()
	var toggle_box := StyleBoxFlat.new()
	toggle_box.bg_color = Color("161926")
	toggle_box.set_corner_radius_all(12)
	toggle_box.border_color = Color("2a2f45")
	toggle_box.set_border_width_all(1)
	toggle_box.set_content_margin_all(4)
	toggle.add_theme_stylebox_override("panel", toggle_box)
	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 3)
	toggle.add_child(toggle_row)
	row.add_child(toggle)

	_speed_buttons.clear()
	for speed in Balance.SPEEDS:
		var pill := PanelContainer.new()
		var pill_label := UiTheme.make_label("x%d" % int(speed), 12, Color("5a6480"))
		pill_label.add_theme_font_override("font", UiTheme.font_bold())
		pill_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(pill_label)
		pill.custom_minimum_size = Vector2(0, 0)
		var margin := StyleBoxFlat.new()
		margin.set_corner_radius_all(8)
		margin.content_margin_left = 12
		margin.content_margin_right = 12
		margin.content_margin_top = 7
		margin.content_margin_bottom = 7
		margin.bg_color = Color("1c2135")
		pill.add_theme_stylebox_override("panel", margin)
		pill.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_speed_selected(float(speed))
		)
		toggle_row.add_child(pill)
		_speed_buttons[speed] = pill

	var end_spacer := Control.new()
	end_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(end_spacer)

	var end_turn := _icon_button("skip", "FIN TOUR", Color("1c2135"), Color("2a2f45"), Color("a0aabf"), 14, 11)
	end_turn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_end_turn()
	)
	row.add_child(end_turn)

	_refresh_combat_status()


## Panneau clic-able icone + texte (Pause / Fin Tour, ecran 05) - un
## PanelContainer plutot qu'un Button, pour placer une Icon vectorielle a
## cote du texte sans dependre d'une police emoji (cf. icon.gd).
func _icon_button(icon_name: String, text: String, bg: Color, border: Color, fg: Color,
		icon_size: float, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(10)
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = fg
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	row.add_child(icon)

	var label := UiTheme.make_label(text, font_size, fg)
	label.name = "Label"
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	UiTheme.ignore_mouse_recursive(row)
	return panel


func _on_speed_selected(speed: float) -> void:
	_speed = speed
	_paused = false
	_refresh_combat_status()


## "Fin tour" (Btn-EndTurn, ecran 05) : accelere jusqu'a la fin des activations
## du tour en cours, puis restaure la vitesse choisie - cf. _refresh_combat_status().
func _on_end_turn() -> void:
	if _fast_forward_target_turn != -1 or _engine.finished:
		return
	_speed_before_fast_forward = _speed
	_fast_forward_target_turn = _turn_activations / _combat_unit_count + 1
	_speed = 200.0
	_paused = false
	_refresh_combat_status()


func _refresh_combat_status() -> void:
	var turn := _turn_activations / _combat_unit_count + 1
	_phase_label.text = str(turn)
	_refresh_stats_hud()

	# La vitesse d'avant "Fin tour" revient des que le tour suivant commence -
	# cf. _on_end_turn().
	if _fast_forward_target_turn != -1 and turn != _fast_forward_target_turn:
		_speed = _speed_before_fast_forward
		_fast_forward_target_turn = -1

	var shown_speed := _speed_before_fast_forward if _fast_forward_target_turn != -1 else _speed
	for speed in _speed_buttons.keys():
		var pill: PanelContainer = _speed_buttons[speed]
		var active: bool = speed == shown_speed
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(8)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		box.bg_color = Color("ffd700") if active else Color("1c2135")
		pill.add_theme_stylebox_override("panel", box)
		var label: Label = pill.get_child(0)
		label.add_theme_color_override("font_color", Color("0f111a") if active else Color("5a6480"))


## Boucle principale du combat. Une iteration = une activation d'unite.
func _run_combat() -> void:
	_running = true
	while _running and not _engine.finished:
		while _running and _paused:
			_refresh_combat_status()
			await get_tree().process_frame
		if not _running:
			return

		var events: Array = _engine.step()
		_turn_activations += 1
		await _play_events(events)
		if not _running:
			return

		_refresh_combat_status()
		await _wait(float(Balance.COMBAT["step_delay"]))

	if _running:
		_show_result()


## Rejoue les evenements d'une activation. Seules les DUREES dependent de la
## vitesse choisie : les evenements, eux, sont deja resolus.
func _play_events(events: Array) -> void:
	for event in events:
		if not _running:
			return
		match String(event["type"]):
			"capture":
				await _grid_view.play_capture(
					event["cell"], float(Balance.COMBAT["capture_duration"]) / _speed)
			"move":
				await _grid_view.play_move(
					int(event["unit"]), event["from"], event["to"],
					float(Balance.COMBAT["move_duration"]) / _speed)
			"promotion":
				await _grid_view.play_promotion(
					event["cell"], String(event["result"]),
					float(Balance.COMBAT["promotion_duration"]) / _speed)
			_:
				pass


func _wait(seconds: float) -> void:
	var duration := maxf(0.01, seconds / _speed)
	await get_tree().create_timer(duration).timeout


# ------------------------------- PHASE RESULTAT ------------------------------

func _show_result() -> void:
	_phase = Phase.RESULT
	_running = false
	var victory := _engine.winner == BattleUnit.TEAM_PLAYER
	var reward := Game.reward_for(int(_battle["id"]))
	var battle_id := int(_battle["id"])
	var first_win := victory and not Game.is_battle_won(battle_id)

	# Les pertes sont definitives, victoire ou defaite : les pieces capturees
	# quittent l'armee et devront etre recrutees a nouveau.
	var losses: Dictionary = _engine.losses(BattleUnit.TEAM_PLAYER)
	Game.apply_losses(losses)

	# Recompense de consolation en cas de defaite - cf. capture Figma 07
	# (Consolation-Row) : meme perdue, une bataille rapporte un peu.
	var consolation := 0
	if victory:
		Game.win_battle(battle_id, reward)
	else:
		consolation = int(round(reward * Balance.DEFEAT_CONSOLATION_RATIO))
		if consolation > 0:
			Game.add_gold(consolation)

	_phase_prefix.text = ""
	_phase_label.text = "Victoire" if victory else "Defaite"

	var total_enemies := 0
	var enemy_data: Dictionary = _battle["enemies"]
	for type in enemy_data.keys():
		total_enemies += int(enemy_data[type])
	var enemies_defeated := total_enemies - _engine.living(BattleUnit.TEAM_ENEMY).size()

	# Modal generique (cf. scenes/ui/components/modal.gd) : contexte or pour
	# la victoire, rouge pour la defaite, comme prevu par les captures Figma
	# 06/07, avec le blason couronne et le grand titre "Inter Black" repris
	# tels quels (title-block).
	var modal: Modal = ModalScene.instantiate()
	modal.show_close_button = false
	modal.close_on_dim_click = false
	add_child(modal)
	modal.open("VICTOIRE" if victory else "DEFAITE",
		Modal.Context.GOLD if victory else Modal.Context.RED, "crown")
	(modal.get_node("%TitleLabel") as Label).add_theme_font_size_override("font_size", 32)
	var body := modal.body

	if not victory:
		var subtitle := UiTheme.make_label(
			"Tes forces ont succombe face a la strategie ennemie.", 12, Color("a0aabf"))
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(subtitle)
		body.add_child(DividerScene.instantiate())

	var stats_card: PanelContainer = CardScene.instantiate()
	var stats_body: VBoxContainer = stats_card.get_node("%Body")
	body.add_child(stats_card)

	if victory:
		stats_body.add_child(UiTheme.stat_row("Recompense",
			_icon_value("coin", UiTheme.GOLD, "+%d Or" % reward, UiTheme.GOLD, 16)))
		stats_body.add_child(_stats_separator())
		stats_body.add_child(UiTheme.stat_row("Ennemis vaincus",
			_plain_value(str(enemies_defeated), Color("f0f3f8"), 14)))
		if first_win and battle_id < Balance.battle_count():
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Progression",
				_icon_value("check", Color("4cd964"), "Bataille %d debloquee" % (battle_id + 1), Color("4cd964"), 14)))
		elif battle_id >= Balance.battle_count():
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Progression",
				_plain_value("Campagne terminee", UiTheme.GOLD, 14)))
		if not losses.is_empty():
			var details: Array = []
			for type in Balance.UNIT_TYPES:
				if losses.has(type):
					details.append("%d %s" % [int(losses[type]), Balance.unit_name(type)])
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Pertes",
				UiTheme.make_label(", ".join(details), 14, Color("a0aabf"))))
	else:
		if losses.is_empty():
			stats_body.add_child(UiTheme.make_label("Aucune perte. Toute ton armee rentre.",
				13, UiTheme.SUCCESS))
		else:
			stats_body.add_child(UiTheme.make_label("Pertes subies", 12, Color("a0aabf")))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			for type in Balance.UNIT_TYPES:
				if losses.has(type):
					row.add_child(_loss_chip(int(losses[type]), Balance.unit_name(type)))
			stats_body.add_child(row)
		if consolation > 0:
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Consolation",
				_icon_value("coin", UiTheme.GOLD_BUTTON, "+%d Or" % consolation, UiTheme.GOLD_BUTTON, 14)))

	body.add_child(DividerScene.instantiate())

	# Boutons : ordre et styles repris tels quels des captures Figma 06/07 -
	# victoire met en avant l'or (bataille suivante), defaite met en avant
	# le rejeu (Reessayer) plutot que le retour au village.
	if victory:
		if battle_id < Balance.battle_count():
			var next := Button.new()
			next.text = "BATAILLE SUIVANTE"
			next.theme_type_variation = "GoldButton"
			next.pressed.connect(func(): Router.goto_prep(battle_id + 1))
			body.add_child(next)

		var retry := Button.new()
		retry.text = "REESSAYER"
		retry.theme_type_variation = "SecondaryButton"
		retry.pressed.connect(func(): Router.goto_battle(battle_id))
		body.add_child(retry)

		var village_link := Button.new()
		village_link.text = "RETOUR AU VILLAGE"
		village_link.theme_type_variation = "DiscreetButton"
		village_link.add_theme_font_size_override("font_size", 13)
		var underline := StyleBoxFlat.new()
		underline.bg_color = Color(0, 0, 0, 0)
		underline.border_color = UiTheme.TEXT_DIM
		underline.border_width_bottom = 1
		village_link.add_theme_stylebox_override("normal", underline)
		village_link.add_theme_stylebox_override("hover", underline)
		village_link.add_theme_stylebox_override("pressed", underline)
		village_link.pressed.connect(Router.goto_village)
		body.add_child(village_link)
	else:
		var retry := Button.new()
		retry.text = "REESSAYER"
		retry.theme_type_variation = "GoldButton"
		retry.pressed.connect(func(): Router.goto_battle(battle_id))
		body.add_child(retry)

		var village := Button.new()
		village.text = "RETOUR AU VILLAGE"
		village.theme_type_variation = "SecondaryButton"
		village.pressed.connect(Router.goto_village)
		body.add_child(village)


func _stats_separator() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _plain_value(text: String, color: Color, size: int) -> Label:
	var label := UiTheme.make_label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", UiTheme.font_bold())
	return label


## Valeur d'une ligne de stats avec une icone devant le texte (recompense,
## deblocage, consolation) - cf. captures Figma 06/07, ou ces trois lignes
## seules portent un petit glyphe.
func _icon_value(icon_name: String, icon_color: Color, text: String, text_color: Color, size: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = icon_color
	icon.custom_minimum_size = Vector2(size, size)
	box.add_child(icon)
	var label := UiTheme.make_label(text, size, text_color)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(label)
	return box


func _loss_chip(count: int, name: String) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	var dot := Icon.new()
	dot.icon_name = "dot"
	dot.color = UiTheme.DANGER
	dot.custom_minimum_size = Vector2(16, 16)
	chip.add_child(dot)
	var label := UiTheme.make_label("%d %s" % [count, name], 13, Color("f0f3f8"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_child(label)
	return chip


# ------------------------------- DIVERS --------------------------------------

func _clear_bottom() -> void:
	for child in _bottom.get_children():
		child.queue_free()
	_type_buttons.clear()
	_status_label = null
	_fight_button = null


func _on_quit() -> void:
	_running = false
	Router.goto_village()
