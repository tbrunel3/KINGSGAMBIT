class_name GridModel
extends RefCounted
##
## GRILLE - occupation du champ de bataille, sans aucun affichage.
##
## La taille vient de la bataille jouee (Balance.CAMPAIGN), pas d'une constante :
## rien ici ne suppose un echiquier 8x8.
##

var cols: int = 6
var rows: int = 8

var _occupant: Dictionary = {}  # Vector2i -> BattleUnit


func _init(grid_cols: int, grid_rows: int) -> void:
	cols = grid_cols
	rows = grid_rows


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows


func unit_at(cell: Vector2i) -> BattleUnit:
	return _occupant.get(cell, null)


func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _occupant.has(cell)


func place(unit: BattleUnit, cell: Vector2i) -> void:
	_occupant[cell] = unit
	unit.cell = cell

func remove_unit(unit: BattleUnit) -> void:
	if _occupant.get(unit.cell, null) == unit:
		_occupant.erase(unit.cell)


func move_unit(unit: BattleUnit, to: Vector2i) -> void:
	remove_unit(unit)
	place(unit, to)


# ------------------------------- ZONES DE DEPLOIEMENT ------------------------
#
#  Le joueur se deploie sur les dernieres rangees (en bas), l'ennemi sur les
#  premieres (en haut). Le nombre de rangees vient de Balance.DEPLOY_ROWS.

func player_zone_first_row() -> int:
	return rows - Balance.DEPLOY_ROWS


func is_player_zone(cell: Vector2i) -> bool:
	return in_bounds(cell) and cell.y >= player_zone_first_row()

## Cases libres de la zone ennemie, rangee du fond d'abord, du centre vers les
## bords : une armee massee au centre se defend mieux qu'une ligne etalee.
func free_enemy_cells() -> Array:
	var cells: Array = []
	for y in range(Balance.DEPLOY_ROWS):
		for cell in _row_from_center(y):
			if is_free(cell):
				cells.append(cell)
	return cells


## Meme logique, en miroir, pour le camp du joueur : la rangee la plus proche
## de l'ennemi vient en premier, du centre vers les bords. C'est ce qu'utilise
## le bouton Auto, pour que les deux camps partent a armes egales.
func free_player_cells() -> Array:
	var cells: Array = []
	for y in range(player_zone_first_row(), rows):
		for cell in _row_from_center(y):
			if is_free(cell):
				cells.append(cell)
	return cells


func _row_from_center(y: int) -> Array:
	var middle := cols / 2.0 - 0.5
	var row: Array = []
	for x in range(cols):
		row.append(Vector2i(x, y))
	row.sort_custom(func(a, b): return absf(a.x - middle) < absf(b.x - middle))
	return row
