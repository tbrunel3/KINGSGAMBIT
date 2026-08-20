extends Control
##
## BATAILLE - une seule scene, trois phases : PLACEMENT, COMBAT, RESULTAT.
##
## Une scene unique plutot que trois : l'etat du placement n'a ainsi jamais a
## transiter entre deux scenes, et le moteur de combat est construit une fois.
##
## Ce fichier ne contient aucune regle de combat. Il pose les unites, transmet
## au moteur le coup choisi par le joueur (tape ou glisser-deposer), demande a
## l'IA le coup adverse, et rejoue les evenements retournes.
##
## Le combat se joue coup par coup : une piece du joueur, une piece de l'IA.
## Le bouton AUTO laisse l'IA jouer les deux camps jusqu'au bout - pratique
## pour refaire de l'or sur une bataille deja gagnee. La vitesse (x1/x2/x4)
## n'agit que sur les durees d'affichage, jamais sur l'issue d'un coup.
##

enum Phase { PLACEMENT, COMBAT, RESULT }

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const SelectionChipScene := preload("res://scenes/ui/components/selection_chip.tscn")

const VICTORY_BG_PATH := "res://assets/results/victory_modal_bg.png"
const DEFEAT_BG_PATH := "res://assets/results/defeat_modal_bg.png"

@onready var _tour_badge: PanelContainer = $Safe/Overlay/TourBadge
@onready var _phase_prefix: Label = $Safe/Overlay/TourBadge/TourRow/PhasePrefixLabel
@onready var _phase_label: Label = $Safe/Overlay/TourBadge/TourRow/PhaseLabel
@onready var _quit_button: Button = $Safe/Overlay/QuitButton
@onready var _grid_view: Control = $Safe/Overlay/Grid
@onready var _stats_hud: PanelContainer = $Safe/Overlay/StatsHud
@onready var _stats_box: VBoxContainer = $Safe/Overlay/StatsHud/StatsBox
@onready var _bottom_panel: PanelContainer = $Safe/Overlay/BottomPanel
@onready var _bottom: VBoxContainer = $Safe/Overlay/BottomPanel/BottomBox

## Chrono de blocage (cf. Balance.COMBAT.stalemate_seconds_cap) : construit et
## detruit avec la phase de combat, jamais present pendant placement/resultat.
var _blockage_badge: PanelContainer = null
var _blockage_label: Label = null

## Fraction du seuil d'enlisement a partir de laquelle le chrono devient
## visible. Reste cache avant ca : ce garde-fou doit rester exceptionnel, pas
## un compte a rebours permanent qui inquieterait le joueur pour rien pendant
## une phase de poursuite tout a fait normale.
const _BLOCKAGE_WARNING_RATIO := 0.5

var _battle: Dictionary = {}
var _engine: BattleEngine = null
var _phase: int = Phase.PLACEMENT

# Placement
var _remaining: Dictionary = {}   # type -> unites encore disponibles
var _selected_type: String = ""
var _placed: Array = []           # BattleUnit du joueur poses sur la grille

# Combat
var _speed: float = 1.0
var _running: bool = false

## Piece du joueur actuellement selectionnee (tape ou saisie au doigt).
var _selected_unit: BattleUnit = null

## Vrai pendant qu'une animation ou le tour de l'IA se joue : le plateau
## n'accepte alors aucun geste, sinon un joueur rapide jouerait deux coups.
var _busy: bool = false

## Resolution automatique : l'IA joue les DEUX camps jusqu'a la fin.
var _auto: bool = false

# Elements rafraichis souvent, gardes sous la main.
var _status_label: Label = null
var _type_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _fight_button: Button = null
var _auto_button: PanelContainer = null
var _auto_label: Label = null
var _turn_label: Label = null


func _ready() -> void:
	_battle = Router.current_battle()
	if _battle.is_empty():
		Router.goto_village()
		return

	_style_stats_hud()
	_quit_button.add_theme_font_size_override("font_size", 13)
	_quit_button.pressed.connect(_on_quit)

	_engine = BattleEngine.new(int(_battle["cols"]), int(_battle["rows"]))
	_engine.enemy_skill = Balance.battle_ai_skill(_battle)
	_spawn_enemies()

	for type in Balance.ARMY_TYPES:
		_remaining[type] = Game.units_owned(type)

	_grid_view.setup(_engine)
	_grid_view.cell_clicked.connect(_on_cell_clicked)
	_grid_view.cell_pressed.connect(_on_cell_pressed)
	_grid_view.piece_dropped.connect(_on_piece_dropped)
	_grid_view.draggable_team = BattleUnit.TEAM_PLAYER

	_enter_placement()


