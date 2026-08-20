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
##   4. si rien n'ameliore la position ET que la bataille est bloquee depuis
##      trop longtemps (cf. _STANDOFF_RATIO), bouger quand meme plutot que de
##      rester plante - une piece ne doit jamais s'arreter indefiniment
##   5. sinon, ne pas bouger
##
## Pour rendre l'IA plus maligne en Phase 2, il suffit de retoucher _score_move :
## le reste du moteur n'a pas a changer.
##

## Valeur en dessous de laquelle une piece accepte D'EMBLEE d'avancer sur une
## case menacee, sans attendre le moindre enlisement. A 1, seuls les pions :
## c'est leur role d'ouvrir le contact et d'etre echanges.
const _EXPENDABLE_VALUE := 1

## Fraction du seuil d'enlisement (BattleEngine._stalemate_limit) au-dela de
## laquelle TOUTE piece sans coup interessant accepte de bouger quand meme -
## y compris sur une case menacee si aucune case sure n'existe - plutot que de
## rester plantee. Sans ca, plusieurs pieces de valeur (ex. 4 Dames apres une
## vague de promotions) peuvent chacune refuser indefiniment d'etre la
## premiere a s'exposer : personne n'attaque, la bataille s'enlise et finit
## tranchee au materiel alors que tout le monde est encore en vie.
##
## Volontairement PAS conditionne a l'absence de pion sacrifiable dans le
## camp : un pion encore vivant mais coince (chemin bloque par ses propres
## pieces, coin du plateau...) ne rejoint jamais le front, et un tel gardien
## empechait avant cette regle toute autre piece du camp de se decoincer -
## c'est exactement le blocage que ce garde-fou doit lever. Rester au-dela de
## la moitie du seuil d'enlisement suffit a garantir que ce n'est pas une
## bataille normale (qui passe naturellement du temps sans prise - position-
## nement, poursuite) qui declenche ceci pour rien, ce qui a fait perdre au
## joueur des combats qu'il gagnait auparavant lors des essais.
const _STANDOFF_RATIO := 0.5

## Nombre minimum de pieces en vie (les deux camps confondus) pour que la
## desperation puisse s'appliquer - cf. "4 Dames sur le plateau" dans le
## rapport d'origine. En dessous, c'est une fin de partie normale a 1-3
## pieces, pas un blocage : y forcer une piece a se sacrifier ne fait que
## rendre une victoire serree perdante pour rien.
const _STANDOFF_MIN_PIECES := 4


## Retourne {"move": Vector2i, "capture": BattleUnit|null}.
## "move" vaut la case actuelle si la piece reste sur place.
## `stalled` = activations consecutives sans capture, `stalemate_limit` = le
## seuil d'enlisement du moteur pour cette bataille (cf. BattleEngine),
## transmis pour la desperation ci-dessus.
static func decide(unit: BattleUnit, grid: GridModel, units: Array, stalled: int = 0, stalemate_limit: int = 999999) -> Dictionary:
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
	# Parmi TOUTES les cases libres, meme celles qui n'avancent pas, la moins
	# survolee par l'ennemi - cf. desperation ci-dessous. Une piece coincee
	# dans un angle du plateau peut n'avoir QUE des cases qui l'eloignent :
	# sans ce filet calcule hors du "score <= 0: continue" plus bas, elle
	# resterait plantee indefiniment meme en situation de blocage confirmee.
	var least_exposed_cell := Vector2i(-1, -1)
	var least_threats := 999
	var least_exposed_score := -INF

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

		var threatened := _would_be_threatened(cell, unit, enemy_team, grid, units)
		if threatened:
			var threats := _threat_count(cell, unit, enemy_team, grid, units)
			if threats < least_threats or (threats == least_threats and score > least_exposed_score):
				least_threats = threats
				least_exposed_cell = cell
				least_exposed_score = score
		elif score > least_exposed_score:
			# Une case sure prime toujours sur une case menacee, meme si elle
			# ne rapproche de rien : la desperation ne veut pas dire foncer
			# dans le mur, juste refuser l'immobilisme.
			least_threats = 0
			least_exposed_cell = cell
			least_exposed_score = score

		if score <= 0:
			continue
		if score > any_score:
			any_score = score
			any_cell = cell
		if not threatened and score > safe_score:
			safe_score = score
			safe_cell = cell

	if safe_cell != Vector2i(-1, -1):
		return {"move": safe_cell, "capture": null}

	# 3. Aucune case sure. Les pieces de faible valeur avancent quand meme :
	#    c'est le role du pion d'ouvrir le contact et d'etre echange.
	if any_cell != Vector2i(-1, -1) and unit.value <= _EXPENDABLE_VALUE:
		return {"move": any_cell, "capture": null}

	# 4. Enlisement confirme (cf. _STANDOFF_RATIO) : quelle que soit sa valeur
	#    et meme sans coup qui rapproche de l'ennemi, une piece qui a une case
	#    libre ne doit plus rester plantee - sinon le combat ne se termine
	#    jamais alors que des pieces sont encore en vie des deux cotes. Elle
	#    prend la case la moins survolee (least_exposed_cell), qui peut tres
	#    bien etre totalement sure : la desperation ne force pas un saut
	#    suicide, elle interdit juste l'immobilisme prolonge.
	var desperate := _total_alive(units) >= _STANDOFF_MIN_PIECES \
		and stalled >= int(float(stalemate_limit) * _STANDOFF_RATIO)
	if desperate and least_exposed_cell != Vector2i(-1, -1):
		return {"move": least_exposed_cell, "capture": null}

	# 5. Rien de sur, la piece vaut trop cher pour se sacrifier hors enlisement
	#    confirme : elle tient sa position. Si les deux camps s'immobilisent,
	#    le moteur tranche au materiel restant apres Balance.COMBAT.stalemate.
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


## Nombre d'ennemis capables d'atteindre cette case si la piece s'y installe -
## cf. desperation dans decide() : entre deux cases menacees, celle visee par
## un seul ennemi reste moins risquee que celle visee par trois.
static func _threat_count(cell: Vector2i, unit: BattleUnit, enemy_team: int, grid: GridModel, units: Array) -> int:
	var origin := unit.cell
	var victim := grid.unit_at(cell)

	grid.remove_unit(unit)
	if victim != null:
		grid.remove_unit(victim)
	grid.place(unit, cell)

	var count := 0
	for other in units:
		if other.is_alive() and other.team == enemy_team and MovementRules.legal_moves(other, grid).has(cell):
			count += 1

	grid.remove_unit(unit)
	if victim != null:
		grid.place(victim, cell)
	grid.place(unit, origin)

	return count


static func _living_enemies(unit: BattleUnit, units: Array) -> Array:
	var enemies: Array = []
	for other in units:
		if other.is_alive() and unit.is_enemy_of(other):
			enemies.append(other)
	return enemies


static func _total_alive(units: Array) -> int:
	var count := 0
	for other in units:
		if other.is_alive():
			count += 1
	return count


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _distance_to_nearest(cell: Vector2i, enemies: Array) -> int:
	var best := 9999
	for enemy in enemies:
		best = mini(best, _distance(cell, enemy.cell))
	return best
