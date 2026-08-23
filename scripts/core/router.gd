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

## Bataille en cours de preparation ou de combat.
var current_battle_id: int = 1


func goto_intro() -> void:
	_change(INTRO_SCENE)


func goto_village() -> void:
	_change(VILLAGE_SCENE)


## Salle du trone, en plein ecran : le chateau est le batiment central du
## village, il ne tient pas dans une modale.
func goto_castle() -> void:
	_change(CASTLE_SCENE)


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
## l'appeler depuis un signal de bouton reste sans danger.
func _change(path: String, veil_color: Color = ScreenVeil.BLACK) -> void:
	ScreenVeil.go(func(): get_tree().change_scene_to_file(path), veil_color)
