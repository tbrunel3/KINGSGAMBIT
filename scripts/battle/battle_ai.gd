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


## Coup du camp entier : QUELLE piece jouer, et ou. Depuis que le combat se
## joue coup par coup, un camp ne deplace qu'une seule piece par tour - il
## faut donc choisir la meilleure, exactement comme le joueur en face choisit
## la sienne. On demande son intention a chaque piece (decide), on note le
## coup obtenu (_move_score), et on garde le meilleur.
##
## Retourne {"unit": BattleUnit|null, "move": Vector2i}. unit vaut null quand
## le camp n'a strictement aucun coup a jouer : le moteur passe alors la main.
static func decide_team(team: int, grid: GridModel, units: Array, stalled: int = 0,
		stalemate_limit: int = 999999, skill: int = Balance.AI_EXPERT) -> Dictionary:
	var best := _best_of_team(team, grid, units, stalled, stalemate_limit, skill)
	if best["unit"] != null:
		return best

	# Personne ne veut bouger : toutes les pieces jugent leur position
	# meilleure que n'importe quel deplacement. Rester plante fait perdre la
	# bataille a l'usure, alors on rejoue la decision en mode "desperation"
	# (cf. _STANDOFF_RATIO), qui accepte la case la moins exposee.
	return _best_of_team(team, grid, units, stalemate_limit, stalemate_limit, skill)


static func _best_of_team(team: int, grid: GridModel, units: Array, stalled: int,
		stalemate_limit: int, skill: int) -> Dictionary:
	var best_unit: BattleUnit = null
	var best_move := Vector2i(-1, -1)
	var best_score := -INF

	for unit in units:
		if not unit.is_alive() or unit.team != team:
			continue
		var decision := decide(unit, grid, units, stalled, stalemate_limit, skill)
		var destination: Vector2i = decision["move"]
		if destination == unit.cell:
			continue
		var score := _move_score(unit, destination, grid, units, skill)
		if score > best_score:
			best_score = score
			best_unit = unit
			best_move = destination

	return {"unit": best_unit, "move": best_move}


## Note d'un coup deja choisi, pour les comparer entre pieces d'un meme camp.
## Trois urgences, dans cet ordre : prendre du materiel, sauver une piece
## menacee, sinon avancer - une piece chere avance en dernier, elle a plus a
## perdre au contact.
static func _move_score(unit: BattleUnit, destination: Vector2i, grid: GridModel, units: Array,
		skill: int = Balance.AI_EXPERT) -> float:
	var enemy_team := BattleUnit.TEAM_ENEMY if unit.team == BattleUnit.TEAM_PLAYER else BattleUnit.TEAM_PLAYER
	var score := 0.0

	# Une case menacee OU l'on peut etre repris par un allie n'est pas une
	# case perdue : c'est un echange. Une case menacee sans defense, si.
	# Une IA novice ne se demande pas si la case est tenue : c'est exactement
	# ce qui la rend battable.
	var threatened: bool = skill > Balance.AI_NOVICE \
		and _would_be_threatened(destination, unit, enemy_team, grid, units)
	var exposed := threatened and not _would_be_defended(destination, unit, grid, units)

	var target := grid.unit_at(destination)
	if target != null and unit.is_enemy_of(target):
		score += 100.0 + float(target.value) * 10.0
		if exposed:
			score -= float(unit.value) * 10.0
	elif exposed:
		# Avancer une piece la ou l'adversaire la prend gratuitement, c'est
		# la donner. Le plus gros piege du combat coup par coup : une seule
		# piece bouge par tour, personne ne vient la couvrir apres coup.
		score -= float(unit.value) * 12.0

	var fleeing: bool = skill >= Balance.AI_EXPERT \
		and MovementRules.is_cell_threatened(unit.cell, enemy_team, grid, units)
	if fleeing and not _would_be_threatened(destination, unit, enemy_team, grid, units):
		# Fuite reussie : d'autant plus urgente que la piece vaut cher.
		score += 40.0 + float(unit.value) * 8.0

	var enemies := _living_enemies(unit, units)
	var gained := _distance_to_nearest(unit.cell, enemies) - _distance_to_nearest(destination, enemies)
	score += float(gained) * 3.0 - float(unit.value) * 0.5

	# Un pion a une case de la promotion passe avant tout le reste : c'est une
	# Dame de plus sur le plateau, et une Dame de plus au village.
	var wants_queen: bool = unit.origin_type == Balance.PION and not unit.promoted
	if wants_queen and destination.y == unit.promotion_row(grid.rows):
		score += 80.0

	return score


