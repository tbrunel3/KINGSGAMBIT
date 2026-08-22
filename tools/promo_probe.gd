extends Node
##
## SONDE DE PROMOTION - mesure jetable.
##
## A quel MOMENT de la bataille les pions passent-ils Dame ? Si les promotions
## tombent quand l'armee ennemie est deja rincee, c'est une promotion de
## ramassage : elle ne coute rien et ne merite pas une Dame.
##

func _ready() -> void:
	# Banc : recherche sans limite de temps, donc reproductible (cf.
	# BattleAI.budget_ms).
	BattleAI.budget_ms = 0
	var promotions := 0
	var mopping := 0
	var dames := 0
	print("")
	for battle_id in range(1, Balance.battle_count() + 1):
		var battle := Balance.battle(battle_id)
		var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
		engine.enemy_skill = Balance.battle_ai_skill(battle)
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

		var start_material := engine.material(BattleUnit.TEAM_ENEMY)
		while not engine.finished:
			for event in engine.step():
				if String(event["type"]) != "promotion":
					continue
				var unit := engine.unit_by_id(int(event["unit"]))
				var foe := BattleUnit.TEAM_ENEMY if unit.team == BattleUnit.TEAM_PLAYER else BattleUnit.TEAM_PLAYER
				var left := engine.material(foe)
				var ratio := float(left) / maxf(1.0, float(start_material))
				promotions += 1
				var result := String(event["result"])
				if result == Balance.DAME:
					dames += 1
				if ratio < Balance.PROMOTION_CONTESTED_RATIO:
					mopping += 1
				# POURQUOI CE N'EST PAS UNE DAME. La sonde n'affichait que le
				# ratio de materiel, ce qui laissait croire que c'etait le seul
				# critere : une ligne "CAVALIER, adversaire a 133%" ressemblait
				# alors a un bug alors que la regle s'appliquait correctement.
				# Trois conditions se cumulent (cf. BattleEngine._promotion_for),
				# et on dit maintenant laquelle a mordu.
				var cause := ""
				if result != Balance.DAME:
					if int(unit.captures) <= 0:
						cause = "  <- pion sans capture"
					elif ratio < Balance.PROMOTION_CONTESTED_RATIO:
						cause = "  <- ramassage"
					else:
						cause = "  <- couronne deja prise par ce camp"
				print("  bataille %2d  tour %2d  ->  %-9s  (adversaire a %3d%% de son materiel)%s" % [
					battle_id, engine.turn, Balance.unit_name(result).to_upper(),
					int(round(ratio * 100.0)), cause])

	print("")
	print("  promotions : %d  ->  %d DAMES, %d en piece intermediaire" % [
		promotions, dames, promotions - dames])
	print("  dont %d en situation de ramassage (adversaire sous %d%% de materiel)" % [
		mopping, int(round(Balance.PROMOTION_CONTESTED_RATIO * 100.0))])
	get_tree().quit()
