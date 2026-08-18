extends Node
##
## ROUTER - changements de scene et contexte transmis entre elles.
##
## Godot ne permet pas de passer des arguments a change_scene_to_file(), donc
## le contexte (quelle bataille ?) transite par ce singleton. C'est volontaire :
## un seul endroit a lire quand on se demande d'ou vient une valeur.
##

const VILLAGE_SCENE := "res://scenes/village/village.tscn"
const CAMPAIGN_SCENE := "res://scenes/battle/campaign.tscn"
const PREP_SCENE := "res://scenes/battle/battle_prep.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

## Bataille en cours de preparation ou de combat.
var current_battle_id: int = 1


func goto_village() -> void:
	_change(VILLAGE_SCENE)


func goto_campaign() -> void:
	_change(CAMPAIGN_SCENE)


func goto_prep(battle_id: int) -> void:
	current_battle_id = battle_id
	_change(PREP_SCENE)


func goto_battle(battle_id: int) -> void:
	current_battle_id = battle_id
	_change(BATTLE_SCENE)


func current_battle() -> Dictionary:
	return Balance.battle(current_battle_id)


func _change(path: String) -> void:
	# Differe d'une frame : on peut ainsi appeler ces methodes depuis un signal
	# de bouton sans detruire la scene pendant qu'elle traite son input.
	get_tree().call_deferred("change_scene_to_file", path)
