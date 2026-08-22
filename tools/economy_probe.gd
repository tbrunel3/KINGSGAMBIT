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
## LA POLITIQUE D'ACHAT. On tente la bataille avec l'etat courant ; si elle est
## perdue, on achete le prochain pas et on rejoue. Quand l'or manque, on rejoue
## une bataille deja gagnee et on compte ce farm.
##
## Le "prochain pas" suit une politique REALISTE - le chateau, puis les
## casernes, puis les recrues - et non "le moins cher d'abord" (cf.
## _pas_suivant, qui explique pourquoi cette premiere version mesurait autre
## chose que ce qu'on croyait).
##
## TROIS BIAIS, ecrits noir sur blanc plutot que caches :
##
##   1. La montee donne un MAJORANT du vrai plancher, pas l'optimum : un joueur
##      malin depense mieux.
##   2. Les deux camps sont joues par la recherche a son niveau maximum. Le
##      plancher mesure est donc celui d'un JOUEUR PARFAIT : un humain perdra
##      plus de pieces et devra acheter davantage. Meme biais que promo_probe,
##      assume de la meme facon.
##   3. Un replay PERDU ne coute rien ici, alors qu'il couterait des pieces dans
##      le jeu. Biais optimiste, donc du bon cote : si cette sonde annonce un
##      mur, le vrai jeu en a un plus tot.
##
## Le TEMPS d'amelioration est compte a part : c'est un axe de rythme de
## seance, pas d'or, et melanger les deux ne dirait rien de bon.
##

## AU-DELA DE CE NOMBRE DE REPLAYS POUR UNE SEULE BATAILLE, on declare le mur.
##
## Ce n'est pas un garde-fou technique mais un SEUIL DE DESIGN. Rejouer douze
## fois une bataille deja gagnee pour s'offrir le niveau suivant, ce n'est plus
## de la difficulte, c'est de la corvee - et un joueur qui ouvre le jeu sur son
## telephone ne la fera pas. Une campagne qui l'exige a echoue, meme si elle est
## theoriquement franchissable.
##
## Effet de bord bienvenu : la sonde s'arrete tot au lieu de simuler des heures
## de farm, ce qui la rend utilisable pour REGLER l'economie et pas seulement
## pour la constater.
const REPLAYS_TOLERABLES := 12

## Garde-fou d'achats successifs pour une meme bataille.
const MAX_ACHATS_PAR_BATAILLE := 40

var _or_gagne_batailles: int = 0
var _or_gagne_missions: int = 0
var _or_gagne_replays: int = 0
var _or_depense: int = 0
var _replays_total: int = 0
var _secondes_amelioration: int = 0

## Vrai si le joueur s'est retrouve sans or ET sans bataille regagnable.
var _impasse: bool = false


