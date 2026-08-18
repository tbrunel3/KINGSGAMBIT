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

@onready var _phase_label: Label = $Safe/Root/TopBar/TopRow/PhaseLabel
@onready var _quit_button: Button = $Safe/Root/TopBar/TopRow/QuitButton
@onready var _grid_view: Control = $Safe/Root/Grid
@onready var _bottom_panel: PanelContainer = $Safe/Root/BottomPanel
@onready var _bottom: VBoxContainer = $Safe/Root/BottomPanel/BottomBox

var _battle: Dictionary = {}
var _engine: BattleEngine = null
var _phase: int = Phase.PLACEMENT

# Placement
var _remaining: Dictionary = {}   # type -> unites encore disponibles
var _selected_type: String = ""
var _placed: Array = []           # BattleUnit du joueur poses sur la grille

# Combat
var _speed: float = 1.0
var _paused: bool = false
var _running: bool = false

# Elements rafraichis souvent, gardes sous la main.
var _status_label: Label = null
var _type_buttons: Dictionary = {}
var _fight_button: Button = null


func _ready() -> void:
	_battle = Router.current_battle()
	if _battle.is_empty():
		Router.goto_village()
		return

	UiTheme.style_panel($Safe/Root/TopBar)
	UiTheme.style_panel(_bottom_panel)
	UiTheme.style_button(_quit_button, UiTheme.DANGER.darkened(0.35))
	_quit_button.add_theme_font_size_override("font_size", 12)
	_quit_button.pressed.connect(_on_quit)

	_engine = BattleEngine.new(int(_battle["cols"]), int(_battle["rows"]))
	_spawn_enemies()

	for type in Balance.UNIT_TYPES:
		_remaining[type] = Game.units_owned(type)

	_grid_view.setup(_engine)
	_grid_view.cell_clicked.connect(_on_cell_clicked)

	_enter_placement()


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
	_phase_label.text = "Placement"
	_highlight_deploy_zone()
	_build_placement_ui()
	_refresh_placement()


func _highlight_deploy_zone() -> void:
	var cells: Array = []
	for y in range(_engine.grid.player_zone_first_row(), _engine.grid.rows):
		for x in range(_engine.grid.cols):
			cells.append(Vector2i(x, y))
	_grid_view.highlighted = cells
	_grid_view.queue_redraw()