## Niveau auquel une piece part au combat : celui de son batiment. La Dame
## n'ayant pas de caserne qui s'ameliore, elle garde le niveau de la Caserne
## des Pions - elle EST un pion promu, sa mobilite suit celle des pions.
func _unit_level(type: String) -> int:
	if type == Balance.DAME:
		return maxi(1, Game.building_level(Balance.PION))
	return Game.building_level(type)


## Types que le joueur peut poser sur la grille : ses casernes, plus la Dame
## s'il en a ramene une vivante d'une bataille precedente.
func _deployable_types() -> Array:
	var types: Array = []
	for type in Balance.ARMY_TYPES:
		if type == Balance.DAME and Game.units_owned(Balance.DAME) <= 0:
			continue
		types.append(type)
	return types


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

	# Le HUD flotte AU-DESSUS du plateau (cf. maquettes 04/05) : sur un
	# plateau reduit il recouvre la colonne de droite. Il doit donc laisser
	# passer le doigt, sinon les pieces qu'il survole deviennent injouables.
	UiTheme.ignore_mouse_recursive(_stats_hud)


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
	_place_bottom_panel(635, 189)
	_grid_view.show_zones = true
	_grid_view.queue_redraw()
	_build_placement_ui()
	_refresh_placement()
	_refresh_stats_hud()


