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
		var color := Color(0, 0, 0, max_alpha * (1.0 - t))

		# Bandes JOINTIVES, calees sur des pixels entiers. Elles se
		# chevauchaient d'un pixel pour eviter les coutures : ce pixel commun
		# recevait alors deux fois le noir et dessinait une raie sombre tous
		# les trois points - tres visible sur un fond clair comme la carte de
		# campagne. Prendre le bord suivant plutot qu'ajouter une largeur
		# supprime le chevauchement sans rouvrir de couture.
		var from := roundf(t * fade_size)
		var to := roundf(t * fade_size + band)
		var thickness := maxf(1.0, to - from)

		draw_rect(Rect2(0, from, size.x, thickness), color)
		draw_rect(Rect2(0, size.y - to, size.x, thickness), color)
		draw_rect(Rect2(from, 0, thickness, size.y), color)
		draw_rect(Rect2(size.x - to, 0, thickness, size.y), color)
