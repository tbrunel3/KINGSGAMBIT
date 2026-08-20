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

## Tape simple sur une case (appui puis relachement au meme endroit).
signal cell_clicked(cell: Vector2i)
## Appui, avant meme de savoir si ce sera un tap ou un glisser : c'est ce qui
## permet de surligner les coups d'une piece des qu'on pose le doigt dessus.
signal cell_pressed(cell: Vector2i)
## Piece relachee sur une AUTRE case que celle de depart.
signal piece_dropped(from: Vector2i, to: Vector2i)

var engine: BattleEngine = null

## Cases ou la piece selectionnee peut aller (pastille) ou capturer (anneau).
## Remplies par l'ecran de bataille, qui seul connait les regles.
var legal_targets: Array = []

## Camp dont les pieces peuvent etre saisies au doigt. -1 = plateau en lecture
## seule (tour de l'IA, resolution automatique, ecran de resultat).
var draggable_team: int = -1

## Dernier coup joue, surligne discretement : sur un plateau ou l'adversaire
## repond entre deux de nos coups, on doit pouvoir voir ce qui a bouge.
## {"from": Vector2i, "to": Vector2i}
var last_move: Dictionary = {}

## Distance en pixels au-dela de laquelle un appui devient un glisser plutot
## qu'une tape. Assez large pour tolerer le tremblement d'un doigt.
const _DRAG_THRESHOLD := 8.0

var _press_cell: Vector2i = Vector2i(-1, -1)
var _press_point: Vector2 = Vector2.ZERO
var _pointer: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_unit_id: int = -1

## Zones de deploiement (pointilles rouge/bleu) : visibles pendant le
## placement, masquees pendant le combat - cf. captures Figma 04 vs 05, ou le
## terrain redevient un simple fond illustre une fois la bataille lancee.
var show_zones: bool = true
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

# Badge de promotion : petit et transitoire, plusieurs peuvent se succeder
# rapidement en fin de partie sans jamais se superposer (une seule activation
# a la fois).
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
#
#  Deux gestes pour un meme coup, parce que les deux sont naturels au doigt :
#  taper la piece puis taper la case d'arrivee, ou faire glisser la piece
#  jusqu'a sa case. La vue ne fait qu'emettre le geste ; c'est l'ecran de
#  bataille qui decide s'il est legal.

func _gui_input(event: InputEvent) -> void:
	if engine == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_press(event.position)
		else:
			_end_press(event.position)
	elif event is InputEventMouseMotion and _press_cell.x >= 0:
		_pointer = event.position
		if not _dragging and _pointer.distance_to(_press_point) > _DRAG_THRESHOLD:
			_dragging = _drag_unit_id != -1
		if _dragging:
			queue_redraw()


func _begin_press(point: Vector2) -> void:
	_reset_press()
	var cell := position_to_cell(point)
	if not engine.grid.in_bounds(cell):
		return

	_press_cell = cell
	_press_point = point
	_pointer = point

	# Seule une piece du camp jouable se souleve : le decor, lui, ne bouge pas.
	if draggable_team >= 0:
		var unit := engine.grid.unit_at(cell)
		if unit != null and unit.is_alive() and unit.team == draggable_team:
			_drag_unit_id = unit.id

	cell_pressed.emit(cell)


func _end_press(point: Vector2) -> void:
	var from := _press_cell
	var was_dragging := _dragging
	var had_piece := _drag_unit_id != -1
	_reset_press()
	queue_redraw()

	if from.x < 0:
		return

	var cell := position_to_cell(point)
	if was_dragging and had_piece and engine.grid.in_bounds(cell) and cell != from:
		piece_dropped.emit(from, cell)
	elif not was_dragging:
		cell_clicked.emit(from)


func _reset_press() -> void:
	_press_cell = Vector2i(-1, -1)
	_dragging = false
	_drag_unit_id = -1


## Vrai pendant qu'une piece suit le doigt : l'ecran de bataille s'en sert
## pour ne pas relancer d'animation par-dessus le geste en cours.
func is_dragging() -> bool:
	return _dragging


# ------------------------------- DESSIN --------------------------------------

