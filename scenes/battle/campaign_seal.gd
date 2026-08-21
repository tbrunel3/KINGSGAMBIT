class_name CampaignSeal
extends Control
##
## CACHET DE BATAILLE - la pastille posee sur la carte de campagne, reprise de
## la maquette V2 (02_Campagne, frames level-N-seal).
##
## Trois etats, trois cires :
##   LOCKED     plomb pique de rouille - la bataille n'est pas encore ouverte
##   AVAILABLE  or vif - c'est la prochaine bataille a jouer
##   WON        cire pale, deja pressee - le terrain est conquis
##
## La derniere bataille - la Tour de la Dame - n'est pas un cachet mais un
## MEDAILLON : un grand disque sombre cercle d'or, la tour gravee au centre.
## C'est le bout du chemin, il doit se voir depuis le bas de la carte.
##
## Le fond de cire vient de la maquette en PNG. C'est le seul morceau importe :
## il empile un degrade, une ombre portee et une ombre interne, soit trois
## filtres SVG que l'import vectoriel de Godot n'applique pas (cf. CLAUDE.md).
## Tout le reste - anneau interieur, gouttes de cire, taches de rouille - est
## du trace plein, dessine ici, net a n'importe quelle definition.
##

signal pressed(battle_id: int)

enum State { LOCKED, AVAILABLE, WON }

## Diametre du cachet et du medaillon, en unites de la maquette.
const SIZE := 64.0
const MEDALLION_SIZE := 160.0

const BASE_TEXTURES := {
	State.WON: preload("res://assets/campaign/seal_won_base.png"),
	State.AVAILABLE: preload("res://assets/campaign/seal_available_base.png"),
	State.LOCKED: preload("res://assets/campaign/marker_locked_base.png"),
}
const TOWER_TEXTURE := preload("res://assets/campaign/level10_inner.png")

## Le PNG de cire mesure 76 unites de cote pour un disque de 64 : l'ombre
## portee deborde. Son disque est centre sur (38, 36) de l'image.
const BASE_TEXTURE_SIZE := Vector2(76, 76)
const BASE_TEXTURE_CENTER := Vector2(38, 36)

const INNER_FILL := {
	State.WON: Color("f5d87a"),
	State.AVAILABLE: Color("ffc71a"),
	State.LOCKED: Color("c4a265"),
}
const INNER_STROKE := {
	State.WON: Color("8b6914"),
	State.AVAILABLE: Color("8b6914"),
	State.LOCKED: Color("6b4f1a"),
}
const DRIP_STROKE := {
	State.WON: Color("b8860b"),
	State.AVAILABLE: Color("d99900"),
}

const NUMBER_COLOR := Color("3d2005")
const LOCK_COLOR := Color("2b1a0a", 0.85)
const RUST_COLOR := Color("8b6914")

const MEDALLION_DISC := Color("473826")
const MEDALLION_RING := Color("d9a621")
const MEDALLION_RING_LOCKED := Color("8a6a2a")
const MEDALLION_LOCK_COLOR := Color("9e8a6e", 0.7)

var battle_id: int = 1
var is_final: bool = false

var _state: State = State.LOCKED
var _number: Label
var _lock: Icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0
	_build_glyphs()
	_refresh_glyphs()


## Cachet ordinaire (1) ou medaillon de fin de campagne (2) : c'est l'appelant
## qui le dit, avant d'entrer dans l'arbre.
func setup(id: int, final: bool = false) -> void:
	battle_id = id
	is_final = final
	var diameter := MEDALLION_SIZE if final else SIZE
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size


func set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	_refresh_glyphs()
	queue_redraw()


func state() -> State:
	return _state


## Rayon du disque, en pixels ecran. Sert aussi a la carte pour poser le halo
## du medaillon sans redire la taille.
func radius() -> float:
	return size.x / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(battle_id)


