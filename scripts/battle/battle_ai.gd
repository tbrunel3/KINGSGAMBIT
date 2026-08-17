class_name BattleAI
##
## IA - decide ce que fait une unite quand c'est son tour.
##
## Les deux camps utilisent la meme IA : le combat est automatique des qu'il
## commence, le joueur ne joue que le placement.
##
## Ordre de priorite (volontairement simple et previsible) :
##   1. une cible est deja a portee     -> attaquer sans bouger
##   2. une cible devient atteignable   -> se deplacer puis attaquer
##   3. sinon                           -> se rapprocher de l'ennemi le plus proche
##   4. aucun gain                      -> ne pas bouger
##
## A cibles egales, l'IA vise l'unite la plus faible en points de vie, puis la
## plus proche. Pour rendre l'IA plus maligne en Phase 2, il suffit de modifier
## _score_target et _score_cell : le reste du moteur n'a pas a changer.
##

## Retourne {"move": Vector2i, "target": BattleUnit|null}.
## "move" vaut la case actuelle si l'unite reste sur place.
static func decide(unit: BattleUnit, grid: GridModel, units: Array) -> Dictionary:
	var enemies := _living_enemies(unit, units)
	if enemies.is_empty():
		return {"move": unit.cell, "target": null}

	# 1. Cible deja a portee : on frappe sans bouger.
	var direct := _best_target_from(unit.cell, unit, enemies)
	if direct != null:
		return {"move": unit.cell, "target": direct}

	var reachable := MovementRules.reachable_cells(unit, grid)

	# 2. Une case permet-elle d'attaquer ce tour-ci ?
	var best_cell := unit.cell
	var best_target: BattleUnit = null
	var best_score := INF
	for cell in reachable:
		var target := _best_target_from(cell, unit, enemies)
		if target == null:
			continue
		var score := _score_target(target) + 0.01 * _distance(unit.cell, cell)
		if score < best_score:
			best_score = score
			best_cell = cell
			best_target = target

	if best_target != null:
		return {"move": best_cell, "target": best_target}

	# 3. Aucune attaque possible : on se rapproche.
	var current_distance := _distance_to_nearest(unit.cell, enemies)
	var move_cell := unit.cell
	var move_score := float(current_distance)
	for cell in reachable:
		var score := float(_distance_to_nearest(cell, enemies))
		if score < move_score:
			move_score = score
			move_cell = cell

	# 4. Si aucune case ne rapproche vraiment, l'unite tient sa position.
	return {"move": move_cell, "target": null}


# ------------------------------- HEURISTIQUES --------------------------------

## Plus le score est bas, plus la cible est interessante.
## Ici : achever les unites entamees, a distance egale.
static func _score_target(target: BattleUnit) -> float:
	return float(target.hp)


static func _best_target_from(cell: Vector2i, unit: BattleUnit, enemies: Array) -> BattleUnit:
	var best: BattleUnit = null
	var best_score := INF
	for enemy in enemies:
		if not MovementRules.can_attack_from(cell, unit, enemy):
			continue
		var score := _score_target(enemy) + 0.01 * _distance(cell, enemy.cell)
		if score < best_score:
			best_score = score
			best = enemy
	return best


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