func _draw() -> void:
	if engine == null:
		return
	_recompute_layout()
	if _cell_size < 2.0:
		# La grille n'a pas encore de taille utile (premiere image du layout).
		return
	_draw_cells()
	_draw_last_move()
	_draw_preview()
	_draw_legal_targets()
	for unit in engine.units:
		if unit.is_alive():
			_draw_unit(unit)
	_draw_dragged_piece()
	_draw_capture()
	_draw_promotion()


## Le terrain (assets/backgrounds/battlefield_background.png) est deja dessine
## derriere cette vue. Un quadrillage tres fin (cf. Battle-Grid, cellules
## Figma 04/05 : bordure 0.75px blanc 3% opacite) reste visible en
## permanence sur les deux ecrans ; seules les zones de deploiement teintees,
## en pointilles, disparaissent une fois le combat lance (show_zones = false).
func _draw_cells() -> void:
	var grid := engine.grid
	_draw_grid_lines(grid.cols, grid.rows)
	if show_zones:
		_draw_zone_rect(0, Balance.DEPLOY_ROWS, grid.cols,
			Color(0.851, 0.102, 0.051, 0.28), Color(1.0, 0.251, 0.149, 0.7))
		_draw_zone_rect(grid.player_zone_first_row(), grid.rows, grid.cols,
			Color(0.051, 0.302, 0.898, 0.28), Color(0.302, 0.6, 1.0, 0.7))

	if grid.in_bounds(selected_cell):
		var rect := Rect2(cell_to_position(selected_cell), Vector2(_cell_size, _cell_size))
		draw_rect(rect, UiTheme.GOLD, false, maxf(2.0, _cell_size * 0.08))


## Quadrillage plein plateau : chaque case a sa propre bordure fine, comme
## dans le fichier Figma (une bordure par cellule plutot qu'un trace unique) -
## les aretes partagees ressortent donc legerement plus marquees, exactement
## comme sur la maquette. La maquette declare une bordure blanche a 3%
## d'opacite, mais son rendu reel (export Figma) est nettement plus visible
## qu'un 3% brut ne le laisse penser sur le fond du terrain - on part donc du
## rendu observe plutot que de la valeur CSS litterale.
func _draw_grid_lines(cols: int, rows: int) -> void:
	var color := Color(1, 1, 1, 0.3)
	var width := maxf(1.25, _cell_size * 0.03)
	for row in range(rows):
		for col in range(cols):
			var pos := cell_to_position(Vector2i(col, row))
			draw_rect(Rect2(pos, Vector2(_cell_size, _cell_size)), color, false, width)


## Rectangle englobant d'une zone (toute la largeur, quelques rangees),
## rempli en transparence avec une bordure pointillee - jamais case par case,
## pour coller au rendu Figma plutot qu'a un damier de jeu de plateau.
func _draw_zone_rect(first_row: int, last_row: int, cols: int, fill: Color, border: Color) -> void:
	var top_left := cell_to_position(Vector2i(0, first_row))
	var bottom_right := cell_to_position(Vector2i(cols, last_row))
	var rect := Rect2(top_left, bottom_right - top_left)
	draw_rect(rect, fill)

	var width := maxf(1.5, _cell_size * 0.08)
	var dash := maxf(4.0, _cell_size * 0.18)
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in range(4):
		draw_dashed_line(corners[i], corners[(i + 1) % 4], border, width, dash, true)


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
	# La piece portee au doigt est dessinee a part, tout en haut de la pile.
	if unit.id == _drag_unit_id and _dragging:
		return

	var center := cell_center(unit.cell)

	# Deplacement en cours : on interpole entre les deux cases.
	if unit.id == _anim_unit:
		center = cell_center(_anim_from).lerp(cell_center(_anim_to), _anim_t)

	_draw_piece(unit, center, 1.0)