## Le panneau du bas occupe toute la largeur disponible : ses ancres sont
## posees dans la scene, on ne touche donc qu'a sa hauteur. Lui donner une
## largeur en dur (les 393 points de la maquette) le ferait deborder de la
## zone sure, qui retire deja 16 points de chaque cote.
func _place_bottom_panel(top: float, height: float) -> void:
	_bottom_panel.offset_top = top
	_bottom_panel.offset_bottom = top + height


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

	_status_label = UiTheme.make_label("Tape ou glisse", 10, Color("e5bf4d"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Sans clip_text, un message un peu long pousse hors du panneau (393 pt de
	# large, marges comprises) et se fait couper par le bord de l'ecran.
	_status_label.clip_text = true
	# clip_text ramene la largeur minimale a zero : sans ce plancher, l'espaceur
	# de l'en-tete prend toute la place et le message n'a plus rien pour
	# s'afficher.
	_status_label.custom_minimum_size = Vector2(120, 0)
	header.add_child(_status_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_bottom.add_child(row)

	_type_buttons.clear()
	for type in _deployable_types():
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

	# Pas d'espaceur ici : sur 393 points de large, pousser COMBATTRE contre le
	# bord droit le fait sortir du panneau. C'est REINITIALISER, le bouton le
	# plus large, qui absorbe la place restante.
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_fight_button = UiTheme.make_button("COMBATTRE", UiTheme.GOLD, 12)
	_fight_button.add_theme_font_override("font", UiTheme.font_bold())
	_fight_button.pressed.connect(_start_combat)
	actions.add_child(_fight_button)

	# Selectionne d'office le premier type disponible.
	for type in _deployable_types():
		if int(_remaining[type]) > 0:
			_selected_type = type
			break


## Poids total (cf. Balance.deploy_weight) des pieces deja posees - c'est ce
## qu'on compare a Game.deploy_capacity(), pas un nombre de pieces : voir
## CASTLE_DATA.deploy_capacity dans balance.gd.
func _placed_weight() -> int:
	var weight := 0
	for unit in _placed:
		weight += Balance.deploy_weight(unit.type)
	return weight


func _refresh_placement() -> void:
	var capacity := Game.deploy_capacity()
	if _placed_weight() >= capacity:
		_status_label.text = "Charge maximale atteinte"
	else:
		_status_label.text = "Tape ou glisse"

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
		var label := UiTheme.make_label("Charge", 10, Color("b2b2cc"))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(label)
		_stats_box.add_child(_hud_separator())
		var count := UiTheme.make_label("%d/%d" % [_placed_weight(), Game.deploy_capacity()], 13, Color("99ccff"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(count)
	else:
		_stats_box.add_child(_hud_row(UiTheme.ENEMY, Color("ffb299"), _engine.living(BattleUnit.TEAM_ENEMY).size()))
		_stats_box.add_child(_hud_separator())
		_stats_box.add_child(_hud_row(UiTheme.ACCENT, Color("99ccff"), _engine.living(BattleUnit.TEAM_PLAYER).size()))

	UiTheme.ignore_mouse_recursive(_stats_hud)
	_keep_hud_on_screen.call_deferred()


## Le HUD est pose en coordonnees absolues (cf. maquette Figma), mais sa
## largeur depend de son contenu et la zone sure retire 16 points de chaque
## cote : sans ce recalage sur la largeur REELLE du parent, "Charge 12/16"
## sort de l'ecran par la droite.
func _keep_hud_on_screen() -> void:
	if not is_instance_valid(_stats_hud):
		return
	_stats_hud.reset_size()
	var available: float = _stats_hud.get_parent().size.x
	_stats_hud.position.x = available - _stats_hud.size.x - 8.0


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


## Le plateau ne montre plus de fleches d'intention : depuis que chaque camp
## ne joue qu'UNE piece par tour, un faisceau de fleches "si tout le monde
## bougeait en meme temps" annoncerait un combat qui n'aura pas lieu.
func _update_preview() -> void:
	_grid_view.preview_moves = []
	_grid_view.queue_redraw()


func _on_type_selected(type: String) -> void:
	if int(_remaining[type]) <= 0:
		return
	_selected_type = type
	_refresh_placement()


# ------------------------------- GESTES SUR LE PLATEAU -----------------------
#
#  Trois entrees, deux gestes : on tape une piece puis sa case d'arrivee, ou
#  on la fait glisser directement. cell_pressed sert a allumer les cases
#  possibles des que le doigt se pose, avant meme de savoir lequel des deux
#  gestes le joueur est en train de faire.

func _on_cell_pressed(cell: Vector2i) -> void:
	var unit: BattleUnit = _engine.grid.unit_at(cell)
	if unit == null or unit.team != BattleUnit.TEAM_PLAYER:
		return

	if _phase == Phase.PLACEMENT:
		# Pendant le placement, une piece posee peut aller sur n'importe quelle
		# case de la zone de deploiement : libre, ou occupee par une autre de
		# nos pieces - les deux echangent alors leur place.
		_grid_view.legal_targets = _placement_targets()
		_grid_view.selected_cell = cell
		_grid_view.queue_redraw()
	elif _phase == Phase.COMBAT:
		_select_unit(unit)


## Toute la zone de deploiement, sauf les cases occupees par l'ennemi (il n'y
## en a pas, mais rien ne l'interdit dans une bataille future).
func _placement_targets() -> Array:
	var cells: Array = []
	for y in range(_engine.grid.player_zone_first_row(), _engine.grid.rows):
		for x in range(_engine.grid.cols):
			var cell := Vector2i(x, y)
			var occupant: BattleUnit = _engine.grid.unit_at(cell)
			if occupant == null or occupant.team == BattleUnit.TEAM_PLAYER:
				cells.append(cell)
	return cells


func _on_cell_clicked(cell: Vector2i) -> void:
	match _phase:
		Phase.PLACEMENT:
			_on_placement_tap(cell)
		Phase.COMBAT:
			_on_combat_tap(cell)
		_:
			pass


func _on_piece_dropped(from: Vector2i, to: Vector2i) -> void:
	match _phase:
		Phase.PLACEMENT:
			_move_placed_unit(from, to)
		Phase.COMBAT:
			var unit: BattleUnit = _engine.grid.unit_at(from)
			if unit != null and unit.team == BattleUnit.TEAM_PLAYER:
				_try_player_move(unit, to)
		_:
			pass


# ------------------------------- PLACEMENT : GESTES --------------------------

func _on_placement_tap(cell: Vector2i) -> void:
	_clear_selection()

	# Une unite deja posee : on la retire (elle retourne dans la reserve).
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
	var capacity := Game.deploy_capacity()
	if _placed_weight() + Balance.deploy_weight(_selected_type) > capacity:
		_status_label.text = "Charge max : %d" % capacity
		return

	var unit := _engine.add_unit(_selected_type, _unit_level(_selected_type),
		BattleUnit.TEAM_PLAYER, cell)
	_placed.append(unit)
	_remaining[_selected_type] = int(_remaining[_selected_type]) - 1
	_grid_view.queue_redraw()
	_refresh_placement()


## Repositionnement au doigt : une piece deja posee glisse vers une autre case
## de la zone de deploiement. Si la case est occupee par une autre de nos
## pieces, les deux echangent leur place - c'est ce qu'on attend en reordonnant
## une formation, plutot qu'un geste refuse.
func _move_placed_unit(from: Vector2i, to: Vector2i) -> void:
	_clear_selection()
	var unit: BattleUnit = _engine.grid.unit_at(from)
	if unit == null or unit.team != BattleUnit.TEAM_PLAYER:
		return
	if not _engine.grid.is_player_zone(to):
		_status_label.text = "Zone bleue uniquement"
		return

	var occupant: BattleUnit = _engine.grid.unit_at(to)
	if occupant == null:
		_engine.grid.move_unit(unit, to)
	elif occupant.team == BattleUnit.TEAM_PLAYER:
		_engine.grid.remove_unit(unit)
		_engine.grid.remove_unit(occupant)
		_engine.grid.place(unit, to)
		_engine.grid.place(occupant, from)
	else:
		return

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
	var capacity := Game.deploy_capacity()
	var weight := 0
	var order: Array = []
	# Types qui ne rentrent plus dans la charge restante : a exclure des tours
	# suivants sans arreter la formation pour autant, un type plus leger peut
	# encore avoir sa place (ex. il reste 2 de charge, la Tour a 5 ne rentre
	# plus mais un Pion a 1 oui).
	var exhausted: Dictionary = {}
	while true:
		var type := _pick_available_type(order, exhausted)
		if type.is_empty():
			break
		var type_weight := Balance.deploy_weight(type)
		if weight + type_weight > capacity:
			exhausted[type] = true
			continue
		order.append(type)
		weight += type_weight

	# Les pions passent devant, le reste garde son ordre d'alternance.
	order.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))

	var cells: Array = _engine.grid.free_player_cells()
	for i in range(mini(order.size(), cells.size())):
		var type: String = order[i]
		var unit := _engine.add_unit(type, _unit_level(type),
			BattleUnit.TEAM_PLAYER, cells[i])
		_placed.append(unit)
		_remaining[type] = int(_remaining[type]) - 1

	_grid_view.queue_redraw()
	_refresh_placement()


## Alterne les types disponibles plutot que de vider la caserne la plus pleine :
## un mur de pions perd contre a peu pres tout.
##
## `taken` contient les types deja retenus pour cette formation, afin de tenir
## le compte avant que les pieces soient reellement posees. `exhausted` exclut
## les types qui ne rentrent plus dans la charge restante (cf. _on_auto_place).
func _pick_available_type(taken: Array = [], exhausted: Dictionary = {}) -> String:
	var types: Array = _deployable_types()
	for offset in range(types.size()):
		var type: String = types[(taken.size() + offset) % types.size()]
		if exhausted.has(type):
			continue
		if int(_remaining[type]) - taken.count(type) > 0:
			return type
	return ""


# ------------------------------- PHASE COMBAT --------------------------------
#
#  Le joueur joue une piece, l'IA repond avec une des siennes. Tant que c'est
#  au joueur, le plateau attend : aucune horloge ne tourne, il peut reflechir
#  aussi longtemps qu'il veut. Le bouton AUTO confie les deux camps a l'IA.

func _start_combat() -> void:
	if _placed.is_empty():
		return
	_phase = Phase.COMBAT
	_running = true
	# Le joueur tient un des deux camps : les garde-fous anti-blocage calibres
	# sur des secondes d'animation ne s'appliquent plus (cf. BattleEngine).
	_engine.auto_mode = false
	_style_combat_badge()
	_style_bottom_panel(Color("111319", 0.85), 0, 0)
	_place_bottom_panel(747, 77)
	_grid_view.preview_moves = []
	_grid_view.show_zones = false
	_clear_selection()
	_build_combat_ui()
	_build_blockage_badge()
	_refresh_stats_hud()
	_hand_over_to_player()


## Petit badge rouge sous le Tour-Badge, cache par defaut : cf.
## _BLOCKAGE_WARNING_RATIO. Rejoue le meme habillage (fond fonce, bordure,
## ombre) que les autres badges de l'ecran de combat.
func _build_blockage_badge() -> void:
	_blockage_badge = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.DANGER, 0.16)
	box.set_corner_radius_all(10)
	box.border_color = Color(UiTheme.DANGER, 0.7)
	box.set_border_width_all(1.5)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	_blockage_badge.add_theme_stylebox_override("panel", box)
	_blockage_badge.position = Vector2(12, 97)
	_blockage_badge.visible = false

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_blockage_badge.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "clock"
	icon.color = UiTheme.DANGER
	icon.custom_minimum_size = Vector2(12, 12)
	row.add_child(icon)

	_blockage_label = UiTheme.make_label("", 10, UiTheme.DANGER)
	_blockage_label.add_theme_font_override("font", UiTheme.font_bold())
	_blockage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_blockage_label)

	_tour_badge.get_parent().add_child(_blockage_badge)


func _clear_blockage_badge() -> void:
	if _blockage_badge != null:
		_blockage_badge.queue_free()
		_blockage_badge = null
		_blockage_label = null


func _build_combat_ui() -> void:
	_clear_bottom()

	var separator := ColorRect.new()
	separator.color = Color(0.18, 0.357, 1.0, 0.38)
	separator.custom_minimum_size = Vector2(0, 1)
	_bottom.add_child(separator)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bottom.add_child(row)

	# A gauche : a qui de jouer. C'est la seule information dont le joueur a
	# besoin en permanence - le tour et les effectifs sont deja dans le badge
	# et le HUD lateral (cf. captures Figma 05).
	_turn_label = UiTheme.make_label("", 12, Color("e5e5f0"))
	_turn_label.add_theme_font_override("font", UiTheme.font_bold())
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_turn_label)

	_auto_button = _icon_button("skip", "AUTO", Color("1c2135"), Color("2a2f45"), Color("a0aabf"), 14, 11)
	_auto_label = _auto_button.find_child("Label", true, false)
	_auto_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_auto_pressed()
	)
	row.add_child(_auto_button)

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
		var margin := StyleBoxFlat.new()
		margin.set_corner_radius_all(8)
		margin.content_margin_left = 10
		margin.content_margin_right = 10
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
	_refresh_combat_status()


