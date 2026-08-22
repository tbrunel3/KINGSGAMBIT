class_name EdgeFades
extends Control
##
## FONDUS DE BORD - gradients noir->transparent sur les 4 bords de l'ecran.
##
## Cf. CLAUDE.md : "Tous les fondus (edge fades) sont des gradients lineaires
## noir->transparent sur les 4 bords de l'ecran", utilise sur les ecrans a
## fond illustre (Village, Placement, Combat, carte de campagne) pour que le
## texte reste lisible sans assombrir tout le centre de l'image.
##
## ⚠️ NE PAS REVENIR A UN EMPILEMENT DE BANDES.
##
## La premiere version approximait le degrade par 24 rectangles de plus en plus
## clairs. Elle a coute deux bugs :
##
##   1. des COUTURES : une bande qui chevauchait la suivante d'un pixel
##      recevait deux fois le noir et dessinait une raie sombre - corrige en
##      calant les bandes bord a bord ;
##   2. des RAIES, revenues sur telephone. Bord a bord ou non, la position de
##      chaque bande est arrondie au point pres AVANT que l'etirement
##      "canvas_items" ne la multiplie par le facteur de l'appareil. Sur un
##      ecran dont le format n'est pas celui de reference, ce facteur n'est pas
##      entier : les arrondis tombent entre deux pixels et le degrade se remet
##      a rayer. C'est le defaut que le joueur voyait sur son telephone, et
##      qu'aucun banc ne montrait - les cinq definitions testees avaient toutes
##      le meme format.
##
## Un degrade de TEXTURE n'a pas ce probleme : le GPU l'interpole en continu,
## a n'importe quelle echelle et sur n'importe quel format. Les textures font
## 1 x 64 points, elles ne coutent rien.
##

@export var fade_size: float = 70.0:
	set(value):
		fade_size = value
		queue_redraw()

@export var max_alpha: float = 0.28:
	set(value):
		max_alpha = value
		_textures.clear()
		queue_redraw()

## La part de l'ecran qu'un fondu peut manger, par bord.
##
## `fade_size` est une valeur en POINTS, calee sur un ecran de 852 de haut. Sur
## un ecran court - un navigateur de telephone, ou la barre d'URL prend sa part
## - deux fondus de 70 points mangeaient 23 % de la hauteur au lieu de 16 %, et
## l'image se retrouvait cernee de noir. Le fondu se resserre donc avec l'ecran
## plutot que de garder sa taille absolue.
const MAX_SHARE := 0.09

var _textures: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect_size := get_rect().size
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return

	var vertical := minf(fade_size, rect_size.y * MAX_SHARE)
	var horizontal := minf(fade_size, rect_size.x * MAX_SHARE)

	draw_texture_rect(_fade(Vector2(0.5, 0.0), Vector2(0.5, 1.0)),
		Rect2(0.0, 0.0, rect_size.x, vertical), false)
	draw_texture_rect(_fade(Vector2(0.5, 1.0), Vector2(0.5, 0.0)),
		Rect2(0.0, rect_size.y - vertical, rect_size.x, vertical), false)
	draw_texture_rect(_fade(Vector2(0.0, 0.5), Vector2(1.0, 0.5)),
		Rect2(0.0, 0.0, horizontal, rect_size.y), false)
	draw_texture_rect(_fade(Vector2(1.0, 0.5), Vector2(0.0, 0.5)),
		Rect2(rect_size.x - horizontal, 0.0, horizontal, rect_size.y), false)


## Un degrade noir -> transparent, du bord `from` vers le bord `to`.
## Mis en cache : les quatre textures ne changent qu'avec `max_alpha`.
func _fade(from: Vector2, to: Vector2) -> GradientTexture2D:
	var key := "%s->%s" % [from, to]
	if _textures.has(key):
		return _textures[key]

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, max_alpha))
	gradient.set_color(1, Color(0, 0, 0, 0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	# 64 points dans le sens du degrade suffisent : l'interpolation du GPU fait
	# le reste, quelle que soit la taille a l'ecran.
	texture.width = 64
	texture.height = 64
	_textures[key] = texture
	return texture
