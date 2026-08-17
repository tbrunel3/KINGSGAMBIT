class_name BattleUnit
extends RefCounted
##
## UNITE EN COMBAT - etat d'une piece pendant une bataille.
##
## Objet pur : aucun noeud, aucun affichage. La vue lit ces valeurs pour
## dessiner, jamais l'inverse.
##
## Convention de plateau : la rangee 0 est en HAUT (cote ennemi), la derniere
## rangee est en BAS (cote joueur). Le joueur avance donc vers les rangees
## decroissantes, l'ennemi vers les rangees croissantes.
##

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var id: int = 0
var type: String = ""
var level: int = 1
var team: int = TEAM_PLAYER
var cell: Vector2i = Vector2i.ZERO

var max_hp: int = 1
var hp: int = 1
var damage: int = 0
var attack_range: int = 1
var move_range: int = 1
var move_type: String = "forward"
var jump_offsets: Array = []


static func create(unit_id: int, unit_type: String, unit_level: int, unit_team: int, start_cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = unit_id
	unit.type = unit_type
	unit.level = unit_level
	unit.team = unit_team
	unit.cell = start_cell

	var stats := Balance.unit_stats(unit_type, unit_level)
	unit.max_hp = int(stats["hp"])
	unit.hp = unit.max_hp
	unit.damage = int(stats["damage"])
	unit.attack_range = int(stats["attack_range"])
	unit.move_range = int(stats.get("move_range", 1))
	unit.move_type = String(Balance.UNITS[unit_type]["move_type"])
	unit.jump_offsets = stats.get("jump_offsets", [])
	return unit


func is_alive() -> bool:
	return hp > 0


## Sens de progression de l'unite : -1 vers le haut (joueur), +1 vers le bas.
func forward() -> int:
	return -1 if team == TEAM_PLAYER else 1


func is_enemy_of(other: BattleUnit) -> bool:
	return team != other.team


## Applique des degats et retourne true si l'unite meurt sur ce coup.
func take_damage(amount: int) -> bool:
	hp = maxi(0, hp - amount)
	return hp == 0


func display_name() -> String:
	return "%s Nv.%d" % [Balance.unit_name(type), level]