# ------------------------------- COMBAT : LE COUP DU JOUEUR ------------------

## Selectionne une piece et allume ses coups possibles. Pour changer d'avis,
## on tape une autre piece ou une case vide (cf. _on_combat_tap).
func _select_unit(unit: BattleUnit) -> void:
	if _busy or _auto or unit == null or unit.team != BattleUnit.TEAM_PLAYER:
		return
	if _selected_unit == unit:
		return
	_selected_unit = unit
	_grid_view.selected_cell = unit.cell
	_grid_view.legal_targets = _engine.legal_moves(unit)
	_grid_view.queue_redraw()


func _clear_selection() -> void:
	_selected_unit = null
	_grid_view.selected_cell = Vector2i(-1, -1)
	_grid_view.legal_targets = []
	_grid_view.queue_redraw()


## Tape sur le plateau pendant le combat : soit on choisit une piece, soit on
## envoie la piece deja choisie sur la case tapee.
func _on_combat_tap(cell: Vector2i) -> void:
	if _busy or _auto:
		return

	if _selected_unit != null and _grid_view.legal_targets.has(cell):
		_try_player_move(_selected_unit, cell)
		return

	# _select_unit ignore une piece deja selectionnee : taper deux fois la meme
	# piece ne l'eteint donc pas. C'est voulu - l'appui qui precede ce tap l'a
	# selectionnee il y a une fraction de seconde (cf. _on_cell_pressed), la
	# deselectionner aussitot donnerait un plateau qui ne repond pas.
	var unit: BattleUnit = _engine.grid.unit_at(cell)
	if unit != null and unit.team == BattleUnit.TEAM_PLAYER:
		_select_unit(unit)
	else:
		_clear_selection()


