class_name EdgeFades
extends Control
##
## FONDUS DE BORD - gradients noir->transparent sur les 4 bords de l'ecran.
##
## Cf. CLAUDE.md : "Tous les fondus (edge fades) sont des gradients lineaires
## noir->transparent sur les 4 bords de l'ecran", utilise sur les ecrans a
## fond illustre (Village, Placement, Combat) pour que le texte reste lisible
## sans assombrir tout le centre de l'image.
##
## Approxime le gradient par des bandes superposees plutot que par une
## texture externe : aucun asset a fournir, resultat identique sur toutes
## les plateformes (y compris le Web).
##

@export var fade_size: float = 70.0
@export var max_alpha: float = 0.28
@export var steps: int = 24

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var size := get_rect().size
	var band := fade_size / float(steps)
	for i in range(steps):
		var t := float(i) / float(steps)
		var alpha := max_alpha * (1.0 - t)
		var color := Color(0, 0, 0, alpha)
		draw_rect(Rect2(0, t * fade_size, size.x, band + 1), color)
		draw_rect(Rect2(0, size.y - t * fade_size - band, size.x, band + 1), color)
		draw_rect(Rect2(t * fade_size, 0, band + 1, size.y), color)
		draw_rect(Rect2(size.x - t * fade_size - band, 0, band + 1, size.y), color)
