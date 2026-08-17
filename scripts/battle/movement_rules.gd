class_name MovementRules
##
## REGLES DE DEPLACEMENT - une fonction pure par type de piece.
##
## Les pieces rappellent les echecs sans en respecter les regles : la portee est
## limitee et croit avec le niveau (valeurs dans Balance.UNITS[...].levels).
##
##   Tour      lignes et colonnes, bloquee par les unites
##   Fou       diagonales, bloque par les unites
##   Pion      avance tout droit, plus un pas lateral, faible mobilite
##   Cavalier  saut en L, ignore les unites sur le trajet
##
## Aucune de ces fonctions ne modifie quoi que ce soit : elles retournent des
## listes de cases. C'est ce qui rend l'IA facile a tester et a debugger.
##

const ORTHOGONAL_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Toutes les cases ou l'unite peut se rendre ce tour-ci.
static func reachable_cells(unit: BattleUnit, grid: GridModel) -> Array:
	match unit.move_type:
		"orthogonal":
			return _slide(unit, grid, ORTHOGONAL_DIRS)
		"diagonal":
			return _slide(unit, grid, DIAGONAL_DIRS)
		"jump":
			return _jump(unit, grid)
		_:
			return _forward(unit, grid)


## Deplacement glissant : on avance case par case et on s'arrete au premier
## obstacle. Utilise par la Tour et le Fou.
static func _slide(unit: BattleUnit, grid: GridModel, directions: Array) -> Array:
	var cells: Array = []
	for dir in directions:
		for distance in range(1, unit.move_range + 1):
			var cell: Vector2i = unit.cell + dir * distance
			if not grid.is_free(cell):
				break
			cells.append(cell)
	return cells


## Pion : avance tout droit dans son sens de progression, et peut faire un pas
## de cote ou un pas en arriere pour se degager. Volontairement peu mobile.
##
## Le pas en arriere n'est pas cosmetique : sans lui, un pion ayant depasse
## l'ennemi ne peut plus jamais l'atteindre et le combat s'enlise.
static func _forward(unit: BattleUnit, grid: GridModel) -> Array:
	var cells: Array = []
	var ahead := Vector2i(0, unit.forward())
	for distance in range(1, unit.move_range + 1):
		var cell: Vector2i = unit.cell + ahead * distance
		if not grid.is_free(cell):
			break
		cells.append(cell)

	for step in [Vector2i(1, 0), Vector2i(-1, 0), -ahead]:
		var cell: Vector2i = unit.cell + step
		if grid.is_free(cell):
			cells.append(cell)

	return cells


## Cavalier : sauts en L. Les cases intermediaires sont ignorees, seule la case
## d'arrivee doit etre libre. Les paires (dx, dy) viennent de Balance et
## s'etendent avec le niveau.
static func _jump(unit: BattleUnit, grid: GridModel) -> Array:
	var cells: Array = []
	for offset in unit.jump_offsets:
		var a := int(offset[0])
		var b := int(offset[1])
		for pair in [[a, b], [b, a]]:
			for sx in [1, -1]:
				for sy in [1, -1]:
					var cell: Vector2i = unit.cell + Vector2i(pair[0] * sx, pair[1] * sy)
					if grid.is_free(cell) and not cells.has(cell):
						cells.append(cell)
	return cells


# ------------------------------- ATTAQUE -------------------------------------
#
#  Portee mesuree en distance de Tchebychev, sans ligne de vue. Simplification
#  assumee du MVP : une seule regle a retenir pour toutes les pieces.

static func can_attack_from(cell: Vector2i, unit: BattleUnit, target: BattleUnit) -> bool:
	if not target.is_alive() or not unit.is_enemy_of(target):
		return false
	return _chebyshev(cell, target.cell) <= unit.attack_range


static func can_attack(unit: BattleUnit, target: BattleUnit) -> bool:
	return can_attack_from(unit.cell, unit, target)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
