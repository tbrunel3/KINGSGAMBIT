extends Node
##
## SONDE ECONOMIQUE - le jeu donne-t-il assez d'or pour etre traverse ?
##
## Lancement :
##   godot --headless --path . tools/economy_probe.tscn
##
## LA QUESTION. Quatre bancs mesurent le combat ; aucun ne mesure l'ARGENT. Or
## smoke_test valide la campagne en supposant le joueur "au niveau de la
## bataille qu'il affronte" - niveau 6 partout a la bataille 10 - sans jamais
## verifier que la campagne verse de quoi y arriver. Un calcul de coin de table
## dit que non, d'un facteur trois. Cette sonde tranche.
##
## LA METHODE. On rejoue la campagne dans l'ordre, en tenant la comptabilite
## reelle : recompenses de premiere victoire, ratio de replay, or des missions,
## couts de recrutement progressifs, couts d'amelioration, pertes definitives,
## garnison minimale, et les series avec leurs renforts. On ne recopie pas
## l'economie : on branche le VRAI GameState, sinon la sonde mesurerait sa
## propre arithmetique.
##
## LE "MINIMUM QUI PASSE". Chercher l'armee la moins chere qui gagne est
## combinatoire. On la remplace par une montee gloutonne dont LE COMBAT EST
## L'ORACLE : on tente la bataille avec l'etat courant ; si elle est perdue, on
## achete le PAS LE MOINS CHER disponible (une piece, ou un batiment monte d'un
## niveau) et on rejoue. Quand l'or manque, on rejoue une bataille deja gagnee
## et on compte ce farm.
##
## DEUX BIAIS, ecrits noir sur blanc plutot que caches :
##
##   1. Le glouton donne un MAJORANT du vrai plancher, pas l'optimum. Proche,
##      mais pas exact.
##   2. Les deux camps sont joues par la recherche a son niveau maximum. Le
##      plancher mesure est donc celui d'un JOUEUR PARFAIT : un humain perdra
##      plus de pieces et devra acheter davantage. Meme biais que promo_probe,
##      assume de la meme facon.
##
## Le TEMPS d'amelioration est compte a part : c'est un axe de rythme de
## seance, pas d'or, et melanger les deux ne dirait rien de bon.
##

## Garde-fou : au-dela, on declare le mur plutot que de farmer indefiniment.
const MAX_REPLAYS_PAR_BATAILLE := 60

## Garde-fou d'achats successifs pour une meme bataille.
const MAX_ACHATS_PAR_BATAILLE := 40

var _or_gagne_batailles: int = 0
var _or_gagne_missions: int = 0
var _or_gagne_replays: int = 0
var _or_depense: int = 0
var _replays_total: int = 0
var _secondes_amelioration: int = 0


func _ready() -> void:
	# Banc : recherche sans limite de temps, donc reproductible (cf.
	# BattleAI.budget_ms).
	BattleAI.budget_ms = 0
	Game.reset_progress()
	print("")
	print("=== SONDE ECONOMIQUE ===")
	print("  Politique : le minimum qui passe (montee gloutonne, le combat pour oracle).")
	print("  Les deux camps sont joues par la recherche au maximum : plancher OPTIMISTE.")
	print("")

	var mur := 0
	for battle_id in range(1, Balance.battle_count() + 1):
		if not _traverser(battle_id):
			mur = battle_id
			break

	print("")
	_bilan(mur)
	get_tree().quit(0)


# ------------------------------- LA CAMPAGNE ---------------------------------

