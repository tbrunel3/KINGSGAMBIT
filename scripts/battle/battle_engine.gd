class_name BattleEngine
extends RefCounted
##
## MOTEUR DE COMBAT - la boucle tour par tour, sans aucun affichage.
##
## Le moteur ne connait ni animation ni vitesse : step() resout une activation
## complete d'un coup et retourne la liste des evenements qui viennent de se
## produire. C'est la vue qui les rejoue plus ou moins vite.
##
## Consequence importante : x1, x2, x4 et Pause ne changent RIEN au resultat
## d'une bataille. Le combat est entierement determine par le placement.
##
## Evenements produits :
##   {"type": "activate",  "unit": id}
##   {"type": "move",      "unit": id, "from": Vector2i, "to": Vector2i}
##   {"type": "capture",   "unit": id, "target": id, "cell": Vector2i}
##   {"type": "promotion", "unit": id, "cell": Vector2i}
##   {"type": "end",       "winner": team, "reason": String}
##

const TEAM_PLAYER := BattleUnit.TEAM_PLAYER
const TEAM_ENEMY := BattleUnit.TEAM_ENEMY

var grid: GridModel
var units: Array = []

var finished: bool = false
var winner: int = -1
var activation_count: int = 0

## Camp qui joue la prochaine activation. Le joueur ouvre toujours la bataille.
var current_team: int = TEAM_PLAYER

var _next_id: int = 1
var _queues: Dictionary = {TEAM_PLAYER: [], TEAM_ENEMY: []}

## Activations consecutives sans capture. Sert a detecter deux armees qui ne
## peuvent plus s'atteindre.
var _idle_activations: int = 0


func _init(cols: int, rows: int) -> void:
	grid = GridModel.new(cols, rows)


# ------------------------------- CONSTRUCTION --------------------------------