## Joue le coup demande par le joueur, puis laisse l'IA repondre. Un coup
## illegal ne consomme rien : le moteur retourne une liste vide et la piece
## reste selectionnee.
func _try_player_move(unit: BattleUnit, destination: Vector2i) -> void:
	if _busy or _auto or _phase != Phase.COMBAT:
		return

	var events: Array = _engine.play_move(unit, destination)
	if events.is_empty():
		_status_message("Ce coup n'est pas possible")
		return

	_busy = true
	_clear_selection()
	_grid_view.draggable_team = -1
	await _play_events(events)
	await _resume_until_player_turn()


## Enchaine tous les coups qui ne demandent rien au joueur : la reponse de
## l'IA, et un eventuel tour passe faute de coup legal. En mode AUTO, la
## boucle ne rend jamais la main et resout la bataille entiere.
func _resume_until_player_turn() -> void:
	while _running and not _engine.finished:
		_refresh_combat_status()
		var player_turn: bool = _engine.current_team == BattleUnit.TEAM_PLAYER
		if player_turn and not _auto and _engine.has_any_move(BattleUnit.TEAM_PLAYER):
			break

		await _wait(float(Balance.COMBAT["ai_think_delay"]))
		if not _running:
			return
		await _play_events(_engine.step())

	if not _running:
		return
	if _engine.finished:
		_show_result()
	else:
		_hand_over_to_player()


