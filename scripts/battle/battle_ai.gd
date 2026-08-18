class_name BattleAI
##
## IA - decide ce que fait une piece quand c'est son tour.
##
## Les deux camps utilisent la meme IA : le combat est automatique des qu'il
## commence, le joueur ne joue que le placement.
##
## Ordre de priorite (volontairement simple et previsible) :
##   1. capturer, en visant la piece la plus chere
##   2. a valeur egale, preferer une case ou l'on ne sera pas repris
##   3. sinon avancer vers l'ennemi le plus proche, sur une case sure si possible
##   4. si rien n'ameliore la position, ne pas bouger
##
## Pour rendre l'IA plus maligne en Phase 2, il suffit de retoucher _score_move :
## le reste du moteur n'a pas a changer.
##

## Valeur en dessous de laquelle une piece accepte d'avancer sur une case
## menacee. A 1, seuls les pions se sacrifient.
const _EXPENDABLE_VALUE := 1


## Retourne {"move": Vector2i, "capture": BattleUnit|null}.
## "move" vaut la case actuelle si la piece reste sur place.
static func decide(unit: BattleUnit, grid: GridModel, units: Array) -> Dictionary:
	var enemies := _living_enemies(unit, units)
	if enemies.is_empty():
		return {"move": unit.cell, "capture": null}

	var moves := MovementRules.legal_moves(unit, grid)
	if moves.is_empty():
		return {"move": unit.cell, "capture": null}

	var enemy_team := BattleUnit.TEAM_ENEMY if unit.team == BattleUnit.TEAM_PLAYER else BattleUnit.TEAM_PLAYER

	# Une piece deja attaquee sera prise si elle ne fait rien : ses calculs
	# changent completement, elle n'a plus rien a proteger.
	var in_danger := MovementRules.is_cell_threatened(unit.cell, enemy_team, grid, units)

	# 1. Les prises, evaluees comme un echange : ce que je gagne moins ce que je
	#    risque de perdre si la case est reprise juste apres.
	var best_cell := Vector2i(-1, -1)
	var best_trade := -INF
	var best_value := 0.0
	for cell in moves:
		var target := grid.unit_at(cell)
		if target == null or not unit.is_enemy_of(target):
			continue
		var trade := float(target.value)
		if _would_be_threatened(cell, unit, enemy_team, grid, units):
			trade -= float(unit.value)
		if trade > best_trade:
			best_trade = trade
			best_cell = cell
			best_value = float(target.value)

	if best_cell != Vector2i(-1, -1):
		# Un echange nul passe, un echange perdant non : une tour ne prend pas un
		# pion pour se faire reprendre au coup suivant.
		if best_trade >= 0.0:
			return {"move": best_cell, "capture": grid.unit_at(best_cell)}
		# SAUF si elle est deja en prise : elle est perdue de toute facon, autant
		# emporter quelque chose. Ne pas le faire, c'est mourir les mains vides.
		if in_danger and _best_escape(unit, grid, units, enemies, enemy_team) == Vector2i(-1, -1):
			return {"move": best_cell, "capture": grid.unit_at(best_cell)}

	# 2. En prise et capable de fuir : elle se degage.
	if in_danger:
		var escape := _best_escape(unit, grid, units, enemies, enemy_team)
		if escape != Vector2i(-1, -1):
			return {"move": escape, "capture": null}

	# 3. Aucune prise interessante : on avance. On prefere une case sure, mais on
	#    avance quand meme s'il n'y en a pas - rester plante signifie perdre la
	#    bataille a l'usure sans avoir combattu.
	#
	#    Un pion compte double : se rapprocher de l'ennemi, mais aussi du fond
	#    adverse, ou il devient Dame. Sans ce second critere, un pion cesse
	#    d'avancer des qu'il ne gagne plus de distance et ne promeut jamais.
	var current_distance := _distance_to_nearest(unit.cell, enemies)
	var wants_promotion: bool = unit.origin_type == Balance.PION and not unit.promoted
	var promotion_row := unit.promotion_row(grid.rows)

	var safe_cell := Vector2i(-1, -1)
	var safe_score := 0
	var any_cell := Vector2i(-1, -1)
	var any_score := 0

	for cell in moves:
		if grid.unit_at(cell) != null:
			continue
		var score := (current_distance - _distance_to_nearest(cell, enemies)) * 4
		var promotion_gain := 0
		if wants_promotion:
			promotion_gain = (absi(unit.cell.y - promotion_row) - absi(cell.y - promotion_row)) * 3
			score += promotion_gain
		# S'eloigner du seul ennemi restant ne doit jamais annuler une avance
		# vers la promotion : sinon un pion isole se fige des qu'il n'a plus
		# personne a chasser dans cette direction, et la partie s'enlise.
		if promotion_gain > 0:
			score = maxi(score, promotion_gain)
		if score <= 0:
			continue
		if score > any_score:
			any_score = score
			any_cell = cell
		if score > safe_score and not _would_be_threatened(cell, unit, enemy_team, grid, units):
			safe_score = score
			safe_cell = cell

	if safe_cell != Vector2i(-1, -1):
		return {"move": safe_cell, "capture": null}

	# 3. Aucune case sure. Seules les pieces de faible valeur avancent quand
	#    meme : c'est le role du pion d'ouvrir le contact et d'etre echange.
	#    Une tour qui s'offre a un pion perd la bataille a elle seule.
	if any_cell != Vector2i(-1, -1) and unit.value <= _EXPENDABLE_VALUE:
		return {"move": any_cell, "capture": null}

	# 4. Rien de sur, et la piece vaut trop cher pour se sacrifier : elle tient
	#    sa position. Si les deux camps s'immobilisent, le moteur tranche au
	#    materiel restant apres Balance.COMBAT.stalemate_rounds.
	return {"move": unit.cell, "capture": null}