func _build_placement_ui() -> void:
	_clear_bottom()

	_status_label = UiTheme.make_label("", 14, UiTheme.TEXT_DIM)
	_bottom.add_child(_status_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_bottom.add_child(row)

	_type_buttons.clear()
	for type in Balance.UNIT_TYPES:
		var button := UiTheme.make_button("", Balance.unit_color(type).darkened(0.5), 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 52)
		button.pressed.connect(_on_type_selected.bind(type))
		row.add_child(button)
		_type_buttons[type] = button

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_bottom.add_child(actions)

	var auto := UiTheme.make_button("Auto", UiTheme.PANEL_LIGHT, 14)
	auto.pressed.connect(_on_auto_place)
	actions.add_child(auto)

	var reset := UiTheme.make_button("Reinitialiser", UiTheme.PANEL_LIGHT, 14)
	reset.pressed.connect(_on_reset_placement)
	actions.add_child(reset)

	_fight_button = UiTheme.make_button("COMBATTRE", UiTheme.SUCCESS.darkened(0.3), 17)
	_fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fight_button.custom_minimum_size = Vector2(0, 52)
	_fight_button.pressed.connect(_start_combat)
	actions.add_child(_fight_button)

	# Selectionne d'office le premier type disponible.
	for type in Balance.UNIT_TYPES:
		if int(_remaining[type]) > 0:
			_selected_type = type
			break


func _refresh_placement() -> void:
	var slots := Game.deploy_slots()
	_status_label.text = "Choisis un type, touche une case verte.  %d / %d deployees" % [
		_placed.size(), slots
	]

	for type in _type_buttons.keys():
		var button: Button = _type_buttons[type]
		button.text = "%s\n%d" % [Balance.unit_letter(type), int(_remaining[type])]
		button.disabled = int(_remaining[type]) <= 0
		var color: Color = Balance.unit_color(type)
		UiTheme.style_button(button, color.darkened(0.2) if type == _selected_type else color.darkened(0.6))

	_fight_button.disabled = _placed.is_empty()
	_update_preview()


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
	_phase_label.text = "Combat - bataille %d" % int(_battle["id"])
	_grid_view.preview_moves = []
	_grid_view.highlighted = []
	_grid_view.selected_cell = Vector2i(-1, -1)
	_grid_view.queue_redraw()
	_build_combat_ui()
	_run_combat()


func _build_combat_ui() -> void:
	_clear_bottom()

	_status_label = UiTheme.make_label("", 14, UiTheme.TEXT_DIM)
	_bottom.add_child(_status_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_bottom.add_child(row)

	var pause := UiTheme.make_button("Pause", UiTheme.PANEL_LIGHT, 15)
	pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause.pressed.connect(func():
		_paused = not _paused
		pause.text = "Reprendre" if _paused else "Pause"
	)
	row.add_child(pause)

	for speed in Balance.SPEEDS:
		var button := UiTheme.make_button("x%d" % int(speed), UiTheme.PANEL_LIGHT, 15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_speed_selected.bind(float(speed)))
		row.add_child(button)

	_refresh_combat_status()


func _on_speed_selected(speed: float) -> void:
	_speed = speed
	_paused = false
	_refresh_combat_status()


func _refresh_combat_status() -> void:
	if _status_label == null:
		return
	_status_label.text = "Roi %d  -  Ennemi %d      vitesse x%d%s" % [
		_engine.living(BattleUnit.TEAM_PLAYER).size(),
		_engine.living(BattleUnit.TEAM_ENEMY).size(),
		int(_speed),
		"  (en pause)" if _paused else "",
	]


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

	if victory:
		# Or ajoute et bataille suivante debloquee cote GameState.
		Game.win_battle(battle_id, reward)

	_phase_label.text = "Victoire" if victory else "Defaite"

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	UiTheme.style_panel(panel)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(UiTheme.make_label(
		"VICTOIRE" if victory else "DEFAITE", 30,
		UiTheme.SUCCESS if victory else UiTheme.DANGER))
	box.add_child(UiTheme.make_label(String(_battle["name"]), 14, UiTheme.TEXT_DIM))

	if victory:
		box.add_child(UiTheme.make_label("+ %d or" % reward, 20, UiTheme.GOLD))
		if first_win and battle_id < Balance.battle_count():
			box.add_child(UiTheme.make_label(
				"Bataille %d debloquee" % (battle_id + 1), 14, UiTheme.SUCCESS))
		elif battle_id >= Balance.battle_count():
			box.add_child(UiTheme.make_label(
				"Campagne terminee. La Dame est retrouvee.", 14, UiTheme.GOLD))
	else:
		box.add_child(UiTheme.make_label(
			"Ton armee a ete balayee. Recrute, ameliore, recommence.",
			13, UiTheme.TEXT_DIM))

	# Les pertes comptent autant que la recompense : elles sont definitives.
	box.add_child(HSeparator.new())
	if losses.is_empty():
		box.add_child(UiTheme.make_label("Aucune perte. Toute ton armee rentre.",
			14, UiTheme.SUCCESS))
	else:
		var details: Array = []
		var total := 0
		for type in Balance.UNIT_TYPES:
			if losses.has(type):
				details.append("%d %s" % [int(losses[type]), Balance.unit_name(type)])
				total += int(losses[type])
		box.add_child(UiTheme.make_label(
			"Pieces perdues definitivement : %s" % ", ".join(details), 14, UiTheme.DANGER))
		box.add_child(UiTheme.make_label(
			"Il faudra les recruter a nouveau au village.", 12, UiTheme.TEXT_DIM))

	box.add_child(HSeparator.new())

	var retry := UiTheme.make_button("Reessayer", UiTheme.PANEL_LIGHT, 16)
	retry.pressed.connect(func(): Router.goto_battle(battle_id))
	box.add_child(retry)

	if victory and battle_id < Balance.battle_count():
		var next := UiTheme.make_button("Bataille suivante", UiTheme.ACCENT, 16)
		next.pressed.connect(func(): Router.goto_prep(battle_id + 1))
		box.add_child(next)

	var village := UiTheme.make_button("Retour au village", UiTheme.GOLD.darkened(0.5), 16)
	village.pressed.connect(Router.goto_village)
	box.add_child(village)


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
