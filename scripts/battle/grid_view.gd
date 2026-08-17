extends Control
##
## VUE DE LA GRILLE - tout l'affichage du champ de bataille.
##
## Rien ici ne decide du jeu : la vue lit le moteur et le dessine. Les formes
## sont des placeholders (cercles + lettre + barre de vie) volontairement
## basiques : en Phase 2, _draw_unit sera remplace par des sprites sans qu'une
## seule regle de combat ait a bouger.
##
## La taille des cases est calculee a partir de la place disponible, donc
## n'importe quelle grille definie dans Balance.CAMPAIGN s'affiche correctement.
##

signal cell_clicked(cell: Vector2i)

var engine: BattleEngine = null

## Cases mises en avant (zone de deploiement pendant le placement).
var highlighted: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)

var _cell_size: float = 32.0
var _origin: Vector2 = Vector2.ZERO

# Animation en cours. Une seule a la fois : les activations sont sequentielles.
var _anim_unit: int = -1
var _anim_from: Vector2i = Vector2i.ZERO
var _anim_to: Vector2i = Vector2i.ZERO
var _anim_t: float = 0.0

var _flash_unit: int = -1
var _flash_target: int = -1
var _flash_t: float = 0.0


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(true)


func setup(battle_engine: BattleEngine) -> void:
	engine = battle_engine
	queue_redraw()


func _process(_delta: float) -> void:
	if _anim_unit != -1 or _flash_unit != -1:
		queue_redraw()


# ------------------------------- GEOMETRIE -----------------------------------

func _recompute_layout() -> void:
	if engine == null:
		return
	var cols := float(engine.grid.cols)
	var rows := float(engine.grid.rows)
	_cell_size = minf(size.x / cols, size.y / rows)
	_origin = Vector2(
		(size.x - _cell_size * cols) * 0.5,
		(size.y - _cell_size * rows) * 0.5
	)


func cell_to_position(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell.x, cell.y) * _cell_size


func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_position(cell) + Vector2(_cell_size, _cell_size) * 0.5


func position_to_cell(point: Vector2) -> Vector2i:
	var local := (point - _origin) / _cell_size
	return Vector2i(floori(local.x), floori(local.y))


# ------------------------------- ENTREE --------------------------------------

func _gui_input(event: InputEvent) -> void:
	if engine == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := position_to_cell(event.position)
		if engine.grid.in_bounds(cell):
			cell_clicked.emit(cell)


# ------------------------------- DESSIN --------------------------------------

func _draw() -> void:
	if engine == null:
		return
	_recompute_layout()
	if _cell_size < 2.0:
		# La grille n'a pas encore de taille utile (premiere image du layout).
		return
	_draw_cells()
	for unit in engine.units:
		if unit.is_alive():
			_draw_unit(unit)


func _draw_cells() -> void:
	var grid := engine.grid
	for y in range(grid.rows):
		for x in range(grid.cols):
			var cell := Vector2i(x, y)
			var rect := Rect2(cell_to_position(cell), Vector2(_cell_size, _cell_size))

			var color := UiTheme.PANEL if (x + y) % 2 == 0 else UiTheme.PANEL_LIGHT
			if grid.is_player_zone(cell):
				color = color.lerp(UiTheme.ACCENT, 0.16)
			elif grid.is_enemy_zone(cell):
				color = color.lerp(UiTheme.ENEMY, 0.13)
			draw_rect(rect, color)

			if highlighted.has(cell):
				draw_rect(rect, UiTheme.SUCCESS, false, maxf(2.0, _cell_size * 0.06))
			if cell == selected_cell:
				draw_rect(rect, UiTheme.GOLD, false, maxf(2.0, _cell_size * 0.08))

	# Contour general du plateau
	var board := Rect2(_origin, Vector2(grid.cols, grid.rows) * _cell_size)
	draw_rect(board, UiTheme.BORDER, false, 2.0)


func _draw_unit(unit: BattleUnit) -> void:
	var center := cell_center(unit.cell)

	# Deplacement en cours : on interpole entre les deux cases.
	if unit.id == _anim_unit:
		center = cell_center(_anim_from).lerp(cell_center(_anim_to), _anim_t)

	var radius := _cell_size * 0.36
	var base := Balance.unit_color(unit.type)
	if unit.team == BattleUnit.TEAM_ENEMY:
		base = base.lerp(UiTheme.ENEMY, 0.55).darkened(0.1)

	# Flash blanc sur l'attaquant et sa cible.
	if unit.id == _flash_unit or unit.id == _flash_target:
		base = base.lerp(Color.WHITE, 0.55 * (1.0 - _flash_t))

	draw_circle(center, radius, base)
	draw_arc(center, radius, 0.0, TAU, 24,
		UiTheme.TEXT if unit.team == BattleUnit.TEAM_PLAYER else UiTheme.ENEMY.lightened(0.3),
		maxf(1.5, _cell_size * 0.05))

	var font := ThemeDB.fallback_font
	var font_size := maxi(8, int(_cell_size * 0.4))
	var letter := Balance.unit_letter(unit.type)
	draw_string(font, center + Vector2(-radius, font_size * 0.36), letter,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, UiTheme.TEXT)

	_draw_health_bar(unit, center, radius)


func _draw_health_bar(unit: BattleUnit, center: Vector2, radius: float) -> void:
	var width := radius * 2.0
	var height := maxf(3.0, _cell_size * 0.08)
	var origin := center + Vector2(-radius, radius + height * 0.4)

	draw_rect(Rect2(origin, Vector2(width, height)), UiTheme.BG)
	var ratio := clampf(float(unit.hp) / float(unit.max_hp), 0.0, 1.0)
	var color := UiTheme.SUCCESS
	if ratio < 0.6:
		color = UiTheme.GOLD
	if ratio < 0.3:
		color = UiTheme.DANGER
	draw_rect(Rect2(origin, Vector2(width * ratio, height)), color)


# ------------------------------- ANIMATIONS ----------------------------------
#
#  Ces methodes sont attendues par le controleur de bataille, qui leur passe une
#  duree deja divisee par la vitesse choisie (x1 / x2 / x4).

func play_move(unit_id: int, from: Vector2i, to: Vector2i, duration: float) -> void:
	_anim_unit = unit_id
	_anim_from = from
	_anim_to = to
	_anim_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_anim_t", 1.0, maxf(0.01, duration))
	await tween.finished
	_anim_unit = -1
	queue_redraw()


func play_attack(unit_id: int, target_id: int, duration: float) -> void:
	_flash_unit = unit_id
	_flash_target = target_id
	_flash_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_flash_t", 1.0, maxf(0.01, duration))
	await tween.finished
	_flash_unit = -1
	_flash_target = -1
	queue_redraw()
