extends Node
##
## SONDE DE SERIE - une bataille se joue-t-elle jusqu'au bout ?
##
## Lancement :
##   godot --headless --path . tools/series_probe.tscn
##
## LE TROU QU'ELLE BOUCHE. Ni smoke_test ni tune_probe ne jouent jamais de
## SERIE : ils jouent UN combat, avec une armee au complet. Or huit batailles
## sur dix se gagnent en deux ou trois combats d'affilee, sans retour au
## village. Entre les deux, l'ennemi revient entier et le joueur revient avec
## ses survivants - c'est meme la definition de la difficulte du jeu. Tout ce
## que disaient les deux autres bancs sur les dernieres batailles portait donc
## sur une situation qui n'existe pas.
##
## La sonde economique, elle, joue bien les series, et c'est elle qui a leve le
## lievre : elle a monte TOUT au niveau 10 - chateau et casernes - et perdait
## encore la bataille 10. Aucune somme d'or n'y change quoi que ce soit ; ce
## n'est pas un probleme d'economie mais de combat.
##
## CE QU'ELLE MESURE. La meme serie, jouee sous plusieurs reglages, pour voir
## lequel la rend franchissable :
##
##   - le nombre de combats de la serie (Balance.CAMPAIGN.fights)
##   - l'effectif de l'armee ennemie
##   - le poids de renfort releve entre deux combats (RUN_REINFORCE_WEIGHT)
##
## Un seul de ces trois boutons devrait suffire. Le but est de savoir lequel
## coute le moins cher au jeu.
##
## BIAIS, les memes que partout : les deux camps sont joues par la recherche a
## profondeur pleine, donc c'est un JOUEUR PARFAIT. Un humain fera moins bien.
## Et le resultat est lu sur plusieurs rangements, jamais sur un seul (cf.
## tune_probe : un combat deterministe n'est pas pour autant representatif).
##

## Batailles mesurees - les series de trois, ou le probleme se pose.
const BATAILLES := [8, 9, 10]

## Rangements essayes par configuration.
const FORMATIONS := 3

## Niveau du joueur : le MAXIMUM. La question n'est pas "a quel niveau faut-il
## etre" - la sonde economique a montre que meme tout au maximum ne suffit pas -
## mais "cette serie se gagne-t-elle, au mieux de ce que le jeu permet".
var _niveau := Balance.MAX_LEVEL


func _ready() -> void:
	# Banc : recherche sans limite de temps, donc reproductible (cf.
	# BattleAI.budget_ms).
	BattleAI.budget_ms = 0
	print("")
	print("=== SONDE DE SERIE ===")
	print("  Joueur au niveau %d (le maximum), %d rangements par configuration." % [
		_niveau, FORMATIONS])
	print("  Les deux camps sont joues par la recherche : resultat d'un joueur parfait.")
	print("")

	for battle_id in BATAILLES:
		var battle := Balance.battle(battle_id)
		var fights := Balance.battle_fights(battle)
		var ennemis := _effectif(battle)
		print("  Bataille %d - %s : %d combats, %d ennemis, renfort %d" % [
			battle_id, String(battle["name"]), fights, ennemis,
			Balance.RUN_REINFORCE_WEIGHT])
		print("    reglage                        serie gagnee   combats gagnes")
		print("    ---------------------------------------------------------------")

		_mesurer(battle, "tel quel", fights, 1.0, Balance.RUN_REINFORCE_WEIGHT)
		if fights > 1:
			_mesurer(battle, "un combat de moins", fights - 1, 1.0, Balance.RUN_REINFORCE_WEIGHT)
		_mesurer(battle, "ennemis -20%%", fights, 0.8, Balance.RUN_REINFORCE_WEIGHT)
		_mesurer(battle, "renfort x3", fights, 1.0, Balance.RUN_REINFORCE_WEIGHT * 3)
		_mesurer(battle, "renfort x6", fights, 1.0, Balance.RUN_REINFORCE_WEIGHT * 6)
		print("")

	get_tree().quit(0)


func _effectif(battle: Dictionary) -> int:
	var total := 0
	for type in Balance.UNIT_TYPES:
		total += int(battle["enemies"].get(type, 0))
	return total


## Une configuration, jouee sur FORMATIONS rangements.
func _mesurer(battle: Dictionary, nom: String, fights: int, ratio_ennemi: float,
		renfort: int) -> void:
	var series_gagnees := 0
	var combats_gagnes := 0
	var combats_joues := 0
	for formation in range(FORMATIONS):
		var issue := _jouer_serie(battle, fights, ratio_ennemi, renfort, formation)
		if bool(issue["gagnee"]):
			series_gagnees += 1
		combats_gagnes += int(issue["gagnes"])
		combats_joues += fights
	print("    %-30s %d/%d            %d/%d" % [
		nom, series_gagnees, FORMATIONS, combats_gagnes, combats_joues])