## Fait passer une bataille au joueur, en achetant le strict necessaire et en
## farmant quand l'or manque. Retourne false si le mur est infranchissable.
func _traverser(battle_id: int) -> bool:
	var battle := Balance.battle(battle_id)
	var achats := 0
	var replays := 0
	var or_depart := Game.gold

	while true:
		var issue := _jouer_serie(battle_id)
		if issue["gagnee"]:
			_encaisser(battle_id, issue)
			print("  bataille %2d  %-20s  %s  charge %2d/%-2d  %2d essai(s), %2d replay(s)  or restant %5d" % [
				battle_id, String(battle["name"]), _niveaux(),
				int(issue["charge"]), Game.deploy_capacity(),
				achats + 1, replays, Game.gold])
			return true

		# Perdue : il faut monter en puissance. Quel est le pas le moins cher ?
		var pas := _pas_le_moins_cher()
		if pas.is_empty():
			print("  bataille %2d  %-20s  MUR : plus rien a acheter (tout au maximum)" % [
				battle_id, String(battle["name"])])
			return false

		# Pas les moyens : on rejoue une bataille deja gagnee.
		while Game.gold < int(pas["cout"]):
			if replays >= MAX_REPLAYS_PAR_BATAILLE:
				print("  bataille %2d  %-20s  MUR : %d replays n'ont pas suffi a payer %s (%d or)" % [
					battle_id, String(battle["name"]), replays,
					String(pas["libelle"]), int(pas["cout"])])
				return false
			if not _farmer():
				print("  bataille %2d  %-20s  MUR : aucune bataille rejouable" % [
					battle_id, String(battle["name"])])
				return false
			replays += 1

		_acheter(pas)
		achats += 1
		if achats >= MAX_ACHATS_PAR_BATAILLE:
			print("  bataille %2d  %-20s  MUR : %d achats sans jamais passer" % [
				battle_id, String(battle["name"]), achats])
			return false

	return false


## Rejoue la meilleure bataille deja gagnee pour faire de l'or. Retourne false
## s'il n'y en a aucune (donc au tout debut de la partie).
func _farmer() -> bool:
	var cible := 0
	for id in range(1, Balance.battle_count() + 1):
		if Game.is_battle_won(id):
			cible = id
	if cible == 0:
		return false

	var issue := _jouer_serie(cible)
	if not issue["gagnee"]:
		# Une bataille deja gagnee qu'on ne regagne pas : l'armee a trop fondu.
		# On laisse la garnison minimale faire son office au prochain tour.
		return true

	var gain := Game.reward_for(cible)
	_encaisser(cible, issue)
	_or_gagne_replays += gain
	_or_gagne_batailles -= gain
	_replays_total += 1
	return true


## Verse ce que la serie a rapporte et applique ses pertes, par le vrai
## GameState : recompense, deblocage, missions, garnison minimale.
func _encaisser(battle_id: int, issue: Dictionary) -> void:
	var avant := Game.gold
	Game.apply_losses(issue["pertes"])
	Game.record_battle(true, int(issue["pertes_total"]), int(issue["captures"]), int(issue["promotions"]))
	Game.win_battle(battle_id, Game.reward_for(battle_id))
	_or_gagne_batailles += Game.gold - avant
	_reclamer_les_missions()


func _reclamer_les_missions() -> void:
	for mission in Game.missions_visible():
		if Game.is_mission_complete(mission) and not Game.is_mission_claimed(String(mission["id"])):
			_or_gagne_missions += Game.claim_mission(String(mission["id"]))


# ------------------------------- LES ACHATS ----------------------------------

## Le pas de progression le moins cher : une piece recrutee, ou un batiment
## monte d'un niveau. Vide si tout est au maximum.
func _pas_le_moins_cher() -> Dictionary:
	var meilleur: Dictionary = {}

	for type in Balance.UNIT_TYPES:
		if not Game.is_building_unlocked(type) or Game.is_at_capacity(type):
			continue
		var cout := Game.recruit_cost(type)
		if meilleur.is_empty() or cout < int(meilleur["cout"]):
			meilleur = {"genre": "recrue", "type": type, "cout": cout,
				"libelle": "un %s" % Balance.unit_name(type)}

	var batiments: Array = [Balance.CASTLE]
	batiments.append_array(Balance.UNIT_TYPES)
	for type in batiments:
		if type != Balance.CASTLE and not Game.is_building_unlocked(type):
			continue
		if Game.is_max_level(type):
			continue
		var cout := Balance.upgrade_cost(type, Game.building_level(type) if type != Balance.CASTLE else Game.castle_level())
		if cout < 0:
			continue
		if meilleur.is_empty() or cout < int(meilleur["cout"]):
			meilleur = {"genre": "niveau", "type": type, "cout": cout,
				"libelle": "%s au niveau suivant" % Balance.building_name(type)}

	return meilleur


