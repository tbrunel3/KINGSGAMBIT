class_name Icon
extends Control
##
## ICONE VECTORIELLE - glyphe dessine a la main, sans dependance a une police
## emoji.
##
## Les emojis (🔒 ⚔ 🏠...) evoques dans CLAUDE.md rendent en tofu (carre vide)
## sur l'export Web : la police par defaut de Godot n'embarque pas ces
## glyphes, et le systeme n'a pas acces aux polices emoji du systeme
## d'exploitation dans un contexte WASM. Un trace vectoriel garantit un rendu
## identique sur toutes les plateformes, y compris le Web.
##
## Usage : instancier icon.tscn, ou construire a la volee :
##   var icon := Icon.new()
##   icon.icon_name = "lock"
##   icon.color = UiTheme.TEXT_DIM
##

@export_enum("lock", "wrench", "star", "check", "close", "diamond", "sword", "house", "crown", "crown_broken", "compass", "coin", "dot", "pause", "skip", "arrow_left", "clock", "info") var icon_name: String = "star"
@export var color: Color = Color.WHITE
@export var line_width: float = 1.8


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(18, 18)


func set_icon(name: String, icon_color: Color = color) -> void:
	icon_name = name
	color = icon_color
	queue_redraw()


func _draw() -> void:
	var r := get_rect()
	var s := minf(r.size.x, r.size.y)
	var c := r.size * 0.5
	var lw := maxf(1.0, s * (line_width / 18.0))

	match icon_name:
		"lock":
			_draw_lock(c, s, lw)
		"wrench":
			_draw_wrench(c, s, lw)
		"star":
			_draw_star(c, s)
		"check":
			_draw_check(c, s, lw)
		"close":
			_draw_close(c, s, lw)
		"diamond":
			_draw_diamond(c, s)
		"sword":
			_draw_sword(c, s, lw)
		"house":
			_draw_house(c, s, lw)
		"crown":
			_draw_crown(c, s, lw)
		"crown_broken":
			_draw_crown_broken(c, s, lw)
		"compass":
			_draw_compass(c, s, lw)
		"coin":
			_draw_coin(c, s, lw)
		"dot":
			draw_circle(c, s * 0.32, color)
		"pause":
			_draw_pause(c, s)
		"skip":
			_draw_skip(c, s)
		"arrow_left":
			_draw_arrow_left(c, s, lw)
		"clock":
			_draw_clock(c, s, lw)
		"info":
			_draw_info(c, s, lw)


func _draw_lock(c: Vector2, s: float, lw: float) -> void:
	var body_h := s * 0.5
	var body_w := s * 0.72
	var body_top := c.y - s * 0.05
	var body := Rect2(c.x - body_w * 0.5, body_top, body_w, body_h)
	draw_rect(body, color, true)

	var shackle_r := s * 0.24
	var shackle_center := Vector2(c.x, body_top - shackle_r * 0.15)
	draw_arc(shackle_center, shackle_r, PI, TAU, 20, color, lw, true)
	draw_line(Vector2(shackle_center.x - shackle_r, shackle_center.y), Vector2(shackle_center.x - shackle_r, body_top + 1), color, lw, true)
	draw_line(Vector2(shackle_center.x + shackle_r, shackle_center.y), Vector2(shackle_center.x + shackle_r, body_top + 1), color, lw, true)

	var keyhole_r := s * 0.06
	draw_circle(Vector2(c.x, body_top + body_h * 0.4), keyhole_r, color.darkened(0.5) if color.v > 0.5 else Color(0, 0, 0, 0.001))


func _draw_wrench(c: Vector2, s: float, lw: float) -> void:
	var half := s * 0.34
	var a := c + Vector2(-half, half)
	var b := c + Vector2(half, -half)
	draw_line(a, b, color, lw * 1.6, true)
	draw_arc(a, s * 0.16, 0, TAU, 16, color, lw, true)
	draw_arc(b, s * 0.16, 0, TAU, 16, color, lw, true)