# ------------------------------- HEURISTIQUES --------------------------------

## Case de repli pour une piece en prise : une case libre et sure, en preferant
## celle qui reste la plus proche de l'ennemi. Vector2i(-1, -1) si aucune ne
## met la piece a l'abri - elle vendra alors sa peau sur place.
static func _best_escape(unit: BattleUnit, grid: GridModel, units: Array, enemies: Array, enemy_team: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 9999
	for cell in MovementRules.legal_moves(unit, grid):
		if grid.unit_at(cell) != null:
			continue
		if _would_be_threatened(cell, unit, enemy_team, grid, units):
			continue
		var distance := _distance_to_nearest(cell, enemies)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

## Simule le deplacement pour savoir si la case d'arrivee est reprenable.
## On retire temporairement la piece de sa case d'origine : sans cela, elle se
## bloquerait elle-meme les lignes de vue et jugerait mal le danger.
static func _would_be_threatened(cell: Vector2i, unit: BattleUnit, enemy_team: int, grid: GridModel, units: Array) -> bool:
	var origin := unit.cell
	var victim := grid.unit_at(cell)

	grid.remove_unit(unit)
	if victim != null:
		grid.remove_unit(victim)
	grid.place(unit, cell)

	var threatened := MovementRules.is_cell_threatened(cell, enemy_team, grid, units)

	grid.remove_unit(unit)
	if victim != null:
		grid.place(victim, cell)
	grid.place(unit, origin)

	return threatened


static func _living_enemies(unit: BattleUnit, units: Array) -> Array:
	var enemies: Array = []
	for other in units:
		if other.is_alive() and unit.is_enemy_of(other):
			enemies.append(other)
	return enemies


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _distance_to_nearest(cell: Vector2i, enemies: Array) -> int:
	var best := 9999
	for enemy in enemies:
		best = mini(best, _distance(cell, enemy.cell))
	return best