func _ready() -> void:
	# Banc : recherche sans limite de temps, donc reproductible (cf.
	# BattleAI.budget_ms).
	BattleAI.budget_ms = 0
	Game.reset_progress()
	print("")
	print("=== SONDE ECONOMIQUE ===")
	print("  Politique : le chateau d'abord, puis les casernes, puis les recrues -")
	print("              jusqu'au niveau que la campagne prete au joueur.")
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

		# Perdue : il faut monter en puissance. Quel est le prochain achat ?
		var pas := _pas_suivant(battle)
		if pas.is_empty():
			print("  bataille %2d  %-20s  MUR : plus rien a acheter (tout au maximum)" % [
				battle_id, String(battle["name"])])
			return false

		# Pas les moyens : on rejoue une bataille deja gagnee.
		while Game.gold < int(pas["cout"]):
			if replays >= REPLAYS_TOLERABLES:
				print("  bataille %2d  %-20s  CORVEE : %d replays sans pouvoir payer %s (%d or)" % [
					battle_id, String(battle["name"]), replays,
					String(pas["libelle"]), int(pas["cout"])])
				return false
			if not _farmer():
				print("  bataille %2d  %-20s  IMPASSE : aucune bataille deja gagnee ne se regagne" % [
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


## Rejoue une bataille deja gagnee pour faire de l'or. Retourne false quand le
## farm est IMPOSSIBLE - et c'est le cas le plus interessant de la sonde.
##
## On ne rejoue pas la derniere gagnee mais LA PLUS RENTABLE QU'ON REGAGNE.
## Un joueur ruine ne retourne pas se faire battre sur le terrain le plus dur :
## il redescend jusqu'a celui qu'il tient encore. La sonde fait pareil, en
## partant du haut.
##
## L'IMPASSE. Si aucune bataille deja gagnee ne se regagne, le joueur est
## bloque pour toujours : plus d'or pour acheter, plus d'armee pour en gagner,
## et la garnison minimale ne rend que trois pions. C'est un cul-de-sac dont le
## jeu ne sort pas, et il faut le voir ici plutot que chez un joueur.
func _farmer() -> bool:
	for cible in range(Balance.battle_count(), 0, -1):
		if not Game.is_battle_won(cible):
			continue
		if _tenter_replay(cible):
			return true
	_impasse = true
	return false


## Un replay : retourne vrai s'il a rapporte quelque chose.
func _tenter_replay(cible: int) -> bool:
	var issue := _jouer_serie(cible)
	if not issue["gagnee"]:
		return false

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

## Le prochain achat, selon une politique REALISTE.
##
## POURQUOI PAS "LE MOINS CHER D'ABORD". C'etait la premiere politique de cette
## sonde, et elle mesurait autre chose que ce qu'on croyait. Toujours acheter le
## pas le moins cher, c'est empiler des pions a 35 or et ne JAMAIS monter le
## chateau a 300 : la sonde traversait six batailles avec un chateau niveau 1,
## donc 16 de charge, pendant que le banc de bataille suppose un joueur au
## niveau de la campagne, donc 28 de charge. Les deux bancs ne parlaient pas du
## meme joueur, et le "mur" mesure etait celui d'un joueur qui joue mal.
##
## La politique d'ici est celle du banc de bataille, et c'est deliberé : les
## deux doivent parler du MEME joueur, sans quoi aucun des deux ne dit rien.
##
##   1. LE CHATEAU D'ABORD. Il porte la charge deployable et il ouvre les
##      casernes du Fou et de la Tour. Rien d'autre n'a cet effet de levier :
##      un chateau en retard plafonne l'armee entiere, quel que soit le nombre
##      de pieces achetees.
##   2. LES CASERNES ENSUITE, jusqu'au niveau que la campagne prete au joueur.
##      C'est la mobilite des pieces, donc leur portee au combat.
##   3. RECRUTER EN DERNIER, et seulement jusqu'a pouvoir remplir la charge.
##      Acheter au-dela, c'est payer des pieces qui resteront au village.
##
## Vide quand il n'y a plus rien a acheter : tout est au maximum, ou la charge
## est deja remplie et les niveaux atteints.
func _pas_suivant(battle: Dictionary) -> Dictionary:
	var cible := Balance.battle_player_level(battle)

	if Game.castle_level() < cible and not Game.is_max_level(Balance.CASTLE):
		return {"genre": "niveau", "type": Balance.CASTLE,
			"cout": Balance.upgrade_cost(Balance.CASTLE, Game.castle_level()),
			"libelle": "le Chateau au niveau %d" % (Game.castle_level() + 1)}

	for type in Balance.UNIT_TYPES:
		if not Game.is_building_unlocked(type) or Game.is_max_level(type):
			continue
		if Game.building_level(type) < cible:
			return {"genre": "niveau", "type": type,
				"cout": Balance.upgrade_cost(type, Game.building_level(type)),
				"libelle": "%s au niveau %d" % [
					Balance.building_name(type), Game.building_level(type) + 1]}

	# Charge : le poids de l'armee entiere, compare a ce que le chateau porte.
	# On recrute le type dont on a le MOINS, pour garder l'armee variee - un mur
	# de pions perd contre a peu pres tout, et c'est la formation de reference
	# qui alterne les types.
	if _poids_de_l_armee() < Game.deploy_capacity():
		var choisi := ""
		for type in Balance.UNIT_TYPES:
			if not Game.is_building_unlocked(type) or Game.is_at_capacity(type):
				continue
			if choisi.is_empty() or Game.units_owned(type) < Game.units_owned(choisi):
				choisi = type
		if not choisi.is_empty():
			return {"genre": "recrue", "type": choisi, "cout": Game.recruit_cost(choisi),
				"libelle": "un %s" % Balance.unit_name(choisi)}

	# Plus rien d'utile a acheter au niveau vise : on monte au-dela plutot que
	# de declarer le mur, car une bataille peut demander mieux que prevu.
	var meilleur: Dictionary = {}
	var batiments: Array = [Balance.CASTLE]
	batiments.append_array(Balance.UNIT_TYPES)
	for type in batiments:
		if type != Balance.CASTLE and not Game.is_building_unlocked(type):
			continue
		if Game.is_max_level(type):
			continue
		var niveau: int = Game.castle_level() if type == Balance.CASTLE else Game.building_level(type)
		var cout := Balance.upgrade_cost(type, niveau)
		if cout < 0:
			continue
		if meilleur.is_empty() or cout < int(meilleur["cout"]):
			meilleur = {"genre": "niveau", "type": type, "cout": cout,
				"libelle": "%s au-dela du niveau prevu" % Balance.building_name(type)}
	return meilleur


## Poids total de l'armee du village, au bareme du deploiement. C'est ce qui se
## compare a Game.deploy_capacity() : les deux parlent de charge, pas d'effectif.
func _poids_de_l_armee() -> int:
	var poids := 0
	for type in Balance.ARMY_TYPES:
		poids += Game.units_owned(type) * Balance.deploy_weight(type)
	return poids


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
	if _impasse:
		print("  VERDICT : IMPASSE a la bataille %d. Le joueur n'a plus d'or, et plus" % mur)
		print("            aucune bataille qu'il regagne pour en refaire. Le jeu ne")
		print("            propose aucune sortie : c'est un cul-de-sac, pas une")
		print("            difficulte.")
	elif mur > 0:
		print("  VERDICT : CORVEE a la bataille %d. La campagne est franchissable, mais" % mur)
		print("            seulement en rejouant plus de %d fois une bataille deja" % REPLAYS_TOLERABLES)
		print("            gagnee. Ce n'est pas de la difficulte.")
	elif _replays_total == 0:
		print("  VERDICT : la campagne se traverse SANS farmer une seule fois.")
	else:
		print("  VERDICT : campagne franchissable, mais au prix de %d replays." % _replays_total)
		print("            C'est %d combats joues en plus des %d de la campagne." % [
			_replays_total, Balance.battle_count()])
	print("")
	print("  Rappel des biais : glouton (majorant du plancher) et joueur parfait")
	print("  (recherche au maximum des deux cotes). Un humain aura besoin de PLUS.")