func _acheter(pas: Dictionary) -> void:
	var avant := Game.gold
	if String(pas["genre"]) == "recrue":
		Game.recruit(String(pas["type"]))
	else:
		var type := String(pas["type"])
		var niveau := Game.castle_level() if type == Balance.CASTLE else Game.building_level(type)
		_secondes_amelioration += maxi(0, Balance.upgrade_seconds(type, niveau))
		Game.start_upgrade(type)
		Game.force_finish_upgrade(type)
	_or_depense += avant - Game.gold
	_reclamer_les_missions()


# ------------------------------- LE COMBAT -----------------------------------

## Joue la serie entiere d'une bataille avec l'armee du village. Retourne
## l'issue et les pertes cumulees, SANS rien crediter : c'est _encaisser qui
## touche a l'economie.
func _jouer_serie(battle_id: int) -> Dictionary:
	var battle := Balance.battle(battle_id)
	var fights := Balance.battle_fights(battle)

	var effectif: Dictionary = {}
	for type in Balance.ARMY_TYPES:
		effectif[type] = Game.units_owned(type)

	var pertes: Dictionary = {}
	var captures := 0
	var promotions := 0
	var charge := 0

	for fight in range(1, fights + 1):
		var combat := _jouer_combat(battle, effectif)
		charge = maxi(charge, int(combat["charge"]))
		captures += int(combat["captures"])
		promotions += int(combat["promotions"])
		for type in combat["pertes"].keys():
			pertes[type] = int(pertes.get(type, 0)) + int(combat["pertes"][type])
			effectif[type] = maxi(0, int(effectif.get(type, 0)) - int(combat["pertes"][type]))

		if not combat["gagne"]:
			return {"gagnee": false, "pertes": pertes, "pertes_total": _total(pertes),
				"captures": captures, "promotions": promotions, "charge": charge}

		# Renforts entre deux combats : les moins chers d'abord.
		if fight < fights:
			_renforcer(effectif, pertes)

	return {"gagnee": true, "pertes": pertes, "pertes_total": _total(pertes),
		"captures": captures, "promotions": promotions, "charge": charge}


## Un combat. L'armee ennemie revient au complet ; le joueur pose ce qui lui
## reste, dans la limite de la charge du chateau.
func _jouer_combat(battle: Dictionary, effectif: Dictionary) -> Dictionary:
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = Balance.battle_ai_skill(battle)
	engine.auto_mode = true

	var level := int(battle["level"])
	var cells: Array = engine.grid.free_enemy_cells()
	var index := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[index])
			index += 1

	var pose := _poser(engine, effectif.duplicate())

	while not engine.finished:
		engine.step()

	var survivants: Dictionary = {}
	for unit in engine.living(BattleUnit.TEAM_PLAYER):
		survivants[unit.type] = int(survivants.get(unit.type, 0)) + 1

	var pertes: Dictionary = {}
	for type in pose["par_type"].keys():
		var perdu := int(pose["par_type"][type]) - int(survivants.get(type, 0))
		if perdu > 0:
			pertes[type] = perdu

	return {
		"gagne": engine.winner == BattleUnit.TEAM_PLAYER,
		"pertes": pertes,
		"charge": int(pose["charge"]),
		"captures": index - engine.living(BattleUnit.TEAM_ENEMY).size(),
		"promotions": 0,
	}