## Dessine une piece a un endroit donne du plateau. Le centre est passe en
## parametre plutot que deduit de la case : une piece peut etre en train de
## glisser d'une case a l'autre, ou de suivre le doigt du joueur.
func _draw_piece(unit: BattleUnit, center: Vector2, scale: float) -> void:
	# Hauteur relative a la case (18/24 sur une case de 31, cf. maquette
	# Figma 04/05) : le pion reste nettement plus petit que les autres
	# pieces, qui partagent toutes la meme hauteur.
	var height_fraction := (18.0 / 31.0) if unit.type == Balance.PION else (24.0 / 31.0)
	var height := _cell_size * height_fraction * scale
	var radius := height * 0.5
	var team_folder := "bleu" if unit.team == BattleUnit.TEAM_PLAYER else "rouge"
	var texture: Texture2D = _piece_textures.get("%s_%s" % [team_folder, unit.type])

	if texture != null:
		# La largeur suit le ratio naturel du sprite plutot qu'un carre, pour
		# ne pas deformer les silhouettes (un pion est nettement plus etroit
		# qu'une tour).
		var tex_size := texture.get_size()
		var width := height * (tex_size.x / tex_size.y) if tex_size.y > 0 else height
		var draw_size := Vector2(width, height)
		draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false)
	else:
		# Repli si un sprite manque : cercle + lettre, comme en Phase 1.
		var base := Balance.unit_color(unit.type)
		if unit.team == BattleUnit.TEAM_ENEMY:
			base = base.lerp(UiTheme.ENEMY, 0.55).darkened(0.1)
		draw_circle(center, radius, base)
		draw_arc(center, radius, 0.0, TAU, 24,
			UiTheme.TEXT if unit.team == BattleUnit.TEAM_PLAYER else UiTheme.ENEMY.lightened(0.3),
			maxf(1.5, _cell_size * 0.05))
		var font_size := maxi(8, int(_cell_size * 0.42 * scale))
		draw_string(ThemeDB.fallback_font, center + Vector2(-radius, font_size * 0.36),
			Balance.unit_letter(unit.type),
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, UiTheme.TEXT)

	# Une piece promue porte un lisere dore, pour la distinguer d'un coup
	# d'oeil - elle garde le type "Dame" mais reste rattachee a son pion
	# d'origine (voir BattleUnit.origin_type).
	if unit.promoted:
		draw_arc(center, radius * 1.18, 0.0, TAU, 24, UiTheme.GOLD, maxf(1.5, _cell_size * 0.04))


## Coups legaux de la piece selectionnee : une pastille sur une case vide, un
## anneau autour d'une piece a prendre. Deux formes distinctes plutot que deux
## couleurs : au doigt, sur un petit ecran, la forme se lit mieux.
func _draw_legal_targets() -> void:
	for cell in legal_targets:
		var center := cell_center(cell)
		var occupant := engine.grid.unit_at(cell)
		if occupant != null:
			draw_arc(center, _cell_size * 0.42, 0.0, TAU, 28,
				Color(UiTheme.GOLD, 0.9), maxf(2.0, _cell_size * 0.07))
		else:
			draw_circle(center, _cell_size * 0.14, Color(0.4, 0.75, 1.0, 0.75))


## Case de depart et case d'arrivee du dernier coup joue - surtout utile pour
## voir ce que l'adversaire vient de faire.
func _draw_last_move() -> void:
	if not last_move.has("from") or not last_move.has("to"):
		return
	var color := Color(1.0, 0.85, 0.3, 0.16)
	for key in ["from", "to"]:
		var cell: Vector2i = last_move[key]
		if engine.grid.in_bounds(cell):
			draw_rect(Rect2(cell_to_position(cell), Vector2(_cell_size, _cell_size)), color)


## Piece soulevee : elle suit le doigt, legerement agrandie, et la case
## survolee s'allume dessous.
func _draw_dragged_piece() -> void:
	if not _dragging or _drag_unit_id < 0:
		return
	var unit := engine.unit_by_id(_drag_unit_id)
	if unit == null or not unit.is_alive():
		return

	var hovered := position_to_cell(_pointer)
	if engine.grid.in_bounds(hovered):
		var rect := Rect2(cell_to_position(hovered), Vector2(_cell_size, _cell_size))
		var valid: bool = legal_targets.has(hovered)
		draw_rect(rect, Color(1.0, 0.82, 0.1, 0.22) if valid else Color(1, 1, 1, 0.06))
		if valid:
			draw_rect(rect, UiTheme.GOLD, false, maxf(2.0, _cell_size * 0.06))

	_draw_piece(unit, _pointer, 1.25)


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
## affichant la promotion en Dame. Volontairement compact : en fin de partie
## plusieurs pions peuvent promouvoir coup sur coup.
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
