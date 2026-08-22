extends RefCounted
##
## PILOTE DE BATAILLE - ce que le jeu ne fait plus lui-meme.
##
## Le jeu n'a plus aucun bouton qui joue a la place du joueur : ni formation
## automatique au placement, ni resolution automatique du combat. C'est une
## decision de fond - "c'est a moi de jouer" - et non un oubli.
##
## Les BANCS, eux, en ont toujours besoin : ils doivent peupler un plateau et
## mener une bataille a son terme sans personne devant l'ecran. Ce fichier porte
## donc ce qui a quitte l'interface, et il vit dans tools/ plutot que dans
## scenes/ : du code qui n'existe que pour les tests n'a rien a faire dans une
## scene de production, ou il finirait par etre rebranche "juste pour essayer".
##
## Le MOTEUR, lui, sait toujours jouer les deux camps (BattleEngine.auto_mode) :
## c'est une capacite du moteur, pas une commande offerte au joueur.
##
## Usage :
##   const Driver := preload("res://tools/battle_driver.gd")
##   Driver.auto_place(battle)
##   Driver.resolve(battle)


## Pose une armee sur l'ecran de bataille donne et retourne le nombre de pieces
## posees.
##
## Reprend l'alternance de l'ancien bouton AUTO : les types se relaient au lieu
## de vider la caserne la plus pleine (un mur de pions perd contre a peu pres
## tout), les pions passent devant, les pieces lourdes suivent une fois les
## lignes ouvertes. C'est la formation de reference sur laquelle sont calibres
## les budgets de charge de Balance.CASTLE_DATA.
static func auto_place(battle: Node) -> int:
	var capacity: int = Game.deploy_capacity()
	var weight := 0
	var order: Array = []
	# Types qui ne rentrent plus dans la charge restante : exclus des tours
	# suivants sans arreter la formation - un type plus leger peut encore
	# passer (il reste 2 de charge : la Tour a 5 non, un Pion a 1 oui).
	var exhausted: Dictionary = {}
	while true:
		var type := _pick(battle, order, exhausted)
		if type.is_empty():
			break
		var type_weight: int = Balance.deploy_weight(type)
		if weight + type_weight > capacity:
			exhausted[type] = true
			continue
		order.append(type)
		weight += type_weight

	order.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))

	var cells: Array = battle._engine.grid.free_player_cells()
	for i in range(mini(order.size(), cells.size())):
		var type: String = order[i]
		var unit: BattleUnit = battle._engine.add_unit(
			type, battle._unit_level(type), BattleUnit.TEAM_PLAYER, cells[i])
		battle._placed.append(unit)
		battle._remaining[type] = int(battle._remaining[type]) - 1

	battle._grid_view.queue_redraw()
	battle._refresh_placement()
	return battle._placed.size()


static func _pick(battle: Node, taken: Array, exhausted: Dictionary) -> String:
	var types: Array = battle._deployable_types()
	for offset in range(types.size()):
		var type: String = types[(taken.size() + offset) % types.size()]
		if exhausted.has(type):
			continue
		if int(battle._remaining[type]) - taken.count(type) > 0:
			return type
	return ""


## Mene le combat en cours a son terme, les deux camps joues par l'IA.
##
## `animate` decide si les coups passent par la VUE. A false, ils sont joues
## d'un bloc et la vue se contente d'un redessin : une bataille entiere se
## resout en quelques millisecondes. A true, chaque evenement est rejoue avec
## son animation, au prix du `ai_think_delay` et du temps de deplacement par
## coup - c'etait autrefois le role du selecteur de vitesse x1/x2/x4, qui a
## quitte le jeu avec le reste de ce qui jouait a la place du joueur.
##
## Le chemin RAPIDE est le defaut parce que c'est ce que veulent les bancs :
## ui_test ne demande qu'une bataille menee a son terme. On n'anime que le court
## passage qu'on veut photographier.
##
## `max_steps` borne le nombre de coups joues (0 = jusqu'a la fin). Sert a
## avancer de quelques coups pour photographier un combat en cours, avant de
## le terminer par un second appel, rapide.
##
## L'appel peut se faire sans `await` : sans animation, la fonction ne suspend
## jamais et s'execute d'un trait.
static func resolve(battle: Node, animate: bool = false, max_steps: int = 0) -> void:
	var engine: BattleEngine = battle._engine
	engine.auto_mode = true
	battle._busy = true
	battle._grid_view.draggable_team = -1

	var limit := int(Balance.COMBAT["max_activations"])
	if max_steps > 0:
		limit = mini(limit, max_steps)

	var guard := 0
	while battle._running and not engine.finished and guard < limit:
		if animate:
			await battle._play_events(engine.step())
		else:
			engine.step()
		guard += 1

	battle._grid_view.queue_redraw()
	battle._refresh_combat_status()

	if battle._running and engine.finished:
		battle._show_result()
