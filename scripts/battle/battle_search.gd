class_name BattleSearch
##
## RECHERCHE - l'IA qui regarde plus loin qu'un coup.
##
## BattleAI note un coup et s'arrete la : elle verifie que sa case d'arrivee
## n'est pas attaquee, mais ne joue jamais la REPONSE de l'adversaire. C'est
## exactement ce qui lui fait perdre une tour sur une fourchette de cavalier :
## la case ou elle pose sa tour est sure, alors elle y va, et decouvre le coup
## suivant que le cavalier attaquait deux pieces a la fois.
##
## Ici on deroule l'arbre : je joue, tu reponds, je replique. Un negamax avec
## elagage alpha-beta, en approfondissement iteratif sous contrainte de temps.
##
## Pourquoi ce n'est PAS un moteur d'echecs du commerce : le jeu n'est pas une
## partie d'echecs. Plateaux de 5x6 a 8x9, armees quelconques, aucun roi, et la
## victoire consiste a capturer toute l'armee adverse - pas a mater. Un moteur
## comme Stockfish evalue autour de la securite du roi et consulte des bases de
## positions 8x8 standard : rien de tout cela n'a de sens ici. Ce qui se
## transporte, en revanche, c'est la MECANIQUE : recherche, elagage, ordre des
## coups. C'est ce que fait ce fichier.
##
## Le plateau est modifie puis remis en etat (`_apply` / `_undo`) plutot que
## copie a chaque noeud : une copie de la grille et de toutes les pieces par
## noeud couterait bien plus cher que la recherche elle-meme.
##

## Score d'une position gagnee ou perdue. Tres au-dessus de tout materiel
## possible, pour qu'une victoire passe toujours avant un gain de piece.
const MATE := 1000000.0

## Poids d'un point de materiel. Le reste de l'evaluation doit rester petit
## devant : aucune consideration de position ne vaut une piece.
const MATERIAL := 100.0

## Prime d'avancee vers le camp adverse. Sans elle, deux armees qui ne se
## voient pas encore n'ont aucune raison de se rapprocher : la recherche
## trouve toutes les positions equivalentes et le combat s'enlise.
const ADVANCE := 2.0

## MENACE DE PROMOTION - ce que vaut un pion en marche vers le fond adverse,
## en plus de sa valeur de pion.
##
## C'est le terme qui fait DEFENDRE sa rangee du fond. Sans lui, un camp ne
## voit venir le pion que lorsqu'il entre dans l'horizon de la recherche - a
## profondeur 3, c'est un coup et demi par camp, soit deux cases : bien trop
## tard pour aller au-devant d'un coureur parti de loin.
##
## La prime decroit geometriquement avec la distance, pour qu'un pion a deux
## cases pese assez lourd (81 points, presque une piece) pour detourner un
## defenseur, et qu'un pion a cinq cases ne fasse pas paniquer tout le camp :
##
##   distance    1     2     3     4     5
##   prime      75    37    19     9     5
##
## Calibre a la baisse apres mesure : a 400 de base, la prime valait quatre
## pions et poussait les deux camps a courir au fond plutot qu'a se battre -
## les promotions DOUBLAIENT au lieu de se rarefier. Une prime d'evaluation
## doit pencher la balance, pas faire le travail de la recherche : a deux
## cases du but, la recherche voit deja la promotion toute seule.
##
## Approximation assumee : l'evaluation ignore que la promotion ne donne une
## DAME que dans une bataille encore disputee (cf. BattleEngine._promotion_for).
## Elle surestime donc le coureur en fin de partie - une erreur qui pousse a
## defendre, c'est-a-dire du bon cote.
const PROMOTION_THREAT := 150.0
const PROMOTION_FALLOFF := 0.5