## Formation de reference : les types alternent (un mur de pions perd contre a
## peu pres tout), les pions devant. Identique a celle de smoke_test, pour que
## les deux bancs parlent de la meme armee.
func _poser(engine: BattleEngine, pool: Dictionary) -> Dictionary:
	var capacite := Game.deploy_capacity()
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
	var par_type: Dictionary = {}
	var poses := mini(ordre.size(), cells.size())
	for i in range(poses):
		var type := String(ordre[i])
		engine.add_unit(type, _niveau_de(type), BattleUnit.TEAM_PLAYER, cells[i])
		par_type[type] = int(par_type.get(type, 0)) + 1

	return {"par_type": par_type, "charge": poids}


func _tour_de_role(pool: Dictionary, curseur: int, epuises: Dictionary) -> String:
	var types: Array = Balance.ARMY_TYPES
	for offset in range(types.size()):
		var type: String = types[(curseur + offset) % types.size()]
		if epuises.has(type):
			continue
		if int(pool.get(type, 0)) > 0:
			return type
	return ""


func _niveau_de(type: String) -> int:
	if type == Balance.DAME:
		return Game.dame_level()
	return Game.building_level(type)


## Renforts d'entre-deux-combats : RUN_REINFORCE_WEIGHT de poids relève parmi
## les pertes, les moins cheres d'abord.
func _renforcer(effectif: Dictionary, pertes: Dictionary) -> void:
	var budget := Balance.RUN_REINFORCE_WEIGHT
	var types: Array = Balance.ARMY_TYPES.duplicate()
	types.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))
	for type in types:
		while budget >= Balance.deploy_weight(type) and int(pertes.get(type, 0)) > 0:
			budget -= Balance.deploy_weight(type)
			pertes[type] = int(pertes[type]) - 1
			effectif[type] = int(effectif.get(type, 0)) + 1


# ------------------------------- SORTIE --------------------------------------

func _total(d: Dictionary) -> int:
	var n := 0
	for v in d.values():
		n += int(v)
	return n


func _niveaux() -> String:
	var bouts: Array = ["Ch%d" % Game.castle_level()]
	for type in Balance.UNIT_TYPES:
		if Game.is_building_unlocked(type):
			bouts.append("%s%d" % [Balance.unit_letter(type), Game.building_level(type)])
		else:
			bouts.append("%s-" % Balance.unit_letter(type))
	return " ".join(bouts)


func _bilan(mur: int) -> void:
	var gagne := _or_gagne_batailles + _or_gagne_missions + _or_gagne_replays + Balance.STARTING_GOLD
	print("  ---------------------------------------------------------------")
	print("  Or de depart ................... %6d" % Balance.STARTING_GOLD)
	print("  Or des premieres victoires ..... %6d" % _or_gagne_batailles)
	print("  Or des missions ................ %6d" % _or_gagne_missions)
	print("  Or du farm (%d replays) ......... %6d" % [_replays_total, _or_gagne_replays])
	print("  ---------------------------------------------------------------")
	print("  TOTAL ENCAISSE ................. %6d" % gagne)
	print("  Depense en recrues/niveaux ..... %6d" % _or_depense)
	print("  Reste en poche ................. %6d" % Game.gold)
	print("")
	var heures := float(_secondes_amelioration) / 3600.0
	print("  Attente d'amelioration cumulee . %6d s  (%.1f h de temps reel)" % [
		_secondes_amelioration, heures])
	print("")
	if mur > 0:
		print("  VERDICT : MUR a la bataille %d. La campagne ne verse pas de quoi la franchir." % mur)
	elif _replays_total == 0:
		print("  VERDICT : la campagne se traverse SANS farmer une seule fois.")
	else:
		print("  VERDICT : campagne franchissable, mais au prix de %d replays." % _replays_total)
		print("            C'est %d combats joues en plus des %d de la campagne." % [
			_replays_total, Balance.battle_count()])
	print("")
	print("  Rappel des biais : glouton (majorant du plancher) et joueur parfait")
	print("  (recherche au maximum des deux cotes). Un humain aura besoin de PLUS.")
