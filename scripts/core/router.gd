extends Node
##
## ROUTER - changements de scene et contexte transmis entre elles.
##
## Godot ne permet pas de passer des arguments a change_scene_to_file(), donc
## le contexte (quelle bataille ?) transite par ce singleton. C'est volontaire :
## un seul endroit a lire quand on se demande d'ou vient une valeur.
##

const SPLASH_SCENE := "res://scenes/intro/splash_screen.tscn"
const INTRO_SCENE := "res://scenes/intro/king_intro_dialogue.tscn"
const VILLAGE_SCENE := "res://scenes/village/village.tscn"
const CAMPAIGN_SCENE := "res://scenes/battle/campaign.tscn"
const PREP_SCENE := "res://scenes/battle/battle_prep.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const CASTLE_SCENE := "res://scenes/village/castle_screen.tscn"
const CODEX_SCENE := "res://scenes/village/codex_popup.tscn"
const SHOP_SCENE := "res://scenes/village/shop.tscn"
const BUILDING_SCENE := "res://scenes/village/building_screen.tscn"

## Bataille en cours de preparation ou de combat.
var current_battle_id: int = 1

## Batiment dont l'ecran s'ouvre. Meme raison que current_battle_id : Godot ne
## sait pas passer d'argument a un changement de scene.
var current_building: String = ""


func goto_intro() -> void:
	_change(INTRO_SCENE)


## Le village, sans rien demander.
##
## ⚠️ NE PAS Y REMETTRE LA GARDE D'ABANDON DE SERIE. Elle y a ete posee un
## moment, sur l'idee que c'etait "la porte unique vers le village" - et c'est
## vrai, mais c'est justement le probleme : le CHATEAU, le CODEX et la BOUTIQUE
## reviennent au village par ici. Fermer le codex en pleine serie aurait donc
## demande de l'abandonner.
##
## Naviguer DANS le village n'est pas quitter la serie. Seul le chemin qui sort
## du combat la quitte - voir leave_battle_for_village().
func goto_village() -> void:
	_change(VILLAGE_SCENE)


## Repartir au royaume DEPUIS le combat ou la carte : la serie est abandonnee.
##
## Regle demandee par le joueur. Elle ne bouche PAS l'exploit qu'il craignait -
## celui-la n'existe pas, `CampaignRun.roster` est un instantane pris a
## l'ouverture et les pieces achetees ensuite n'y entrent jamais. C'est une
## decision de jeu : une serie est un engagement, on ne la met pas en pause
## pour aller faire ses courses.
##
## L'avertissement n'est pas negociable : sans lui, le joueur perdrait deux
## combats gagnes en touchant un bouton qui, jusque-la, ne coutait rien.
var ask_before_leaving: bool = true


func leave_battle_for_village() -> void:
	var run := Game.current_run()
	if run == null:
		_change(VILLAGE_SCENE)
		return

	if not ask_before_leaving:
		# Les bancs : la regle s'applique, la question ne se pose pas. Une
		# modale y attendrait une reponse qui ne viendrait jamais.
		Game.abandon_run()
		_change(VILLAGE_SCENE)
		return

	# ⚠️ Charge a l'appel, pas par son class_name : nommer une classe
	# d'interface dans un autoload tire tout le graphe des ecrans au chargement
	# des autoloads, et le jeu ne demarre plus du tout. Piege deja paye.
	var Confirm := load("res://scenes/ui/confirm_leave.gd")
	Confirm.ask(get_tree().current_scene, run, func():
		Game.abandon_run()
		_change(VILLAGE_SCENE))


## Salle du trone, en plein ecran : le chateau est le batiment central du
## village, il ne tient pas dans une modale.
func goto_castle() -> void:
	_change(CASTLE_SCENE)


## L'ecran d'un batiment, en plein ecran et non en modale.
##
## Demande du joueur apres test : "ce n'est pas vraiment une pop up, c'est une
## transition vers un nouvel ecran". Chaque batiment a son propre decor, ce
## qu'une modale posee sur le village ne pouvait pas rendre.
func goto_building(type: String) -> void:
	current_building = type
	_change(BUILDING_SCENE)


## Codex du royaume. En plein ecran defilant et non en modale : il enumere
## les dix niveaux de cinq pieces, les batiments et les regles - une modale
## qui ne defile pas en montrerait le dixieme.
func goto_codex() -> void:
	_change(CODEX_SCENE)


## Boutique. En plein ecran defilant, comme le codex et pour la meme raison :
## la maquette fait 982 points de haut, aucune modale ne la contient.
func goto_shop() -> void:
	_change(SHOP_SCENE)


## La carte s'ouvre sur un fondu au BLANC, pas au noir.
##
## Demande du joueur, dans ses mots : "un dezoom et fondu au blanc comme une
## elevation, et ensuite ouverture sur la carte avec le fondu au blanc qui
## disparait". Le blanc dit qu'on s'eleve au-dessus du village pour regarder
## le royaume ; le noir dirait qu'on s'en va.
func goto_campaign() -> void:
	_change(CAMPAIGN_SCENE, ScreenVeil.WHITE)


func goto_prep(battle_id: int) -> void:
	current_battle_id = battle_id
	_change(PREP_SCENE)


func goto_battle(battle_id: int) -> void:
	current_battle_id = battle_id
	_change(BATTLE_SCENE)


func current_battle() -> Dictionary:
	return Balance.battle(current_battle_id)


## TOUT CHANGEMENT D'ECRAN PASSE PAR LE VOILE.
##
## C'est le seul endroit du jeu ou une scene est remplacee : y poser le voile
## corrige d'un coup le chateau, la carte, la boutique, le codex et la
## bataille, plutot que d'ajouter un fondu local a chacun.
##
## ScreenVeil est un autoload : il n'est pas detruit avec la scene sortante.
## C'est exactement ce qui manquait - village.gd voilait l'ecran puis appelait
## goto_castle(), et son voile mourait avec lui avant d'avoir pu se lever.
##
## L'attente du voile remplace aussi le call_deferred d'avant : on est de toute
## facon sorti du traitement d'input quand la scene est remplacee, donc
## l'appeler depuis un signal de bouton reste sans danger. En mode instantane
## - les bancs - c'est ScreenVeil qui differe l'appel a sa place.


## ⚠️ A POSER A `false` DANS LES BANCS. Un banc instancie ses ecrans comme
## ENFANTS DE LUI-MEME : change_scene_to_file() y remplacerait la scene du banc
## elle-meme, et le banc se detruirait en cours de route. Il enregistre alors
## la destination sans l'ouvrir, ce qui suffit a verifier qu'un bouton mene ou
## il doit. Meme doctrine que ScreenVeil.instant.
var navigation_enabled: bool = true

## Derniere destination demandee. Ce que lisent les bancs quand la navigation
## est coupee.
var last_scene_path: String = ""


func _change(path: String, veil_color: Color = ScreenVeil.BLACK) -> void:
	last_scene_path = path
	if not navigation_enabled:
		return
	ScreenVeil.go(func(): get_tree().change_scene_to_file(path), veil_color)