## Rend la main au joueur : ses pieces redeviennent saisissables.
func _hand_over_to_player() -> void:
	_busy = false
	_grid_view.draggable_team = BattleUnit.TEAM_PLAYER
	_refresh_combat_status()

	# Cas limite : c'est au joueur mais aucune de ses pieces ne peut bouger.
	# Le moteur passe alors son tour tout seul plutot que de figer la partie.
	if not _engine.finished and not _engine.has_any_move(BattleUnit.TEAM_PLAYER):
		_busy = true
		_grid_view.draggable_team = -1
		_status_message("Aucun coup possible - tu passes ton tour")
		await _resume_until_player_turn()


func _on_auto_pressed() -> void:
	_auto = not _auto
	if not _auto:
		_refresh_combat_status()
		return

	_clear_selection()
	if _busy or _engine.finished or _phase != Phase.COMBAT:
		_refresh_combat_status()
		return

	_busy = true
	_grid_view.draggable_team = -1
	await _resume_until_player_turn()


## Message temporaire dans le bandeau du bas ; le prochain rafraichissement
## de statut reprend la main.
func _status_message(text: String) -> void:
	if _turn_label != null:
		_turn_label.text = text


func _refresh_combat_status() -> void:
	_phase_label.text = str(_engine.turn)
	_refresh_stats_hud()
	_refresh_blockage_badge()
	_update_speed_pills(_speed)

	if _auto_label != null:
		_auto_label.text = "MANUEL" if _auto else "AUTO"

	if _turn_label == null:
		return
	if _engine.finished:
		_turn_label.text = "Bataille terminee"
	elif _auto:
		_turn_label.text = "Resolution automatique..."
	elif _engine.current_team == BattleUnit.TEAM_PLAYER and not _busy:
		_turn_label.text = "A toi de jouer"
	else:
		_turn_label.text = "L'ennemi joue..."


## N'apparait que passe _BLOCKAGE_WARNING_RATIO du seuil d'enlisement (cf.
## BattleEngine.stalemate_ratio) : le combat doit etre visiblement bloque
## depuis un moment, pas juste en train de manoeuvrer sans prise recente.
##
## En resolution automatique le compte a rebours s'exprime en secondes (le
## joueur regarde), en mode manuel en coups restants (le joueur joue, une
## seconde ne veut plus rien dire).
func _refresh_blockage_badge() -> void:
	if _blockage_badge == null or _engine.finished:
		return
	if _engine.stalemate_ratio() < _BLOCKAGE_WARNING_RATIO:
		_blockage_badge.visible = false
		return
	_blockage_badge.visible = true
	if _auto:
		var seconds := _engine.stalemate_seconds_remaining() / _speed
		_blockage_label.text = "Blocage - %ds" % maxi(1, int(ceil(seconds)))
	else:
		_blockage_label.text = "Blocage - %d coups" % maxi(1, _engine.stalemate_moves_remaining())


func _update_speed_pills(shown_speed: float) -> void:
	for speed in _speed_buttons.keys():
		var pill: PanelContainer = _speed_buttons[speed]
		var active: bool = speed == shown_speed
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(8)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		box.bg_color = Color("ffd700") if active else Color("1c2135")
		pill.add_theme_stylebox_override("panel", box)
		var label: Label = pill.get_child(0)
		label.add_theme_color_override("font_color", Color("0f111a") if active else Color("5a6480"))


## Rejoue les evenements d'un coup. Seules les DUREES dependent de la vitesse
## choisie : les evenements, eux, sont deja resolus.
func _play_events(events: Array) -> void:
	for event in events:
		if not _running:
			return
		match String(event["type"]):
			"capture":
				await _grid_view.play_capture(
					event["cell"], float(Balance.COMBAT["capture_duration"]) / _speed)
			"move":
				_grid_view.last_move = {"from": event["from"], "to": event["to"]}
				await _grid_view.play_move(
					int(event["unit"]), event["from"], event["to"],
					float(Balance.COMBAT["move_duration"]) / _speed)
			"promotion":
				await _grid_view.play_promotion(
					event["cell"], String(event["result"]),
					float(Balance.COMBAT["promotion_duration"]) / _speed)
			"pass":
				_status_message("Camp bloque : tour passe")
				await _wait(float(Balance.COMBAT["step_delay"]))
			_:
				pass


func _wait(seconds: float) -> void:
	var duration := maxf(0.01, seconds / _speed)
	await get_tree().create_timer(duration).timeout


# ------------------------------- PHASE RESULTAT ------------------------------

