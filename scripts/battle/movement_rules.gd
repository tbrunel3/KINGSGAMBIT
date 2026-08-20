class_name MovementRules
##
## REGLES DE DEPLACEMENT - une fonction pure par type de piece.
##
## Les pieces rappellent les echecs sans en respecter les regles : la portee est
## limitee et croit fortement avec le niveau (valeurs dans Balance).
##
##   Tour      lignes et colonnes, bloquee par les pieces
##   Fou       diagonales, bloque par les pieces
##   Cavalier  saut, ignore les pieces sur le trajet
##   Dame      lignes, colonnes et diagonales (obtenue par promotion d'un pion)
##   Pion      avance tout droit sur des cases VIDES, capture en diagonale avant,
##             et dispose d'une OUVERTURE plus longue a son premier coup
##
## CAPTURE : il n'y a pas d'attaque separee ni de portee de tir. Une piece
## capture en se DEPLACANT sur la case occupee par un adversaire. Une case
## occupee par un allie est infranchissable ; une case occupee par un ennemi
## est un point d'arrivee possible, mais on ne va pas au-dela.
##
## Aucune de ces fonctions ne modifie quoi que ce soit : elles retournent des
## listes de cases. C'est ce qui rend l'IA facile a tester et a debugger.
##

const ORTHOGONAL_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONAL_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ALL_DIRS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## Toutes les cases ou la piece peut se rendre ce tour-ci, capture comprise.
static func legal_moves(unit: BattleUnit, grid: GridModel) -> Array:
	match unit.move_type:
		"orthogonal":
			return _slide(unit, grid, ORTHOGONAL_DIRS)
		"diagonal":
			return _slide(unit, grid, DIAGONAL_DIRS)
		"queen":
			return _slide(unit, grid, ALL_DIRS)
		"jump":
			return _jump(unit, grid)
		_:
			return _pawn(unit, grid)


## Les cases de `legal_moves` qui capturent effectivement une piece adverse.
static func capture_moves(unit: BattleUnit, grid: GridModel) -> Array:
	var captures: Array = []
	for cell in legal_moves(unit, grid):
		var occupant := grid.unit_at(cell)
		if occupant != null and unit.is_enemy_of(occupant):
			captures.append(cell)
	return captures


## Deplacement glissant : on avance case par case, on s'arrete devant un allie,
## et on s'arrete EN PRENANT le premier ennemi rencontre. Tour, Fou, Dame.
static func _slide(unit: BattleUnit, grid: GridModel, directions: Array) -> Array:
	var cells: Array = []
	for dir in directions:
		for distance in range(1, unit.move_range + 1):
			var cell: Vector2i = unit.cell + dir * distance
			if not grid.in_bounds(cell):
				break
			var occupant := grid.unit_at(cell)
			if occupant == null:
				cells.append(cell)
				continue
			if unit.is_enemy_of(occupant):
				cells.append(cell)  # capture possible
			break                   # allie ou ennemi : on ne va pas plus loin
	return cells


## Pion : avance tout droit sur des cases vides, prend uniquement sur ses deux
## diagonales avant, a une case. Comme aux echecs.
##
## OUVERTURE : a son tout premier coup, il peut avancer plus loin (deux cases
## des que sa caserne est de niveau 2, cf. Balance.first_move_range) - le
## double pas classique. Il ne saute personne pour autant : la premiere case
## occupee arrete la poussee. Ensuite, il reprend son pas ordinaire.
##
## Il ne recule pas : s'il atteint le fond adverse, il promeut en Dame, ce qui
## evite qu'un pion se retrouve coince a jamais derriere les lignes.
static func _pawn(unit: BattleUnit, grid: GridModel) -> Array:
	var cells: Array = []
	var ahead := Vector2i(0, unit.forward())
	var reach := unit.move_range if unit.has_moved else maxi(unit.move_range, unit.first_move_range)

	for distance in range(1, reach + 1):
		var cell: Vector2i = unit.cell + ahead * distance
		if not grid.in_bounds(cell) or grid.unit_at(cell) != null:
			break
		cells.append(cell)

	for side in [1, -1]:
		var cell: Vector2i = unit.cell + Vector2i(side, unit.forward())
		if not grid.in_bounds(cell):
			continue
		var occupant := grid.unit_at(cell)
		if occupant != null and unit.is_enemy_of(occupant):
			cells.append(cell)

	return cells


## Cavalier : sauts. Les cases intermediaires sont ignorees, seule la case
## d'arrivee compte. Les figures (dx, dy) viennent de Balance et s'enrichissent
## avec le niveau.
static func _jump(unit: BattleUnit, grid: GridModel) -> Array:
	var cells: Array = []
	for offset in unit.jump_offsets:
		var a := int(offset[0])
		var b := int(offset[1])
		for pair in [[a, b], [b, a]]:
			for sx in [1, -1]:
				for sy in [1, -1]:
					var cell: Vector2i = unit.cell + Vector2i(pair[0] * sx, pair[1] * sy)
					if not grid.in_bounds(cell) or cells.has(cell):
						continue
					var occupant := grid.unit_at(cell)
					if occupant == null or unit.is_enemy_of(occupant):
						cells.append(cell)
	return cells


# ------------------------------- MENACES -------------------------------------
#
#  Sert a l'IA : une case est menacee si une piece adverse pourrait s'y rendre
#  au prochain tour, donc y capturer ce qui s'y trouve.

static func is_cell_threatened(cell: Vector2i, by_team: int, grid: GridModel, units: Array) -> bool:
	for other in units:
		if not other.is_alive() or other.team != by_team:
			continue
		if legal_moves(other, grid).has(cell):
			return true
	return false