func _draw_star(c: Vector2, s: float) -> void:
	var outer := s * 0.46
	var inner := outer * 0.42
	var points := PackedVector2Array()
	for i in range(10):
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _draw_check(c: Vector2, s: float, lw: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(-s * 0.28, 0.0),
		c + Vector2(-s * 0.06, s * 0.24),
		c + Vector2(s * 0.32, -s * 0.26),
	])
	draw_polyline(points, color, lw, true)


func _draw_close(c: Vector2, s: float, lw: float) -> void:
	var half := s * 0.3
	draw_line(c + Vector2(-half, -half), c + Vector2(half, half), color, lw, true)
	draw_line(c + Vector2(-half, half), c + Vector2(half, -half), color, lw, true)


func _draw_diamond(c: Vector2, s: float) -> void:
	var half := s * 0.32
	var points := PackedVector2Array([
		c + Vector2(0, -half),
		c + Vector2(half, 0),
		c + Vector2(0, half),
		c + Vector2(-half, 0),
	])
	draw_colored_polygon(points, color)


func _draw_sword(c: Vector2, s: float, lw: float) -> void:
	_draw_single_sword(c, s, lw, false)
	_draw_single_sword(c, s, lw, true)


func _draw_single_sword(c: Vector2, s: float, lw: float, mirrored: bool) -> void:
	var dir := Vector2(1, -1) if not mirrored else Vector2(-1, -1)
	var tip := c + dir * s * 0.4
	var hilt := c - dir * s * 0.4
	draw_line(hilt, tip, color, lw, true)
	var guard_dir := Vector2(dir.y, -dir.x).normalized() * s * 0.1
	var guard_center := hilt + dir * s * 0.12
	draw_line(guard_center - guard_dir, guard_center + guard_dir, color, lw * 0.8, true)


func _draw_house(c: Vector2, s: float, lw: float) -> void:
	var half_w := s * 0.34
	var base_top := c.y + s * 0.02
	var base_bottom := c.y + s * 0.34
	var roof_tip := Vector2(c.x, c.y - s * 0.36)

	var roof := PackedVector2Array([
		roof_tip,
		Vector2(c.x + half_w * 1.15, base_top),
		Vector2(c.x - half_w * 1.15, base_top),
	])
	draw_colored_polygon(roof, color)

	var base := Rect2(c.x - half_w, base_top, half_w * 2, base_bottom - base_top)
	draw_rect(base, color, true)

	var door_w := s * 0.14
	var door := Rect2(c.x - door_w * 0.5, base_bottom - s * 0.18, door_w, s * 0.18)
	draw_rect(door, Color(0.05, 0.055, 0.08, 1.0) if color.v > 0.4 else Color(0.9, 0.9, 0.9, 1.0), true)


## Silhouette a 3 pointes, posee sur une base - cf. le blason des modales
## Victoire/Defaite/Chateau dans les captures Figma.
func _draw_crown(c: Vector2, s: float, lw: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(-0.32 * s, 0.12 * s),
		c + Vector2(-0.32 * s, -0.28 * s),
		c + Vector2(-0.11 * s, 0.0),
		c + Vector2(0.0, -0.36 * s),
		c + Vector2(0.11 * s, 0.0),
		c + Vector2(0.32 * s, -0.28 * s),
		c + Vector2(0.32 * s, 0.12 * s),
	])
	draw_polyline(points, color, lw, true)
	draw_line(c + Vector2(-0.36 * s, 0.12 * s), c + Vector2(0.36 * s, 0.12 * s), color, lw, true)


## Meme diademe que _draw_crown, mais la pointe centrale est cassee et tombee -
## cf. le blason de la modale Defaite dans la maquette Figma.
func _draw_crown_broken(c: Vector2, s: float, lw: float) -> void:
	var left := PackedVector2Array([
		c + Vector2(-0.32 * s, 0.12 * s),
		c + Vector2(-0.32 * s, -0.28 * s),
		c + Vector2(-0.11 * s, 0.0),
		c + Vector2(-0.02 * s, -0.2 * s),
	])
	draw_polyline(left, color, lw, true)

	var right := PackedVector2Array([
		c + Vector2(0.32 * s, 0.12 * s),
		c + Vector2(0.32 * s, -0.28 * s),
		c + Vector2(0.11 * s, 0.0),
		c + Vector2(0.04 * s, -0.12 * s),
	])
	draw_polyline(right, color, lw, true)

	draw_line(c + Vector2(-0.36 * s, 0.12 * s), c + Vector2(0.36 * s, 0.12 * s), color, lw, true)

	# La pointe centrale, detachee et tombee sous le diademe.
	var broken_tip := PackedVector2Array([
		c + Vector2(0.07 * s, 0.26 * s),
		c + Vector2(-0.03 * s, 0.14 * s),
		c + Vector2(0.15 * s, 0.18 * s),
	])
	draw_polyline(broken_tip, color, lw * 0.85, true)