func _show_result() -> void:
	_phase = Phase.RESULT
	_running = false
	_clear_blockage_badge()
	var victory := _engine.winner == BattleUnit.TEAM_PLAYER
	var reward := Game.reward_for(int(_battle["id"]))
	var battle_id := int(_battle["id"])

	_grid_view.draggable_team = -1
	_grid_view.legal_targets = []

	# Les pertes sont definitives, victoire ou defaite : les pieces capturees
	# quittent l'armee et devront etre recrutees a nouveau.
	var losses: Dictionary = _engine.losses(BattleUnit.TEAM_PLAYER)
	Game.apply_losses(losses)

	# Les pions promus RENTRES VIVANTS deviennent des Dames stockees a la Tour
	# de la Dame : le joueur pourra les redeployer aux batailles suivantes.
	# Une Dame tombee au combat, elle, est perdue comme le pion qu'elle etait.
	var dames_gained := Game.store_promotions(_engine.promoted_survivors(BattleUnit.TEAM_PLAYER))

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

	# Modale generique (cf. scenes/ui/components/modal.gd) + illustration de
	# fond (confettis en victoire, braises en defaite) - cf. captures Figma
	# 06/07. Le blason (couronne / couronne brisee) a son propre halo circulaire,
	# trop specifique pour rester dans le header_icon integre de Modal : on le
	# construit ici plutot que de le forcer dans le composant generique.
	var modal: Modal = ModalScene.instantiate()
	modal.show_close_button = false
	modal.close_on_dim_click = false
	add_child(modal)
	modal.open("", Modal.Context.GOLD if victory else Modal.Context.RED)
	var bg_path := VICTORY_BG_PATH if victory else DEFEAT_BG_PATH
	if ResourceLoader.exists(bg_path):
		modal.set_background(load(bg_path), 0.35 if victory else 0.3)
	var body := modal.body

	body.add_child(_result_badge(victory))

	var stats_panel := _result_stats_panel()
	var stats_body: VBoxContainer = stats_panel.get_child(0)
	body.add_child(stats_panel)

	if victory:
		stats_body.add_child(_result_highlight_row("Récompense",
			_icon_value("coin", UiTheme.GOLD, "+%d Or" % reward, UiTheme.GOLD, 16), UiTheme.GOLD))
		stats_body.add_child(_stats_separator())
		stats_body.add_child(UiTheme.stat_row("Ennemis vaincus",
			_plain_value(str(enemies_defeated), Color("f0f3f8"), 14)))
		if dames_gained > 0:
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Dames ramenées",
				_icon_value("crown", Color("d8a0d0"),
					"+%d à la Tour de la Dame" % dames_gained, Color("d8a0d0"), 13)))
		if not losses.is_empty():
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Pertes", _plain_value(_format_losses(losses), Color("a0aabf"), 14)))
	else:
		if consolation > 0:
			stats_body.add_child(_result_highlight_row("Consolation",
				_icon_value("coin", Color("d4af37"), "+%d Or" % consolation, Color("d4af37"), 14), UiTheme.DANGER))
			stats_body.add_child(_stats_separator())
		var loss_text := "Aucune - toute l'armee rentre" if losses.is_empty() else _format_losses(losses)
		stats_body.add_child(UiTheme.stat_row("Pertes subies", _plain_value(loss_text, Color("a0aabf"), 14)))
		if dames_gained > 0:
			stats_body.add_child(_stats_separator())
			stats_body.add_child(UiTheme.stat_row("Dames ramenées",
				_icon_value("crown", Color("d8a0d0"),
					"+%d à la Tour de la Dame" % dames_gained, Color("d8a0d0"), 13)))

	# Boutons - cf. Button-Stack Figma 06/07 : victoire met en avant l'or
	# (bataille suivante) puis Reessayer ; defaite met Reessayer en avant sans
	# alternative. "Retour au village" et "Carte de campagne" restent
	# communs aux deux issues.
	if victory:
		if battle_id < Balance.battle_count():
			body.add_child(_result_primary_button("BATAILLE SUIVANTE",
				func(): Router.goto_prep(battle_id + 1)))
		body.add_child(_result_secondary_button("RÉESSAYER", Color("262c3f"), Color("2a2f45"),
			func(): Router.goto_battle(battle_id)))
	else:
		body.add_child(_result_danger_button("RÉESSAYER", func(): Router.goto_battle(battle_id)))

	body.add_child(_result_amber_button("RETOUR AU VILLAGE", "house", Router.goto_village))
	body.add_child(_result_amber_button("CARTE DE CAMPAGNE", "compass", Router.goto_campaign))