## Retourne {"move": Vector2i, "capture": BattleUnit|null}.
## "move" vaut la case actuelle si la piece reste sur place.
## `stalled` = activations consecutives sans capture, `stalemate_limit` = le
## seuil d'enlisement du moteur pour cette bataille (cf. BattleEngine),
## transmis pour la desperation ci-dessus.
static func decide(unit: BattleUnit, grid: GridModel, units: Array, stalled: int = 0,
		stalemate_limit: int = 999999, skill: int = Balance.AI_EXPERT) -> Dictionary:
	var enemies := _living_enemies(unit, units)
	if enemies.is_empty():
		return {"move": unit.cell, "capture": null}

	var moves := MovementRules.legal_moves(unit, grid)
	if moves.is_empty():
		return {"move": unit.cell, "capture": null}

	var enemy_team := BattleUnit.TEAM_ENEMY if unit.team == BattleUnit.TEAM_PLAYER else BattleUnit.TEAM_PLAYER

	# Une piece deja attaquee sera prise si elle ne fait rien : ses calculs
	# changent completement, elle n'a plus rien a proteger.
	# Seule une IA experte sauve une piece deja attaquee ; en dessous, elle
	# poursuit son plan et encaisse.
	var in_danger: bool = skill >= Balance.AI_EXPERT \
		and MovementRules.is_cell_threatened(unit.cell, enemy_team, grid, units)

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
		if skill > Balance.AI_NOVICE and _would_be_threatened(cell, unit, enemy_team, grid, units):
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
	## Case qui promeut immediatement, si elle est atteignable ce tour-ci.
	var promotion_cell := Vector2i(-1, -1)

	for cell in moves:
		if grid.unit_at(cell) != null:
			continue
		if wants_promotion and cell.y == promotion_row:
			promotion_cell = cell
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

	# Une IA novice prend la case qui la rapproche le plus, sans se demander
	# qui la couvre : elle laisse des pieces en prise, et c'est la sa faiblesse.
	if skill == Balance.AI_NOVICE and any_cell != Vector2i(-1, -1):
		return {"move": any_cell, "capture": null}

	if safe_cell != Vector2i(-1, -1):
		return {"move": safe_cell, "capture": null}

	# 2bis. Promotion a portee de main : le pion y va, meme sur une case
	#       menacee et sans personne pour le reprendre. Une Dame vaut neuf
	#       pions ; refuser le dernier pas serait garder le pion et perdre la
	#       Dame. C'est aussi la seule facon d'en ramener une au village.
	if promotion_cell != Vector2i(-1, -1):
		return {"move": promotion_cell, "capture": null}

	# 3. Aucune case sure. Les pieces de faible valeur avancent quand meme,
	#    mais SEULEMENT si une piece amie peut reprendre derriere : c'est le
	#    role du pion d'ouvrir le contact et d'etre echange, pas d'etre donne.
	#    Depuis que le combat se joue coup par coup, un pion pousse seul sur
	#    une case couverte par l'adversaire ne revient jamais - la ligne
	#    entiere y passait, un pion par tour.
	var covered: bool = any_cell != Vector2i(-1, -1) and _would_be_defended(any_cell, unit, grid, units)
	if covered and unit.value <= _EXPENDABLE_VALUE:
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


## Vrai si une piece AMIE pourrait reprendre sur cette case, autrement dit si
## s'y faire capturer serait un echange et non un cadeau.
##
## Astuce : on y pose la piece en la faisant passer temporairement pour une
## piece adverse. Sans ca, aucune de nos pieces ne "menacerait" la case - on
## ne capture jamais un allie, et le pion ne genere sa diagonale que s'il y a
## quelque chose a prendre.
static func _would_be_defended(cell: Vector2i, unit: BattleUnit, grid: GridModel, units: Array) -> bool:
	var origin := unit.cell
	var victim := grid.unit_at(cell)
	var real_team := unit.team

	grid.remove_unit(unit)
	if victim != null:
		grid.remove_unit(victim)
	unit.team = BattleUnit.TEAM_ENEMY if real_team == BattleUnit.TEAM_PLAYER else BattleUnit.TEAM_PLAYER
	grid.place(unit, cell)

	var defended := MovementRules.is_cell_threatened(cell, real_team, grid, units)

	grid.remove_unit(unit)
	unit.team = real_team
	if victim != null:
		grid.place(victim, cell)
	grid.place(unit, origin)

	return defended


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