## Rose des vents simplifiee : cercle + aiguille losange - cf. Compass-Icon
## du bouton "Carte de campagne" dans les captures Figma.
func _draw_compass(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c, s * 0.4, 0.0, TAU, 24, color, lw, true)
	var needle := PackedVector2Array([
		c + Vector2(0, -s * 0.32),
		c + Vector2(s * 0.1, 0),
		c + Vector2(0, s * 0.32),
		c + Vector2(-s * 0.1, 0),
	])
	draw_colored_polygon(needle, color)
	draw_circle(c, s * 0.05, Color(0, 0, 0, 0.35))


## Deux pieces empilees - cf. les montants "+X Or" dans les captures Figma.
func _draw_coin(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c + Vector2(-0.12 * s, 0.08 * s), 0.22 * s, 0, TAU, 20, color, lw, true)
	draw_arc(c + Vector2(0.12 * s, -0.08 * s), 0.22 * s, 0, TAU, 20, color, lw, true)


## Deux barres verticales - bouton Pause du controle de combat (ecran 05).
func _draw_pause(c: Vector2, s: float) -> void:
	var bar_w := s * 0.2
	var bar_h := s * 0.62
	var gap := s * 0.14
	draw_rect(Rect2(c.x - gap - bar_w, c.y - bar_h * 0.5, bar_w, bar_h), color, true)
	draw_rect(Rect2(c.x + gap, c.y - bar_h * 0.5, bar_w, bar_h), color, true)


## Chevron + hampe - bouton retour de l'ecran Preparation (ecran 03).
func _draw_arrow_left(c: Vector2, s: float, lw: float) -> void:
	var half := s * 0.28
	draw_line(c + Vector2(-half, 0), c + Vector2(half, 0), color, lw, true)
	draw_line(c + Vector2(-half, 0), c + Vector2(-half * 0.15, -half * 0.85), color, lw, true)
	draw_line(c + Vector2(-half, 0), c + Vector2(-half * 0.15, half * 0.85), color, lw, true)


## Cadran + aiguilles - chrono de blocage de l'ecran de combat (battle.gd).
func _draw_clock(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c, s * 0.4, 0.0, TAU, 24, color, lw, true)
	draw_line(c, c + Vector2(0, -s * 0.26), color, lw, true)
	draw_line(c, c + Vector2(s * 0.2, s * 0.08), color, lw, true)


## Cercle + point + barre - le "i" des ecrans d'aide. Trace a la main plutot
## qu'ecrit avec une police : la lettre i d'Inter en 12px, centree dans un
## cercle, ne tombe jamais juste sur l'axe optique.
func _draw_info(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c, s * 0.42, 0.0, TAU, 28, color, lw, true)
	draw_circle(c + Vector2(0, -s * 0.19), maxf(1.0, lw * 0.62), color)
	draw_line(c + Vector2(0, -s * 0.03), c + Vector2(0, s * 0.21), color, lw, true)


## Triangle + barre - bouton "Fin tour" du controle de combat (ecran 05).
func _draw_skip(c: Vector2, s: float) -> void:
	var half := s * 0.32
	var tri := PackedVector2Array([
		c + Vector2(-half, -half),
		c + Vector2(-half, half),
		c + Vector2(half * 0.4, 0),
	])
	draw_colored_polygon(tri, color)
	var bar_w := s * 0.14
	draw_rect(Rect2(c.x + half * 0.55, c.y - half, bar_w, half * 2.0), color, true)
