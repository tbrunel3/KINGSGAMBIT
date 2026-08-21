extends Node
##
## SONDE DE RECHERCHE - outil de developpement.
##
## Mesure le cout d'UN coup a chaque profondeur, sur la position de depart de
## trois plateaux : le plus petit, un moyen, le plus grand. C'est ce banc qui
## fixe Balance.AI_DEPTH et Balance.AI_BUDGET_MS - a relancer des qu'on touche
## a la taille des plateaux, aux portees des pieces ou a l'evaluation.
##
## Le banc voisin (tools/ai_bench.tscn) repond a l'autre question : est-ce que
## chercher plus loin fait vraiment gagner.
##
##   godot --headless --path . tools/ai_probe.tscn
##

func _ready() -> void:
	for battle_id in [1, 5, 10]:
		var battle := Balance.battle(battle_id)
		var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
		var level := int(battle["level"])
		var enemy_cells: Array = engine.grid.free_enemy_cells()
		var player_cells: Array = engine.grid.free_player_cells()
		var index := 0
		for type in Balance.UNIT_TYPES:
			if not battle["enemies"].has(type):
				continue
			for i in range(int(battle["enemies"][type])):
				engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, enemy_cells[index])
				engine.add_unit(type, level, BattleUnit.TEAM_PLAYER, player_cells[index])
				index += 1

		var moves := 0
		for unit in engine.living(BattleUnit.TEAM_ENEMY):
			moves += MovementRules.legal_moves(unit, engine.grid).size()

		print("bataille %d  %dx%d  %d pieces/camp  %d coups legaux au depart" % [
			battle_id, int(battle["cols"]), int(battle["rows"]), index, moves])

		for depth in [1, 2, 3, 4]:
			var started := Time.get_ticks_usec()
			BattleSearch.best_move(
				BattleUnit.TEAM_ENEMY, engine.grid, engine.units, depth, 100000)
			var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
			print("    profondeur %d : %8.1f ms" % [depth, elapsed])
		print("")

	get_tree().quit()