# ------------------------------- GLYPHES -------------------------------------
#
#  Le numero et le cadenas sont des noeuds enfants plutot que du texte dessine :
#  ils suivent ainsi la police du theme, et le cadenas reste le meme glyphe
#  vectoriel que partout ailleurs dans le jeu (cf. icon.gd - aucun emoji, ils
#  rendent en tofu a l'export Web).

func _build_glyphs() -> void:
	_number = UiTheme.make_label(str(battle_id), 22, NUMBER_COLOR)
	_number.add_theme_font_override("font", UiTheme.font_black())
	_number.autowrap_mode = TextServer.AUTOWRAP_OFF
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.set_anchors_preset(Control.PRESET_FULL_RECT)
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_number)

	_lock = Icon.new()
	_lock.icon_name = "lock"
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock)


func _refresh_glyphs() -> void:
	if _number == null:
		return

	# Le medaillon ne porte pas de numero : la tour gravee dit deja de quelle
	# bataille il s'agit.
	_number.visible = not is_final and _state != State.LOCKED
	_lock.visible = _state == State.LOCKED

	if is_final:
		_lock.color = MEDALLION_LOCK_COLOR
		_lock.size = Vector2(34, 34)
		_lock.position = (size - _lock.size) / 2.0
	else:
		_lock.color = LOCK_COLOR
		_lock.size = Vector2(22, 22)
		_lock.position = (size - _lock.size) / 2.0


# ------------------------------- TRACE ---------------------------------------

func _draw() -> void:
	if is_final:
		_draw_medallion()
	else:
		_draw_seal()


func _draw_seal() -> void:
	var center := size / 2.0
	var scale := size.x / SIZE

	draw_texture_rect(BASE_TEXTURES[_state], Rect2(
		center - BASE_TEXTURE_CENTER * scale, BASE_TEXTURE_SIZE * scale), false)

	# Anneau interieur : disque plein cercle d'un trait fin, comme la cire
	# retassee au centre du cachet.
	draw_circle(center, 26.0 * scale, INNER_FILL[_state])
	draw_arc(center, 25.25 * scale, 0.0, TAU, 48, INNER_STROKE[_state], 1.5 * scale, true)

	if _state == State.LOCKED:
		# Deux taches de rouille, hors centre : le plomb a pris l'humidite.
		draw_circle(center + Vector2(-10, -10) * scale, 3.0 * scale, Color(RUST_COLOR, 0.6))
		draw_circle(center + Vector2(12, 8) * scale, 2.0 * scale, Color(RUST_COLOR, 0.55))
		return

	# Deux gouttes de cire echappees sous le cachet.
	var fill: Color = INNER_FILL[_state]
	var stroke: Color = DRIP_STROKE[_state]
	_draw_drop(center + Vector2(0, 35) * scale, Vector2(5, 3) * scale,
		Color(fill, 0.9), Color(stroke, 0.9), scale)
	_draw_drop(center + Vector2(0, 41.5) * scale, Vector2(4, 2.5) * scale,
		Color(fill, 0.85), Color(stroke, 0.85), scale)


func _draw_medallion() -> void:
	var center := size / 2.0
	var scale := size.x / MEDALLION_SIZE
	var lit := _state != State.LOCKED

	draw_circle(center, 80.0 * scale, MEDALLION_DISC)
	draw_arc(center, 82.5 * scale, 0.0, TAU, 96,
		MEDALLION_RING if lit else MEDALLION_RING_LOCKED, 5.0 * scale, true)

	# La tour, gravee dans le disque. Elle sort de l'ombre quand la bataille
	# s'ouvre - c'est toute la promesse de la campagne.
	var tint := Color(1, 1, 1, 0.85 if lit else 0.45)
	draw_texture_rect(TOWER_TEXTURE,
		Rect2(center - Vector2(75, 75) * scale, Vector2(150, 150) * scale), false, tint)


## Goutte de cire : une ellipse pleine, cerclee d'un trait plus fonce.
func _draw_drop(center: Vector2, radii: Vector2, fill: Color, stroke: Color,
		scale: float) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, stroke, maxf(1.0, scale), true)
