extends Control
##
## L'ECRAN D'UN BATIMENT - le decor du lieu, puis son panneau.
##
## ⚠️ CE N'ETAIT PAS UN POPUP, ET C'EST LE JOUEUR QUI L'A DIT : "zoom, fade in,
## fade out, ce n'est pas vraiment une pop up, c'est une transition vers un
## nouvel ecran". Les quatre casernes s'ouvraient en modale par-dessus le
## village, toutes sur le meme decor. La maquette (Figma 517:2) en fait douze
## ECRANS - quatre batiments fois trois etats - et chacun a SON PROPRE FOND.
##
## ⚠️ LE CONTENU N'A PAS ETE REECRIT. building_popup.gd tient deja les quatre
## etats, lit ses chiffres dans Balance et GameState, et gere le recrutement
## comme l'amelioration. Le reprendre a zero aurait recree des regles
## concurrentes pour un gain nul. Il est instancie tel quel : cet ecran ne lui
## ajoute qu'un DECOR et une SORTIE.
##
## La structure suit la maquette a l'identique :
##
##   Background-Map   le lieu, en fond couvrant
##   Dark-Overlay     -> c'est le `Dim` de la Modal, qui existait deja
##   Building-Modal   -> le panneau de building_popup, inchange
##

## Un fond par batiment. La Dame n'a pas de caserne - elle vit au Chateau
## Royal, qui a son propre ecran - donc elle n'est pas ici.
const BACKGROUNDS := {
	Balance.PION: "res://assets/buildings/pion_bg.jpg",
	Balance.CAVALIER: "res://assets/buildings/cavalier_bg.jpg",
	Balance.FOU: "res://assets/buildings/fou_bg.jpg",
	Balance.TOUR: "res://assets/buildings/tour_bg.jpg",
}

@onready var _background: TextureRect = $Background
@onready var _popup: Control = $Popup


func _ready() -> void:
	var type := Router.current_building
	_paint_background(type)

	# La fermeture du panneau ramene au village. `goto_village` et NON
	# `leave_battle_for_village` : ouvrir une caserne puis la refermer n'est pas
	# quitter une serie, c'est naviguer dans le village.
	_popup.tree_exited.connect(func():
		if is_inside_tree():
			Router.goto_village())
	_popup.open(type)


func _paint_background(type: String) -> void:
	var path: String = BACKGROUNDS.get(type, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	_background.texture = load(path)
