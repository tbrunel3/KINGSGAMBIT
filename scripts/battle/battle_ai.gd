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

	# 1. Les prises d'abord, evaluees comme un echange : ce que je gagne moins
	#    ce que je risque de perdre si la case est reprise juste apres.
	var best_cell := Vector2i(-1, -1)
	var best_trade := -INF
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

	# Un echange nul est accepte, un echange perdant non : une tour ne prend pas
	# un pion pour se faire reprendre au coup suivant.
	if best_cell != Vector2i(-1, -1) and best_trade >= 0.0:
		return {"move": best_cell, "capture": grid.unit_at(best_cell)}

	# 2. Aucune prise interessante : on avance. On prefere une case sure, mais on
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
		if wants_promotion:
			score += (absi(unit.cell.y - promotion_row) - absi(cell.y - promotion_row)) * 3
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
	if any_cell != Vector2i(-1, -1):
		return {"move": any_cell, "capture": null}

	# 3. Rien ne rapproche : la piece tient sa position.
	return {"move": unit.cell, "capture": null}


# ------------------------------- HEURISTIQUES --------------------------------

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
