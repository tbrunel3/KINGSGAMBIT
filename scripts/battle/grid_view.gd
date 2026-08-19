extends Control
##
## VUE DE LA GRILLE - tout l'affichage du champ de bataille.
##
## Rien ici ne decide du jeu : la vue lit le moteur et le dessine. Les pieces
## sont des sprites (assets/pieces/{bleu,rouge}/*.png) ; si un sprite manque,
## on replie sur un cercle + lettre pour ne jamais planter.
##
## La taille des cases est calculee a partir de la place disponible, donc
## n'importe quelle grille definie dans Balance.CAMPAIGN s'affiche correctement
## - aucune des tailles fixes du mockup Figma n'est codee en dur ici.
##

signal cell_clicked(cell: Vector2i)

var engine: BattleEngine = null

## Cases mises en avant (zone de deploiement pendant le placement).
var highlighted: Array = []
var selected_cell: Vector2i = Vector2i(-1, -1)

## Apercu des premiers deplacements, affiche pendant le placement.
## Chaque entree : {"from": Vector2i, "to": Vector2i, "team": int, "capture": bool}
var preview_moves: Array = []

var _cell_size: float = 32.0
var _origin: Vector2 = Vector2.ZERO

# Animation en cours. Une seule a la fois : les activations sont sequentielles.
var _anim_unit: int = -1
var _anim_from: Vector2i = Vector2i.ZERO
var _anim_to: Vector2i = Vector2i.ZERO
var _anim_t: float = 0.0

var _capture_cell: Vector2i = Vector2i(-1, -1)
var _capture_t: float = 0.0

# Badge de loterie de promotion : petit et transitoire, plusieurs peuvent se
# succeder rapidement en fin de partie sans jamais se superposer (une seule
# activation a la fois).
var _promotion_cell: Vector2i = Vector2i(-1, -1)
var _promotion_type: String = ""
var _promotion_t: float = 0.0


## "bleu_pion" -> Texture2D. Charge une seule fois, jamais dans _draw().
var _piece_textures: Dictionary = {}


func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(true)
	_load_piece_textures()


func _load_piece_textures() -> void:
	for team_folder in ["bleu", "rouge"]:
		for type in [Balance.PION, Balance.CAVALIER, Balance.FOU, Balance.TOUR, Balance.DAME]:
			var path := "res://assets/pieces/%s/%s.png" % [team_folder, type]
			if ResourceLoader.exists(path):
				_piece_textures["%s_%s" % [team_folder, type]] = load(path)


func setup(battle_engine: BattleEngine) -> void:
	engine = battle_engine
	queue_redraw()


func _process(_delta: float) -> void:
	if _anim_unit != -1 or _capture_cell.x != -1 or _promotion_cell.x != -1:
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
	_draw_preview()
	for unit in engine.units:
		if unit.is_alive():
			_draw_unit(unit)
	_draw_capture()
	_draw_promotion()


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

	var board := Rect2(_origin, Vector2(grid.cols, grid.rows) * _cell_size)
	draw_rect(board, UiTheme.BORDER, false, 2.0)


## Fleches d'apercu : ou chaque piece ira a sa premiere activation.
func _draw_preview() -> void:
	for move in preview_moves:
		var from: Vector2i = move["from"]
		var to: Vector2i = move["to"]
		if from == to:
			continue

		var is_player: bool = int(move["team"]) == BattleUnit.TEAM_PLAYER
		var color: Color = UiTheme.SUCCESS if is_player else UiTheme.ENEMY.lightened(0.15)
		if bool(move.get("capture", false)):
			color = UiTheme.GOLD
		color.a = 0.85 if is_player else 0.5

		_draw_arrow(cell_center(from), cell_center(to), color)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	var direction := (to - from).normalized()
	var margin := _cell_size * 0.34
	var start := from + direction * margin
	var end := to - direction * margin * 0.8
	var width := maxf(1.5, _cell_size * 0.045)

	draw_line(start, end, color, width)

	# Pointe : deux traits ramenes vers l'arriere.
	var head := _cell_size * 0.16
	var left := direction.rotated(2.6) * head
	var right := direction.rotated(-2.6) * head
	draw_line(end, end + left, color, width)
	draw_line(end, end + right, color, width)


