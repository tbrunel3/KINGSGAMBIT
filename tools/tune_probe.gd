extends Node
##
## SONDE DE REGLAGE - de combien de niveaux le joueur doit-il dominer ?
##
## Lancement :
##   godot --headless --path . tools/tune_probe.tscn
##
## LA QUESTION. L'avantage du joueur n'est plus fait de NOMBRE mais de QUALITE :
## moins de pieces, mieux equipees, face a un adversaire plus nombreux et plus
## fruste. Reste a savoir DE COMBIEN. Un ecart trop mince et la bataille est
## imperdable pour l'ennemi ; trop large et elle se gagne sans y penser.
##
## LA METHODE. Pour chaque bataille, on rejoue le meme combat en faisant varier
## le SEUL niveau de l'armee ennemie, le joueur restant a celui que la campagne
## lui prete (Balance.battle_player_level). On lit ou bascule l'issue, et a quel
## prix en pieces perdues.
##
## POURQUOI FAIRE VARIER L'ENNEMI ET NON LE JOUEUR. Les deux creusent le meme
## ecart, mais monter le joueur lui envoie la facture : chaque niveau se paie en
## or, et la sonde economique dit deja qu'il n'a pas les moyens des niveaux
## qu'on lui prete. Baisser l'ennemi ne coute rien a personne, et "plus fruste"
## est precisement le mot du cahier des charges.
##
## CE QUE LA SONDE NE DIT PAS. Les deux camps sont joues par la recherche : le
## resultat est celui d'un joueur PARFAIT. Une bataille qui se gagne ici avec
## zero perte se gagnera avec des pertes chez un humain ; une bataille perdue
## ici est perdue pour tout le monde. C'est donc un plancher, pas une promesse.
##

## Combien de niveaux en dessous du joueur on descend l'ennemi.
const ECARTS := [0, 1, 2]

## Batailles mesurees. Les premieres se gagnent sans discussion : les mesurer a
## chaque fois, c'est vingt minutes payees pour relire ce qu'on sait deja.
const BATAILLES := [7, 8, 9, 10]

## Formations essayees par configuration.
##
## POURQUOI PLUSIEURS. Le combat est deterministe - meme position, meme coup,
## toujours. On en avait conclu qu'un seul essai suffisait a prouver un
## resultat. C'est faux, et la sonde l'a montre : sur la bataille 10, baisser
## le SEUL niveau ennemi donnait NUL, NUL, PERDUE, gagnee. Baisser le niveau de
## l'adversaire faisait perdre le joueur.
##
## Deterministe ne veut pas dire representatif. Un coup different au troisieme
## tour envoie la partie ailleurs, et chaque case du tableau n'etait qu'UN
## tirage d'une fonction chaotique. On lit donc un TAUX sur plusieurs
## formations : c'est la seule chose qui distingue une bataille reellement
## gagnable d'un coup de chance reproductible.
const VARIANTES := 5


func _ready() -> void:
	# Banc : recherche sans limite de temps, donc reproductible (cf.
	# BattleAI.budget_ms).
	BattleAI.budget_ms = 0
	print("")
	print("=== SONDE DE REGLAGE : l'ecart de niveau ===")
	print("  Le joueur reste au niveau que la campagne lui prete ; seul l'ennemi bouge.")
	print("  Les deux camps sont joues par la recherche : resultat d'un joueur parfait.")
	print("")
	print("  %d formations par configuration : on lit un TAUX, pas un tirage." % VARIANTES)
	print("")
	print("  Bataille                   Joueur Ennemi ecart  armee variee     armee de pions")
	print("  ------------------------------------------------------------------------------")

	for battle_id in BATAILLES:
		var battle := Balance.battle(battle_id)
		var joueur := Balance.battle_player_level(battle)
		var actuel := int(battle["level"])
		for ecart in ECARTS:
			var ennemi := maxi(1, joueur - ecart)
			print("  %2d %-22s Nv.%d  Nv.%d %s %-3d   %-16s %s" % [
				battle_id, String(battle["name"]), joueur, ennemi,
				"*" if ennemi == actuel else " ", ecart,
				_serie(battle, joueur, ennemi, "variee"),
				_serie(battle, joueur, ennemi, "pions")])
		print("")

	print("  * = le niveau ennemi declare aujourd'hui dans Balance.CAMPAIGN")
	get_tree().quit(0)


## Une configuration, jouee sur VARIANTES formations : "4/5 -6" se lit quatre
## victoires sur cinq, six pieces perdues en moyenne quand elle passe.
func _serie(battle: Dictionary, joueur: int, ennemi: int, style: String) -> String:
	var gagnees := 0
	var nuls := 0
	var pertes := 0
	for variante in range(VARIANTES):
		var issue := _jouer(battle, joueur, ennemi, style, variante)
		if bool(issue["nul"]):
			nuls += 1
		elif bool(issue["gagne"]):
			gagnees += 1
			pertes += int(issue["pertes"])
	var moyenne := "" if gagnees == 0 else " -%.0f" % (float(pertes) / float(gagnees))
	var nul := "" if nuls == 0 else " (%d nul)" % nuls
	return "%d/%d%s%s" % [gagnees, VARIANTES, moyenne, nul]


## Un combat, joueur au niveau `joueur`, ennemi au niveau `ennemi`. Reprend
## exactement le placement de smoke_test : les deux bancs doivent parler de la
## meme armee, sinon leurs chiffres ne se comparent pas.
func _jouer(battle: Dictionary, joueur: int, ennemi: int, style: String,
		variante: int = 0) -> Dictionary:
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = Balance.battle_ai_skill(battle)

	var cells: Array = engine.grid.free_enemy_cells()
	var index := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, ennemi, BattleUnit.TEAM_ENEMY, cells[index])
			index += 1

	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		if style == "pions" and type != Balance.PION:
			pool[type] = 1
		else:
			pool[type] = Balance.capacity(type, joueur)

	var poses := _poser(engine, pool, Balance.deploy_capacity(joueur), joueur, variante)

	while not engine.finished:
		engine.step()

	var perdues := 0
	for count in engine.losses(BattleUnit.TEAM_PLAYER).values():
		perdues += int(count)

	return {
		"gagne": engine.winner == BattleUnit.TEAM_PLAYER,
		"nul": engine.is_draw(),
		"pertes": perdues,
		"poses": poses,
		"ennemis": index,
	}


func _poser(engine: BattleEngine, pool: Dictionary, capacite: int, niveau: int,
		variante: int = 0) -> int:
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

	# La variante fait tourner les cases sous une armee inchangee : meme
	# effectif, meme charge, rangement different. C'est ce que fait un joueur
	# qui repose son armee autrement, et c'est la seule chose qu'on veut voir
	# bouger d'un tirage a l'autre.
	var cells: Array = engine.grid.free_player_cells()
	var decalage := (variante * 3) % maxi(1, cells.size())
	var poses := mini(ordre.size(), cells.size())
	for i in range(poses):
		engine.add_unit(String(ordre[i]), niveau, BattleUnit.TEAM_PLAYER,
			cells[(i + decalage) % cells.size()])
	return poses


func _tour_de_role(pool: Dictionary, curseur: int, epuises: Dictionary) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(curseur + offset) % types.size()]
		if epuises.has(type):
			continue
		if int(pool[type]) > 0:
			return type
	return ""
