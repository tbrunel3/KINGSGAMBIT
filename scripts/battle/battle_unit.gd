class_name BattleUnit
extends RefCounted
##
## PIECE EN COMBAT - etat d'une piece pendant une bataille.
##
## Objet pur : aucun noeud, aucun affichage. La vue lit ces valeurs pour
## dessiner, jamais l'inverse.
##
## Une piece n'a pas de points de vie : elle est sur le plateau, ou capturee.
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

## Type d'origine, jamais modifie par la promotion. C'est lui qui compte pour
## l'armee du village : une Dame promue redevient le pion qu'elle etait.
var origin_type: String = ""
var team: int = TEAM_PLAYER
var cell: Vector2i = Vector2i.ZERO

var captured: bool = false
var promoted: bool = false  ## vrai pour un pion promu (cavalier, fou ou dame)

## Vrai des que la piece a joue un coup. Sert au double pas d'ouverture du
## pion (cf. MovementRules._pawn) : comme aux echecs, il ne s'offre qu'une
## fois, au tout premier deplacement de la piece.
var has_moved: bool = false

## Prises realisees par cette piece. Sert au sacre : seul un pion qui a fait
## ses preuves peut pretendre a la couronne (cf. Balance.PROMOTION_REQUIRES_CAPTURE).
var captures: int = 0

## Pion arrive au fond adverse et EN ATTENTE de couronnement. Il sera fait
## Dame au debut du prochain tour de son camp, s'il est encore debout
## (cf. BattleEngine, le sacre prend un tour).

var move_range: int = 1
## Portee du tout premier coup. Egale a move_range pour toutes les pieces
## sauf le pion, dont l'ouverture s'allonge avec le niveau de sa caserne.
var first_move_range: int = 1
var move_type: String = "forward"
var jump_offsets: Array = []
var value: int = 1


static func create(unit_id: int, unit_type: String, unit_level: int, unit_team: int, start_cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.id = unit_id
	unit.team = unit_team
	unit.cell = start_cell
	unit.level = unit_level
	unit.origin_type = unit_type
	unit._apply_type(unit_type)
	return unit


## Recopie les caracteristiques de deplacement d'un type. Sert a la creation et
## a la promotion : un pion qui devient Dame ne change que de type.
func _apply_type(new_type: String) -> void:
	type = new_type
	move_type = Balance.move_type(new_type)
	move_range = Balance.move_range(new_type, level)
	first_move_range = Balance.first_move_range(new_type, level)
	jump_offsets = Balance.jump_offsets(new_type, level)
	value = Balance.unit_value(new_type)


## Promotion : un pion arrive au fond adverse devient Dame, en gardant son
## niveau - une Dame issue d'un pion de bas niveau reste donc moins mobile
## qu'une Dame issue d'un pion de haut niveau.
func promote_to(new_type: String) -> void:
	_apply_type(new_type)
	promoted = true


## Defait une promotion. Reserve a la RECHERCHE de l'IA (cf. BattleSearch),
## qui joue puis reprend ses coups sur le vrai plateau plutot que d'en copier
## un a chaque noeud - une copie par noeud couterait bien plus cher que la
## recherche elle-meme. Rien dans le jeu ne deprome une piece.
func unpromote() -> void:
	_apply_type(origin_type)
	promoted = false


func is_alive() -> bool:
	return not captured


## Sens de progression de la piece : -1 vers le haut (joueur), +1 vers le bas.
func forward() -> int:
	return -1 if team == TEAM_PLAYER else 1


## Rangee de promotion : le fond du camp adverse.
func promotion_row(rows: int) -> int:
	return 0 if team == TEAM_PLAYER else rows - 1


func is_enemy_of(other: BattleUnit) -> bool:
	return team != other.team