func add_unit(type: String, level: int, team: int, cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.create(_next_id, type, level, team, cell)
	_next_id += 1
	units.append(unit)
	grid.place(unit, cell)
	return unit


## Retire une piece du plateau (utilise pendant la phase de placement).
func remove_unit(unit: BattleUnit) -> void:
	grid.remove_unit(unit)
	units.erase(unit)


func unit_by_id(id: int) -> BattleUnit:
	for unit in units:
		if unit.id == id:
			return unit
	return null


func living(team: int) -> Array:
	var result: Array = []
	for unit in units:
		if unit.is_alive() and unit.team == team:
			result.append(unit)
	return result


## Pieces d'un camp capturees pendant la bataille, comptees par type d'origine.
## Une Dame promue puis prise compte comme le pion qu'elle etait.
func losses(team: int) -> Dictionary:
	var lost: Dictionary = {}
	for unit in units:
		if unit.team != team or unit.is_alive():
			continue
		lost[unit.origin_type] = int(lost.get(unit.origin_type, 0)) + 1
	return lost


## Pieces d'un camp encore debout, comptees par type d'origine : c'est l'armee
## qui rentre au village.
func survivors(team: int) -> Dictionary:
	var alive: Dictionary = {}
	for unit in living(team):
		alive[unit.origin_type] = int(alive.get(unit.origin_type, 0)) + 1
	return alive


# ------------------------------- BOUCLE --------------------------------------

## Resout une activation et retourne les evenements correspondants.
func step() -> Array:
	var events: Array = []
	if finished:
		return events

	if _check_end(events):
		return events

	var unit := _next_unit(current_team)
	if unit == null:
		_finish(_other_team(current_team), "camp vide", events)
		return events

	activation_count += 1
	events.append({"type": "activate", "unit": unit.id})

	var decision := BattleAI.decide(unit, grid, units, _idle_activations, _stalemate_limit())
	var destination: Vector2i = decision["move"]
	var captured := false

	if destination != unit.cell:
		var from := unit.cell
		var target: BattleUnit = grid.unit_at(destination)

		if target != null and unit.is_enemy_of(target):
			target.captured = true
			grid.remove_unit(target)
			captured = true
			events.append({
				"type": "capture",
				"unit": unit.id,
				"target": target.id,
				"cell": destination,
			})

		grid.move_unit(unit, destination)
		events.append({"type": "move", "unit": unit.id, "from": from, "to": destination})

		# Promotion : un pion qui atteint le fond adverse devient Dame, comme
		# aux echecs. Elle garde le niveau du pion (voir BattleUnit.promote_to) :
		# une Dame issue d'un pion Nv.1 se deplace donc bien moins loin que
		# celle d'un pion Nv.10.
		if unit.origin_type == Balance.PION and not unit.promoted \
				and destination.y == unit.promotion_row(grid.rows):
			unit.promote_to(Balance.DAME)
			events.append({
				"type": "promotion", "unit": unit.id, "cell": destination, "result": Balance.DAME,
			})

	_idle_activations = 0 if captured else _idle_activations + 1
	current_team = _other_team(current_team)

	if not _check_end(events):
		# Deux armees qui ne peuvent plus s'atteindre ne doivent pas bloquer la
		# partie : on tranche au nombre de pieces restantes.
		if _idle_activations >= _stalemate_limit():
			_finish_on_material("plus aucune prise possible", events)
		elif activation_count >= int(Balance.COMBAT["max_activations"]):
			_finish_on_material("limite de tours atteinte", events)

	return events


func _next_unit(team: int) -> BattleUnit:
	var queue: Array = _queues[team]
	while true:
		if queue.is_empty():
			for unit in units:
				if unit.team == team and unit.is_alive():
					queue.append(unit.id)
			if queue.is_empty():
				return null
		var id: int = queue.pop_front()
		var candidate := unit_by_id(id)
		if candidate != null and candidate.is_alive():
			return candidate
	return null


## Seuil d'enlisement exprime en activations, deduit du nombre de pieces encore
## en jeu : un tour complet coute une activation par piece vivante. Plafonne a
## Balance.COMBAT.stalemate_seconds_cap de temps reel a vitesse x1 (converti en
## activations via step_delay) : quelle que soit la taille de l'armee, une
## bataille bloquee ne doit jamais faire attendre le joueur plus longtemps que
## ca avant d'etre tranchee - cf. le "chrono" affiche cote vue (battle.gd).
func _stalemate_limit() -> int:
	var alive := living(TEAM_PLAYER).size() + living(TEAM_ENEMY).size()
	var by_army_size := int(Balance.COMBAT["stalemate_rounds"]) * maxi(4, alive)
	var seconds_cap := int(Balance.COMBAT["stalemate_seconds_cap"])
	var by_seconds := int(ceil(float(seconds_cap) / float(Balance.COMBAT["step_delay"])))
	return mini(by_army_size, by_seconds)


## Progression vers l'enlisement (0 = aucune prise recente, 1 = resolution
## imminente au materiel). Sert uniquement a l'affichage du "chrono" de
## blocage cote vue - la resolution elle-meme reste pilotee par step().
func stalemate_ratio() -> float:
	var limit := _stalemate_limit()
	return 0.0 if limit <= 0 else clampf(float(_idle_activations) / float(limit), 0.0, 1.0)


## Temps restant, en secondes de jeu a vitesse x1, avant que le moteur tranche
## au materiel si aucune prise ne survient d'ici la. La vue divise par la
## vitesse choisie pour l'affichage : le seuil reel, lui, ne bouge pas.
func stalemate_seconds_remaining() -> float:
	var remaining := _stalemate_limit() - _idle_activations
	return maxf(0.0, float(remaining) * float(Balance.COMBAT["step_delay"]))


## Departage a la valeur totale des pieces restantes. En cas d'egalite parfaite,
## l'avantage va a l'ennemi : au joueur d'aller chercher la victoire.
func _finish_on_material(reason: String, events: Array) -> void:
	_finish(TEAM_PLAYER if material(TEAM_PLAYER) > material(TEAM_ENEMY) else TEAM_ENEMY, reason, events)


func material(team: int) -> int:
	var total := 0
	for unit in living(team):
		total += unit.value
	return total


func _check_end(events: Array) -> bool:
	if finished:
		return true
	if living(TEAM_ENEMY).is_empty():
		_finish(TEAM_PLAYER, "armee ennemie capturee", events)
		return true
	if living(TEAM_PLAYER).is_empty():
		_finish(TEAM_ENEMY, "armee du Roi capturee", events)
		return true
	return false


func _finish(winning_team: int, reason: String, events: Array) -> void:
	finished = true
	winner = winning_team
	events.append({"type": "end", "winner": winning_team, "reason": reason})


func _other_team(team: int) -> int:
	return TEAM_ENEMY if team == TEAM_PLAYER else TEAM_PLAYER
