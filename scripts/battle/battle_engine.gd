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
##   {"type": "activate", "unit": id}
##   {"type": "move",     "unit": id, "from": Vector2i, "to": Vector2i}
##   {"type": "attack",   "unit": id, "target": id, "damage": int, "target_hp": int}
##   {"type": "death",    "unit": id}
##   {"type": "end",      "winner": team, "reason": String}
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

## Nombre d'activations consecutives sans le moindre degat. Sert a detecter
## deux armees qui ne peuvent plus s'atteindre.
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


## Retire une unite du plateau (utilise pendant la phase de placement).
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

	var decision := BattleAI.decide(unit, grid, units)

	var destination: Vector2i = decision["move"]
	if destination != unit.cell:
		var from := unit.cell
		grid.move_unit(unit, destination)
		events.append({"type": "move", "unit": unit.id, "from": from, "to": destination})

	var target: BattleUnit = decision["target"]
	var dealt_damage := false
	if target != null and target.is_alive() and MovementRules.can_attack(unit, target):
		var killed := target.take_damage(unit.damage)
		dealt_damage = true
		events.append({
			"type": "attack",
			"unit": unit.id,
			"target": target.id,
			"damage": unit.damage,
			"target_hp": target.hp,
		})
		if killed:
			grid.remove_unit(target)
			events.append({"type": "death", "unit": target.id})

	_idle_activations = 0 if dealt_damage else _idle_activations + 1
	current_team = _other_team(current_team)

	if not _check_end(events):
		# Deux armees qui ne peuvent plus s'atteindre ne doivent pas bloquer la
		# partie : on tranche aux points de vie restants.
		if _idle_activations >= int(Balance.COMBAT["stalemate_limit"]):
			_finish_on_health("plus aucun contact possible", events)
		elif activation_count >= int(Balance.COMBAT["max_activations"]):
			_finish_on_health("limite de tours atteinte", events)

	return events


## Departage sur le total de points de vie restants. En cas d'egalite parfaite,
## l'avantage va a l'ennemi : au joueur d'aller chercher la victoire.
func _finish_on_health(reason: String, events: Array) -> void:
	var player_hp := total_health(TEAM_PLAYER)
	var enemy_hp := total_health(TEAM_ENEMY)
	_finish(TEAM_PLAYER if player_hp > enemy_hp else TEAM_ENEMY, reason, events)


func total_health(team: int) -> int:
	var total := 0
	for unit in living(team):
		total += unit.hp
	return total


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


func _check_end(events: Array) -> bool:
	if finished:
		return true
	if living(TEAM_ENEMY).is_empty():
		_finish(TEAM_PLAYER, "armee ennemie aneantie", events)
		return true
	if living(TEAM_PLAYER).is_empty():
		_finish(TEAM_ENEMY, "armee du Roi aneantie", events)
		return true
	return false


func _finish(winning_team: int, reason: String, events: Array) -> void:
	finished = true
	winner = winning_team
	events.append({"type": "end", "winner": winning_team, "reason": reason})


func _other_team(team: int) -> int:
	return TEAM_ENEMY if team == TEAM_PLAYER else TEAM_PLAYER
