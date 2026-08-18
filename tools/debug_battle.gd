extends Node
##
## TRACE D'UNE BATAILLE - outil de diagnostic.
##
## Rejoue une bataille coup par coup en imprimant chaque activation et le
## plateau. Sert a comprendre POURQUOI une bataille tourne mal, plutot qu'a
## regler des valeurs au hasard.
##
## Lancement :
##   godot --headless --path . tools/debug_battle.tscn
##

const BATTLE_ID := 1
const MAX_PRINTED := 40


func _ready() -> void:
	var battle := Balance.battle(BATTLE_ID)
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))

	var cells: Array = engine.grid.free_enemy_cells()
	var index := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, int(battle["level"]), BattleUnit.TEAM_ENEMY, cells[index])
			index += 1

	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		pool[type] = int(Balance.STARTING_UNITS.get(type, 0))

	var placed := 0
	var cursor := 0
	for cell in engine.grid.free_player_cells():
		if placed >= Balance.deploy_slots(1):
			break
		var type := _pick(pool, cursor)
		if type.is_empty():
			break
		engine.add_unit(type, 1, BattleUnit.TEAM_PLAYER, cell)
		pool[type] = int(pool[type]) - 1
		cursor += 1
		placed += 1

	print("=== Bataille %d - armee de depart ===" % BATTLE_ID)
	_print_board(engine)

	var step := 0
	while not engine.finished and step < MAX_PRINTED:
		step += 1
		var team_name := "JOUEUR" if engine.current_team == BattleUnit.TEAM_PLAYER else "ennemi"
		var events := engine.step()
		var line := "%2d. %-6s " % [step, team_name]
		for event in events:
			match String(event["type"]):
				"activate":
					var unit := engine.unit_by_id(int(event["unit"]))
					line += "%s%s en %s " % [
						Balance.unit_letter(unit.type),
						"" if unit.team == BattleUnit.TEAM_PLAYER else "'",
						unit.cell]
				"move":
					line += "-> %s " % event["to"]
				"capture":
					var victim := engine.unit_by_id(int(event["target"]))
					line += "PREND %s en %s " % [Balance.unit_letter(victim.type), event["cell"]]
				"promotion":
					line += "PROMOTION "
				"end":
					line += "| FIN : %s (%s)" % [
						"joueur" if int(event["winner"]) == BattleUnit.TEAM_PLAYER else "ennemi",
						String(event["reason"])]
		print(line)

	print("")
	_print_board(engine)
	print("materiel restant : joueur %d, ennemi %d" % [
		engine.material(BattleUnit.TEAM_PLAYER), engine.material(BattleUnit.TEAM_ENEMY)])
	get_tree().quit()


func _print_board(engine: BattleEngine) -> void:
	for y in range(engine.grid.rows):
		var line := "  "
		for x in range(engine.grid.cols):
			var unit := engine.grid.unit_at(Vector2i(x, y))
			if unit == null:
				line += " . "
			elif unit.team == BattleUnit.TEAM_PLAYER:
				line += " %s " % Balance.unit_letter(unit.type)
			else:
				line += " %s'" % Balance.unit_letter(unit.type).to_lower()
		print(line)
	print("")


func _pick(pool: Dictionary, cursor: int) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(cursor + offset) % types.size()]
		if int(pool[type]) > 0:
			return type
	return ""
