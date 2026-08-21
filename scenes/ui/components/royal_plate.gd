class_name RoyalPlate
extends MarginContainer
##
## PLAQUE ROYALE - le panneau bleu cercle d'or de la maquette V2.
##
## Introduite par l'ecran de preparation (Figma preparation-bataille-v2), cette
## plaque est la brique visuelle de la V2 : un rectangle arrondi rempli d'un
## degrade bleu nuit, cerclee d'un trait d'or epais, et doublee a l'interieur
## d'un filet d'or fin qui suit exactement la zone de contenu.
##
## Tout en sort : le panneau des armees, les cartes d'unite, la banniere rouge
## "ARMEE ENNEMIE", le bouton retour, la pastille "PRET", la coque doree du
## bouton d'action. Seuls changent les couleurs, le rayon et l'epaisseur.
##
## Pourquoi un trace plutot qu'un StyleBoxFlat : StyleBoxFlat ne sait pas
## remplir en degrade, et c'est justement le degrade vertical qui donne a la
## plaque son relief de metal. Le trace au polygone colore par sommet le rend
## exactement, a n'importe quelle taille, sans texture a embarquer.
##
## Usage :
##   var plate := RoyalPlate.new()
##   plate.set_padding(14, 28, 14, 18)
##   plate.add_child(mon_contenu)
##

## Degrade de remplissage, du haut vers le bas. Deux ou trois teintes.
@export var fill_colors: PackedColorArray = PackedColorArray([
	Color("1e3278"), Color("0a1230"), Color("0e1a40")])

## Degrade horizontal plutot que vertical (la banniere "ARMEE ENNEMIE").
@export var gradient_horizontal: bool = false

@export var border_color: Color = Color("ffe680")
@export var border_width: float = 4.0
@export var corner_radius: float = 16.0

## Filet interieur, pose sur le rectangle de contenu (donc sur les marges).
## Transparent = pas de filet.
@export var inner_outline_color: Color = Color("ffd700", 0.31)
@export var inner_outline_width: float = 1.5
@export var inner_radius: float = 10.0

## Reflet en haut de la plaque, l'equivalent du `shadow-[inset_0_3px_...]`
## de la maquette : une lumiere posee sur la tranche superieure.
@export var highlight_alpha: float = 0.13

## Losange serti a cheval sur le bord superieur (plaque de titre). Transparent
## = pas d'ornement.
@export var ornament_color: Color = Color(0, 0, 0, 0)
@export var ornament_border: Color = Color("c8960c")
@export var ornament_size: float = 18.0

const CORNER_SEGMENTS := 6


func _ready() -> void:
	resized.connect(queue_redraw)


func set_padding(left: int, top: int, right: int, bottom: int) -> void:
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)


func set_padding_all(value: int) -> void:
	set_padding(value, value, value, value)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	# Remplissage : un seul polygone arrondi, colore sommet par sommet. Godot
	# interpole les couleurs sur les triangles, ce qui donne le degrade sans
	# aucune texture.
	var fill := rounded_rect(rect, corner_radius)
	var colors := PackedColorArray()
	for point in fill:
		var span := rect.size.x if gradient_horizontal else rect.size.y
		var along := point.x if gradient_horizontal else point.y
		var t := along / maxf(1.0, span)
		colors.append(_color_at(t))
	draw_polygon(fill, colors)

	if highlight_alpha > 0.0:
		var top := Rect2(rect.position + Vector2(corner_radius, border_width),
			Vector2(maxf(0.0, rect.size.x - corner_radius * 2.0), 3.0))
		draw_rect(top, Color(1, 1, 1, highlight_alpha))

	if border_width > 0.0 and border_color.a > 0.0:
		# Bordure INTERIEURE, comme en CSS : le trait est centre sur un
		# rectangle rentre d'une demi-epaisseur, sinon il deborde de la plaque.
		_stroke(rect.grow(-border_width / 2.0),
			corner_radius - border_width / 2.0, border_color, border_width)

	if inner_outline_color.a > 0.0 and inner_outline_width > 0.0:
		var inset := Rect2(
			Vector2(get_theme_constant("margin_left"), get_theme_constant("margin_top")),
			size - Vector2(
				get_theme_constant("margin_left") + get_theme_constant("margin_right"),
				get_theme_constant("margin_top") + get_theme_constant("margin_bottom")))
		if inset.size.x > 0.0 and inset.size.y > 0.0:
			_stroke(inset, inner_radius, inner_outline_color, inner_outline_width)

	if ornament_color.a > 0.0:
		_draw_ornament(Vector2(rect.size.x / 2.0, 0.0))


## Le losange de la plaque de titre : un carre tourne d'un huitieme de tour,
## pose a cheval sur la tranche haute. Dessine ici plutot qu'ajoute en enfant -
## un MarginContainer replacerait l'enfant dans sa zone de contenu, et le
## losange doit justement en sortir.
func _draw_ornament(center: Vector2) -> void:
	var half := ornament_size / 2.0 * sqrt(2.0)
	var points := PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])
	draw_colored_polygon(points, ornament_color)
	points.append(points[0])
	draw_polyline(points, ornament_border, 2.5, true)


func _stroke(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var points := rounded_rect(rect, radius)
	points.append(points[0])
	draw_polyline(points, color, width, true)


func _color_at(t: float) -> Color:
	if fill_colors.is_empty():
		return Color(0, 0, 0, 0)
	if fill_colors.size() == 1:
		return fill_colors[0]
	var scaled := clampf(t, 0.0, 1.0) * float(fill_colors.size() - 1)
	var index := clampi(int(scaled), 0, fill_colors.size() - 2)
	return fill_colors[index].lerp(fill_colors[index + 1], scaled - float(index))


## Contour d'un rectangle a coins arrondis, dans le sens horaire.
static func rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var r := clampf(radius, 0.0, minf(rect.size.x, rect.size.y) / 2.0)
	var points := PackedVector2Array()
	var corners := [
		{"center": rect.position + Vector2(r, r), "from": PI},
		{"center": rect.position + Vector2(rect.size.x - r, r), "from": -PI / 2.0},
		{"center": rect.position + Vector2(rect.size.x - r, rect.size.y - r), "from": 0.0},
		{"center": rect.position + Vector2(r, rect.size.y - r), "from": PI / 2.0},
	]
	for corner in corners:
		var center: Vector2 = corner["center"]
		var from: float = corner["from"]
		for i in range(CORNER_SEGMENTS + 1):
			var angle := from + (PI / 2.0) * float(i) / float(CORNER_SEGMENTS)
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