## La serie entiere. L'armee ennemie revient au complet a chaque combat ; le
## joueur revient avec ses survivants, plus le renfort d'entre-deux.
func _jouer_serie(battle: Dictionary, fights: int, ratio_ennemi: float, renfort: int,
		formation: int) -> Dictionary:
	# Effectif de depart : les casernes pleines au niveau vise.
	var effectif: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		effectif[type] = Balance.capacity(type, _niveau)

	var gagnes := 0
	for fight in range(1, fights + 1):
		var combat := _jouer_combat(battle, effectif, ratio_ennemi, formation)
		for type in combat["pertes"].keys():
			effectif[type] = maxi(0, int(effectif.get(type, 0)) - int(combat["pertes"][type]))
		if not bool(combat["gagne"]):
			return {"gagnee": false, "gagnes": gagnes}
		gagnes += 1
		if fight < fights:
			_renforcer(effectif, combat["pertes"], renfort)

	return {"gagnee": true, "gagnes": gagnes}


func _jouer_combat(battle: Dictionary, effectif: Dictionary, ratio_ennemi: float,
		formation: int) -> Dictionary:
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = Balance.battle_ai_skill(battle)
	engine.auto_mode = true

	var level := int(battle["level"])
	var cells: Array = engine.grid.free_enemy_cells()
	var index := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		# Le ratio retire des pieces en gardant la composition : on arrondit
		# vers le haut pour ne jamais faire disparaitre un type entier.
		var count := int(ceil(float(int(battle["enemies"][type])) * ratio_ennemi))
		for i in range(count):
			if index >= cells.size():
				break
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[index])
			index += 1

	var pose := _poser(engine, effectif.duplicate(), formation)

	while not engine.finished:
		engine.step()

	var survivants: Dictionary = {}
	for unit in engine.living(BattleUnit.TEAM_PLAYER):
		survivants[unit.origin_type] = int(survivants.get(unit.origin_type, 0)) + 1

	var pertes: Dictionary = {}
	for type in pose.keys():
		var perdu := int(pose[type]) - int(survivants.get(type, 0))
		if perdu > 0:
			pertes[type] = perdu

	return {"gagne": engine.winner == BattleUnit.TEAM_PLAYER, "pertes": pertes}


## Formation de reference, la meme que les autres bancs : les types alternent,
## les pions devant, et le rangement tourne d'une variante a l'autre.
func _poser(engine: BattleEngine, pool: Dictionary, formation: int) -> Dictionary:
	var capacite := Balance.deploy_capacity(_niveau)
	var ordre: Array = []
	var poids := 0
	var epuises: Dictionary = {}
	while true:
		var type := _tour_de_role(pool, ordre.size(), epuises)
		if type.is_empty():
			break
		var p := Balance.deploy_weight(type)
		if poids + p > capacite:
			epuises[type] = true
			continue
		ordre.append(type)
		poids += p
		pool[type] = int(pool[type]) - 1

	ordre.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))

	var cells: Array = engine.grid.free_player_cells()
	var decalage := (formation * 3) % maxi(1, cells.size())
	var poses: Dictionary = {}
	for i in range(mini(ordre.size(), cells.size())):
		var type := String(ordre[i])
		engine.add_unit(type, _niveau, BattleUnit.TEAM_PLAYER,
			cells[(i + decalage) % cells.size()])
		poses[type] = int(poses.get(type, 0)) + 1
	return poses


func _tour_de_role(pool: Dictionary, curseur: int, epuises: Dictionary) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(curseur + offset) % types.size()]
		if epuises.has(type):
			continue
		if int(pool.get(type, 0)) > 0:
			return type
	return ""


## Renforts d'entre-deux-combats : `budget` de poids releve parmi les pertes,
## les moins cheres d'abord.
func _renforcer(effectif: Dictionary, pertes: Dictionary, budget: int) -> void:
	var reste := budget
	var types: Array = Balance.UNIT_TYPES.duplicate()
	types.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))
	for type in types:
		while reste >= Balance.deploy_weight(type) and int(pertes.get(type, 0)) > 0:
			reste -= Balance.deploy_weight(type)
			pertes[type] = int(pertes[type]) - 1
			effectif[type] = int(effectif.get(type, 0)) + 1