## Meilleur coup pour ce camp. Retourne {"unit": BattleUnit|null, "move":
## Vector2i} - meme forme que BattleAI.decide_team, pour etre interchangeable.
##
## `budget_ms` borne le temps de reflexion : la recherche rend la main des
## qu'il est depasse, avec le meilleur coup de la derniere profondeur ACHEVEE.
## C'est ce qui garantit qu'une bataille sur un grand plateau ne fige jamais
## l'ecran, quel que soit le nombre de pieces.
##
## `budget_ms <= 0` retire toute limite de temps : la recherche va au bout de
## sa profondeur, quel qu'en soit le prix. C'est le mode des BANCS, et il
## existe pour une raison precise.
##
## POURQUOI LES BANCS NE PEUVENT PAS ETRE CHRONOMETRES. Une coupure au temps
## depend de la machine, de sa charge, de l'heure qu'il est. Deux bancs lances
## sur la meme position rendaient deux verdicts differents - l'un annoncait une
## defaite, l'autre un nul - et regler l'equilibre sur un oracle qui change
## d'avis, c'est regler sur du sable. Sans limite, la meme position donne
## toujours le meme coup : le banc redevient une mesure.
##
## Le banc joue donc contre une IA au moins aussi forte que celle du jeu, jamais
## plus faible. C'est le bon sens de l'erreur : une bataille declaree gagnable
## par le banc l'est a coup sur dans le jeu.
static func best_move(team: int, grid: GridModel, units: Array, max_depth: int,
		budget_ms: int) -> Dictionary:
	var moves := _generate(team, grid, units)
	if moves.is_empty():
		return {"unit": null, "move": Vector2i(-1, -1)}

	_order(moves, grid)
	# Sans budget, une echeance hors d'atteinte plutot qu'un test de plus dans
	# la boucle chaude : _negamax est appele des centaines de milliers de fois.
	var deadline := (1 << 62) if budget_ms <= 0 else Time.get_ticks_msec() + budget_ms
	var best: Dictionary = moves[0]

	# Approfondissement iteratif : on cherche a 1, puis 2, puis 3... Deux
	# bienfaits pour un seul mecanisme - on a toujours un coup jouable sous la
	# main si le temps manque, et le meilleur coup de la profondeur precedente
	# passe en tete de liste, ce qui fait couper l'elagage bien plus tot.
	for depth in range(1, maxi(1, max_depth) + 1):
		var alpha := -MATE
		var best_score := -INF
		var found: Dictionary = {}
		var completed := true

		for move in moves:
			var undo := _apply(move["unit"], move["move"], grid)
			var score := -_negamax(
				_other(team), grid, units, depth - 1, -MATE, -alpha, deadline)
			_undo(undo, grid)

			if Time.get_ticks_msec() > deadline:
				completed = false
				break
			if score > best_score:
				best_score = score
				found = move
			alpha = maxf(alpha, best_score)

		# Une profondeur interrompue en cours de route est incomplete : ses
		# premiers coups ont ete evalues plus finement que les suivants, la
		# comparaison ne vaut rien. On garde le verdict de la precedente.
		if completed and not found.is_empty():
			best = found
			moves.erase(best)
			moves.push_front(best)
		if not completed:
			break

	return {"unit": best["unit"], "move": best["move"]}


static func _negamax(team: int, grid: GridModel, units: Array, depth: int,
		alpha: float, beta: float, deadline: int) -> float:
	var mine := _living(team, units)
	var theirs := _living(_other(team), units)
	# Fin de partie : le camp qui n'a plus rien a perdu (cf.
	# BattleEngine._check_end, la victoire c'est capturer toute l'armee).
	if theirs.is_empty():
		return MATE
	if mine.is_empty():
		return -MATE
	if depth <= 0 or Time.get_ticks_msec() > deadline:
		return _evaluate(grid, mine, theirs)

	var moves := _generate(team, grid, units)
	if moves.is_empty():
		# Aucun coup legal : le camp passe la main, il ne perd pas la partie
		# (cf. BattleEngine._pass_turn).
		return -_negamax(_other(team), grid, units, depth - 1, -beta, -alpha, deadline)

	_order(moves, grid)

	var best := -INF
	for move in moves:
		var undo := _apply(move["unit"], move["move"], grid)
		var score := -_negamax(_other(team), grid, units, depth - 1, -beta, -alpha, deadline)
		_undo(undo, grid)
		if score > best:
			best = score
		alpha = maxf(alpha, best)
		if alpha >= beta:
			break  # l'adversaire ne laissera jamais venir ici : inutile de creuser
	return best