## Blason circulaire (couronne en victoire, couronne brisee en defaite) +
## grand titre - cf. Title-Block des captures Figma 06/07.
func _result_badge(victory: bool) -> VBoxContainer:
	var accent := UiTheme.GOLD if victory else UiTheme.DANGER

	var block := VBoxContainer.new()
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 10)

	var badge := PanelContainer.new()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Color(accent, 0.09)
	badge_box.border_color = accent
	badge_box.set_border_width_all(2)
	badge_box.set_corner_radius_all(36)
	badge_box.shadow_color = Color(accent, 0.33)
	badge_box.shadow_size = 10
	badge.add_theme_stylebox_override("panel", badge_box)
	badge.custom_minimum_size = Vector2(72, 72)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	block.add_child(badge)

	var glyph_wrap := CenterContainer.new()
	badge.add_child(glyph_wrap)
	var glyph := Icon.new()
	glyph.icon_name = "crown" if victory else "crown_broken"
	glyph.color = accent
	glyph.custom_minimum_size = Vector2(44, 44)
	glyph_wrap.add_child(glyph)

	var title := UiTheme.make_label("VICTOIRE" if victory else "DEFAITE", 32, accent)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	block.add_child(title)

	return block


## Carte de stats semi-transparente posee sur l'illustration de fond -
## cf. Stats-List des captures Figma 06/07.
func _result_stats_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1a2035", 0.8)
	box.border_color = Color("2a2f45")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(16)
	box.shadow_color = Color(0, 0, 0, 0.6)
	box.shadow_size = 10
	panel.add_theme_stylebox_override("panel", box)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	panel.add_child(body)

	return panel


## Ligne de stat mise en avant dans son propre encart teinte - cf. Reward-Row
## (victoire) / Consolation-Row (defaite) des captures Figma 06/07.
func _result_highlight_row(label_text: String, value: Control, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent, 0.06)
	box.border_color = Color(accent, 0.2)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(UiTheme.stat_row(label_text, value))
	return panel


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
## consolation) - cf. captures Figma 06/07.
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


## "4 Pions, 1 Cavalier" - une seule ligne, plutot que des jetons par type,
## cf. Losses-Row des nouvelles captures Figma 06/07.
func _format_losses(losses: Dictionary) -> String:
	var details: Array = []
	for type in Balance.ARMY_TYPES:
		if losses.has(type):
			details.append("%d %s" % [int(losses[type]), Balance.unit_name(type)])
	return ", ".join(details)


func _result_primary_button(text: String, on_press: Callable) -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.GOLD
	box.border_color = Color("b8860b")
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_top = 15
	box.content_margin_bottom = 15
	button.add_theme_stylebox_override("panel", box)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UiTheme.make_label(text, 14, Color("0f111a"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	return button


func _result_secondary_button(text: String, bg: Color, border: Color, on_press: Callable) -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.content_margin_top = 15
	box.content_margin_bottom = 15
	button.add_theme_stylebox_override("panel", box)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UiTheme.make_label(text, 14, Color("f0f3f8"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	return button


func _result_danger_button(text: String, on_press: Callable) -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("c0392b")
	box.border_color = UiTheme.DANGER
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.content_margin_top = 15
	box.content_margin_bottom = 15
	box.shadow_color = Color(UiTheme.DANGER, 0.27)
	box.shadow_size = 10
	button.add_theme_stylebox_override("panel", box)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UiTheme.make_label(text, 14, Color("f0f3f8"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	return button


## Bouton ambre discret - "Retour au village" / "Carte de campagne" des
## captures Figma 06/07, meme habillage que le bouton VILLAGE de l'ecran
## Campagne (cf. campaign.gd > _build_village_button).
func _result_amber_button(text: String, icon_name: String, on_press: Callable) -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("261a0d", 0.9)
	box.border_color = Color("99804d", 0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	button.add_theme_stylebox_override("panel", box)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)

	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = Color("d9c78c")
	icon.custom_minimum_size = Vector2(16, 16)
	row.add_child(icon)

	var label := UiTheme.make_label(text, 13, Color("d9c78c"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)

	UiTheme.ignore_mouse_recursive(row)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	return button


# ------------------------------- DIVERS --------------------------------------

func _clear_bottom() -> void:
	for child in _bottom.get_children():
		child.queue_free()
	_type_buttons.clear()
	_status_label = null
	_fight_button = null


func _on_quit() -> void:
	_running = false
	_clear_blockage_badge()
	Router.goto_village()