func _draw_unit(unit: BattleUnit) -> void:
	var center := cell_center(unit.cell)

	# Deplacement en cours : on interpole entre les deux cases.
	if unit.id == _anim_unit:
		center = cell_center(_anim_from).lerp(cell_center(_anim_to), _anim_t)

	var radius := _cell_size * 0.36
	var team_folder := "bleu" if unit.team == BattleUnit.TEAM_PLAYER else "rouge"
	var texture: Texture2D = _piece_textures.get("%s_%s" % [team_folder, unit.type])

	if texture != null:
		var size := radius * 2.0
		draw_texture_rect(texture, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false)
	else:
		# Repli si un sprite manque : cercle + lettre, comme en Phase 1.
		var base := Balance.unit_color(unit.type)
		if unit.team == BattleUnit.TEAM_ENEMY:
			base = base.lerp(UiTheme.ENEMY, 0.55).darkened(0.1)
		draw_circle(center, radius, base)
		draw_arc(center, radius, 0.0, TAU, 24,
			UiTheme.TEXT if unit.team == BattleUnit.TEAM_PLAYER else UiTheme.ENEMY.lightened(0.3),
			maxf(1.5, _cell_size * 0.05))
		var font_size := maxi(8, int(_cell_size * 0.42))
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, font_size * 0.36),
			Balance.unit_letter(unit.type),
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, UiTheme.TEXT)

	# Une piece promue (loterie) porte un lisere dore, pour la distinguer
	# d'un coup d'oeil, quel que soit le resultat du tirage.
	if unit.promoted:
		draw_arc(center, radius * 1.18, 0.0, TAU, 24, UiTheme.GOLD, maxf(1.5, _cell_size * 0.04))


## Marque brievement la case ou une piece vient d'etre capturee.
func _draw_capture() -> void:
	if _capture_cell.x < 0:
		return
	var center := cell_center(_capture_cell)
	var radius := _cell_size * 0.4 * (1.0 - _capture_t * 0.5)
	var color := UiTheme.DANGER
	color.a = 1.0 - _capture_t
	var width := maxf(2.0, _cell_size * 0.07)
	draw_line(center + Vector2(-radius, -radius), center + Vector2(radius, radius), color, width)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, width)


## Petit badge flottant qui monte et s'estompe au-dessus de la case,
## affichant le resultat de la loterie de promotion. Volontairement compact :
## en fin de partie plusieurs pions peuvent promouvoir coup sur coup.
func _draw_promotion() -> void:
	if _promotion_cell.x < 0:
		return
	var center := cell_center(_promotion_cell)
	var radius := _cell_size * 0.36
	var rise := _cell_size * 0.6 * _promotion_t
	var pos := center + Vector2(0, -radius * 1.5 - rise)
	var fade := 1.0 - _promotion_t

	var color := Balance.unit_color(_promotion_type)
	color.a = fade
	var badge_radius := _cell_size * 0.22

	draw_circle(pos, badge_radius, color)
	var ring := UiTheme.GOLD
	ring.a = fade
	draw_arc(pos, badge_radius, 0.0, TAU, 16, ring, maxf(1.0, _cell_size * 0.035))

	var font := ThemeDB.fallback_font
	var font_size := maxi(7, int(_cell_size * 0.28))
	var text_color := UiTheme.TEXT
	text_color.a = fade
	draw_string(font, pos + Vector2(-badge_radius, font_size * 0.32),
		Balance.unit_letter(_promotion_type),
		HORIZONTAL_ALIGNMENT_CENTER, badge_radius * 2.0, font_size, text_color)


func play_promotion(cell: Vector2i, result_type: String, duration: float) -> void:
	_promotion_cell = cell
	_promotion_type = result_type
	_promotion_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_promotion_t", 1.0, maxf(0.01, duration))
	await tween.finished
	_promotion_cell = Vector2i(-1, -1)
	queue_redraw()


# ------------------------------- ANIMATIONS ----------------------------------
#
#  Ces methodes sont appelees par le controleur de bataille, qui leur passe une
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


func play_capture(cell: Vector2i, duration: float) -> void:
	_capture_cell = cell
	_capture_t = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_capture_t", 1.0, maxf(0.01, duration))
	await tween.finished
	_capture_cell = Vector2i(-1, -1)
	queue_redraw()