## Evaluation de la position, du point de vue du camp a qui appartient `mine`.
## Materiel d'abord, avancee ensuite - et rien d'autre : chaque terme ajoute
## est un terme a regler, et une evaluation trop bavarde joue moins bien
## qu'une evaluation sobre poussee un demi-coup plus loin.
static func _evaluate(grid: GridModel, mine: Array, theirs: Array) -> float:
	return _side_value(grid, mine) - _side_value(grid, theirs)


static func _side_value(grid: GridModel, side: Array) -> float:
	var total := 0.0
	for unit in side:
		total += float(unit.value) * MATERIAL
		total += float(_progress(unit, grid)) * ADVANCE
		if unit.origin_type == Balance.PION and not unit.promoted:
			var distance: int = absi(unit.promotion_row(grid.rows) - unit.cell.y)
			total += PROMOTION_THREAT * pow(PROMOTION_FALLOFF, float(distance))
	return total


## Distance parcourue vers le camp adverse, en rangees. Le joueur remonte vers
## la rangee 0, l'ennemi descend vers la derniere (cf. BattleUnit.forward).
static func _progress(unit: BattleUnit, grid: GridModel) -> int:
	if unit.team == BattleUnit.TEAM_PLAYER:
		return grid.rows - 1 - unit.cell.y
	return unit.cell.y


static func _generate(team: int, grid: GridModel, units: Array) -> Array:
	var moves: Array = []
	for unit in units:
		if not unit.is_alive() or unit.team != team:
			continue
		for cell in MovementRules.legal_moves(unit, grid):
			moves.append({"unit": unit, "move": cell})
	return moves


## Ordre des coups : les prises d'abord, la grosse piece prise par la petite
## en tete. L'elagage alpha-beta ne coupe tot que si les bons coups passent
## en premier - c'est ce tri, bien plus que la profondeur, qui rend la
## recherche tenable sur telephone.
static func _order(moves: Array, grid: GridModel) -> void:
	moves.sort_custom(func(a, b): return _order_key(a, grid) > _order_key(b, grid))


static func _order_key(move: Dictionary, grid: GridModel) -> float:
	var target := grid.unit_at(move["move"])
	if target == null:
		return 0.0
	var unit: BattleUnit = move["unit"]
	if not unit.is_enemy_of(target):
		return 0.0
	return float(target.value) * 10.0 - float(unit.value)


## Joue le coup sur le vrai plateau et retourne de quoi le defaire. Reproduit
## exactement BattleEngine._resolve : capture, deplacement, promotion.
static func _apply(unit: BattleUnit, destination: Vector2i, grid: GridModel) -> Dictionary:
	var undo := {
		"unit": unit,
		"from": unit.cell,
		"had_moved": unit.has_moved,
		"captured": null,
		"promoted": false,
	}

	var target := grid.unit_at(destination)
	if target != null and unit.is_enemy_of(target):
		target.captured = true
		grid.remove_unit(target)
		undo["captured"] = target

	grid.move_unit(unit, destination)
	unit.has_moved = true

	if unit.origin_type == Balance.PION and not unit.promoted \
			and destination.y == unit.promotion_row(grid.rows):
		unit.promote_to(Balance.DAME)
		undo["promoted"] = true

	return undo


static func _undo(undo: Dictionary, grid: GridModel) -> void:
	var unit: BattleUnit = undo["unit"]
	if undo["promoted"]:
		unit.unpromote()
	grid.move_unit(unit, undo["from"])
	unit.has_moved = undo["had_moved"]

	var captured: BattleUnit = undo["captured"]
	if captured != null:
		captured.captured = false
		grid.place(captured, captured.cell)


static func _living(team: int, units: Array) -> Array:
	var alive: Array = []
	for unit in units:
		if unit.is_alive() and unit.team == team:
			alive.append(unit)
	return alive


static func _other(team: int) -> int:
	return BattleUnit.TEAM_ENEMY if team == BattleUnit.TEAM_PLAYER else BattleUnit.TEAM_PLAYER
