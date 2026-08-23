extends Node
##
## BANC DE TEST - verifie la coherence des donnees et joue les 10 batailles.
##
## Lancement :
##   godot --headless --path . tools/smoke_test.tscn
##
## Ne fait pas partie du jeu : c'est un outil de developpement. Il sert surtout
## a detecter les combats qui ne se terminent pas, les batailles impossibles a
## peupler, et les tableaux de Balance mal dimensionnes apres un reglage.
##

var _failures: int = 0
var _promotions_seen: int = 0

## Sections qui sont allees jusqu'au bout (cf. _done).
var _finished: Array = []

## Ce que le banc DOIT avoir execute. Une section absente de _finished a ete
## interrompue en cours de route.
const SECTIONS := [
	"donnees", "missions", "sauvegarde", "formation", "menaces", "pertes",
	"regles", "serie", "batailles", "ecrans", "boucle", "boutique",
]


## Note qu'une section est allee jusqu'au bout. A appeler en DERNIERE
## instruction de chaque _check_*.
##
## Une erreur d'execution GDScript (appel d'une fonction inexistante, index
## hors bornes...) ne fait pas planter le jeu : elle interrompt la fonction
## fautive et rend la main a l'appelant, qui continue comme si de rien n'etait.
## Sans ce garde-fou, une verification qui plante etait donc simplement SAUTEE
## et le banc concluait "tout est passe" avec un code de sortie 0 - un banc qui
## ment est pire que pas de banc du tout.
##
## La sentinelle doit etre DANS la section : un appel enveloppant ne suffit pas,
## il reprend la main apres l'erreur et noterait la section comme terminee.
func _done(name: String) -> void:
	_finished.append(name)


func _ready() -> void:
	# Banc : recherche sans limite de temps, donc reproductible (cf.
	# BattleAI.budget_ms).
	BattleAI.budget_ms = 0
	print("=== KING'S GAMBIT - banc de test ===")
	_check_balance()
	_check_missions()
	_check_save()
	_check_formation()
	_check_threats()
	_check_losses()
	_check_rules()
	_check_run()
	_check_endgame()
	_check_shop()
	_play_all_battles()
	await _check_scenes()
	_check_campaign_loop()

	for name in SECTIONS:
		if not _finished.has(name):
			_fail("la section '%s' ne s'est pas terminee - erreur de script en cours de route" % name)

	print("")
	if _failures == 0:
		print("RESULTAT : tout est passe.")
	else:
		print("RESULTAT : %d probleme(s) detecte(s)." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _fail(message: String) -> void:
	_failures += 1
	print("  ECHEC : %s" % message)


# ------------------------------- SERIE DE COMBATS ----------------------------

## La serie (cf. CampaignRun) : usure entre deux combats, renforts, et surtout
## le fait que RIEN n'atteint l'armee du village avant la fin.
func _check_run() -> void:
	print("
[3b] Serie de combats")
	Game.reset_progress()

	# On teste la serie sur la premiere bataille qui EN EST une : les premieres
	# se jouent volontairement en un seul combat (cf. Balance, "fights").
	var series_id := 0
	for id in range(1, Balance.battle_count() + 1):
		if Balance.battle_fights(Balance.battle(id)) > 1:
			series_id = id
			break
	if series_id == 0:
		_fail("aucune bataille ne se joue en serie")
		return

	var battle := Balance.battle(series_id)
	var fights := Balance.battle_fights(battle)

	var pions_before := Game.units_owned(Balance.PION)
	var gold_before := Game.gold
	var run := Game.begin_run(series_id)

	if int(run.roster.get(Balance.PION, 0)) != pions_before:
		_fail("la serie doit partir avec l'armee du village au complet")

	# Premier combat gagne, deux pions perdus.
	run.record_victory({Balance.PION: 2}, 3, 0, 0, 90)
	if int(run.roster.get(Balance.PION, 0)) != pions_before - 2:
		_fail("les pertes doivent sortir de l'effectif de la serie")
	if Game.units_owned(Balance.PION) != pions_before:
		_fail("les pertes ne doivent PAS toucher le village avant la fin de la serie")
	if Game.gold != gold_before:
		_fail("l'or promis ne doit etre verse qu'a la fin de la serie")

	# Renforts : deux points de poids, donc deux pions releves.
	var recovered := run.advance(Balance.RUN_REINFORCE_WEIGHT)
	if run.fight != 2:
		_fail("advance() doit passer au combat suivant")
	if int(recovered.get(Balance.PION, 0)) != 2:
		_fail("deux pions devraient se relever entre deux combats")
	if int(run.losses.get(Balance.PION, 0)) != 0:
		_fail("un pion releve n'est plus une perte")

	# Une piece lourde ne se releve pas : elle pese plus que le budget.
	run.record_victory({Balance.TOUR: 1}, 2, 0, 0, 90)
	var heavy := run.advance(Balance.RUN_REINFORCE_WEIGHT)
	if heavy.has(Balance.TOUR):
		_fail("une tour ne devrait pas se relever entre deux combats")

	# Aller-retour par la sauvegarde : une serie doit survivre a la fermeture.
	Game.save_run(run)
	var reloaded := Game.current_run(series_id)
	if reloaded == null or reloaded.fight != run.fight or reloaded.reward != run.reward:
		_fail("la serie ne se relit pas correctement depuis la sauvegarde")
	elif int(reloaded.roster.get(Balance.PION, 0)) != int(run.roster.get(Balance.PION, 0)):
		_fail("l'effectif de la serie ne se relit pas correctement")
	if Game.current_run(series_id + 1) != null:
		_fail("une serie ouverte sur une bataille ne doit pas valoir pour une autre")

	# Cloture : c'est la, et seulement la, que tout tombe.
	var promised := run.reward
	Game.finish_run(run, true)
	if Game.gold != gold_before + promised:
		_fail("la victoire de la serie doit verser l'or promis (%d au lieu de %d)" % [
			Game.gold - gold_before, promised])
	if Game.units_owned(Balance.TOUR) != maxi(0, _tours_at_start() - 1):
		_fail("la tour perdue doit quitter l'armee a la fin de la serie")
	if not Game.is_battle_won(series_id):
		_fail("la serie gagnee doit marquer la bataille comme gagnee")
	if Game.current_run() != null:
		_fail("une serie finie doit etre effacee")

	# Serie perdue : la consolation seulement, et la bataille reste a faire.
	Game.reset_progress()
	gold_before = Game.gold
	var lost := Game.begin_run(2)
	lost.record_victory({}, 3, 0, 0, 120)
	lost.advance(Balance.RUN_REINFORCE_WEIGHT)
	lost.record_defeat({Balance.PION: 1})
	Game.finish_run(lost, false)
	var consolation := int(round(120.0 * Balance.DEFEAT_CONSOLATION_RATIO))
	if Game.gold != gold_before + consolation:
		_fail("une serie perdue ne doit rapporter que la consolation")
	if Game.is_battle_won(2):
		_fail("une serie perdue ne doit pas debloquer la bataille")

	# NUL : la serie continue, mais ce combat-la n'a rien paye.
	Game.reset_progress()
	var drawn := Game.begin_run(3)
	drawn.record_draw({Balance.PION: 1}, 2, 0, 0)
	if drawn.reward != 0:
		_fail("un combat nul ne doit rien rapporter")
	if int(drawn.losses.get(Balance.PION, 0)) != 1:
		_fail("un combat nul laisse quand meme ses morts sur le terrain")
	drawn.advance(Balance.RUN_REINFORCE_WEIGHT)
	if drawn.fight != 2:
		_fail("un combat nul ne doit pas rompre la serie")

	# DAME faite en cours de serie : elle reste en ligne, et si elle tombe
	# c'est le PION qu'elle etait qui manque au village, pas une Dame.
	Game.reset_progress()
	var crowned := Game.begin_run(1)
	var pions := int(crowned.roster.get(Balance.PION, 0))
	crowned.record_victory({}, 3, 1, 1, 90)
	if int(crowned.roster.get(Balance.DAME, 0)) != 1:
		_fail("une Dame promue doit rejoindre l'effectif de la serie")
	if int(crowned.roster.get(Balance.PION, 0)) != pions - 1:
		_fail("le pion promu doit quitter l'effectif")
	if crowned.dames_made != 1:
		_fail("la Dame faite doit etre comptee")

	crowned.record_defeat({Balance.DAME: 1})
	if crowned.dames_made != 0:
		_fail("une Dame faite puis tombee ne doit plus etre comptee")
	if int(crowned.losses.get(Balance.DAME, 0)) != 0:
		_fail("une Dame faite en serie ne coute pas une Dame au village")
	if int(crowned.losses.get(Balance.PION, 0)) != 1:
		_fail("une Dame faite puis tombee coute le pion qu'elle etait")

	# ----- La COMPOSITION dans la serie -----
	#
	#  Regle choisie : elle survit a la serie et se REDUIT des pertes - on ne
	#  la refait pas entre deux combats. Mais les renforts doivent y rentrer,
	#  sinon une piece relevee serait vivante et impossible a poser.
	Game.reset_progress()
	var capacity := Game.deploy_capacity()
	var composed := Game.begin_run(series_id)
	var stock := int(composed.roster.get(Balance.PION, 0))

	if composed.has_lineup():
		_fail("sans composition memorisee, la serie doit s'ouvrir sans composition")
	if int(composed.deployable().get(Balance.PION, 0)) != stock:
		_fail("sans composition, le placement doit proposer l'effectif entier")

	# Le joueur en engage trois sur les huit qu'il possede.
	composed.set_lineup({Balance.PION: 3}, capacity)
	if int(composed.deployable().get(Balance.PION, 0)) != 3:
		_fail("le placement ne doit proposer que les pieces composees")
	if composed.reserve(Balance.PION) != stock - 3:
		_fail("le reste doit demeurer en caserne")
	if composed.lineup_weight() != 3 * Balance.deploy_weight(Balance.PION):
		_fail("la charge composee doit compter des POIDS, pas des pieces")

	# Deux tombent au premier combat : la composition les perd.
	composed.record_victory({Balance.PION: 2}, 3, 0, 0, 90)
	if int(composed.lineup.get(Balance.PION, 0)) != 1:
		_fail("les pertes doivent sortir de la composition, pas seulement du roster")

	# Puis se relevent : ils DOIVENT revenir dans la composition.
	var back := composed.advance(Balance.RUN_REINFORCE_WEIGHT, capacity)
	if int(back.get(Balance.PION, 0)) != 2:
		_fail("deux pions devraient se relever entre deux combats")
	if int(composed.lineup.get(Balance.PION, 0)) != 3:
		_fail("un renfort releve doit redevenir posable, donc rentrer dans la composition")

	# Une composition trop lourde est ramenee a la charge, pas refusee.
	var greedy := CampaignRun.new()
	greedy.roster = {Balance.PION: 999}
	greedy.set_lineup({Balance.PION: 999}, capacity)
	if greedy.lineup_weight() != capacity:
		_fail("la charge doit borner la composition (%d au lieu de %d)" % [
			greedy.lineup_weight(), capacity])

	Game.reset_progress()
	print("  usure, renforts, nul, Dame de serie, sauvegarde, cloture : OK")
	print("  composition : bornee par la charge, reduite des pertes, ouverte aux renforts")
	_done("serie")


func _tours_at_start() -> int:
	return int(Balance.STARTING_UNITS.get(Balance.TOUR, 0))


# ------------------------------- DONNEES -------------------------------------

func _check_balance() -> void:
	print("\n[1] Coherence des donnees")

	var levels := Balance.MAX_LEVEL
	for type in Balance.UNIT_TYPES:
		var data: Dictionary = Balance.UNITS[type]
		if data["capacity"].size() != levels:
			_fail("%s : capacity a %d entrees pour %d niveaux" % [type, data["capacity"].size(), levels])
		if data["upgrade_cost"].size() != levels - 1:
			_fail("%s : upgrade_cost devrait avoir %d entrees" % [type, levels - 1])
		if data["upgrade_seconds"].size() != levels - 1:
			_fail("%s : upgrade_seconds devrait avoir %d entrees" % [type, levels - 1])

		# Chaque piece doit savoir bouger a tous les niveaux.
		for level in range(1, levels + 1):
			var reach := Balance.move_range(type, level) + Balance.jump_offsets(type, level).size()
			if reach <= 0:
				_fail("%s niveau %d : aucune mobilite definie" % [type, level])

		# La mobilite ne doit jamais reculer d'un niveau au suivant.
		for level in range(2, levels + 1):
			if Balance.move_range(type, level) < Balance.move_range(type, level - 1):
				_fail("%s : la portee baisse au niveau %d" % [type, level])

	if Balance.CASTLE_DATA["deploy_capacity"].size() != levels:
		_fail("chateau : deploy_capacity a %d entrees pour %d niveaux" % [
			Balance.CASTLE_DATA["deploy_capacity"].size(), levels])

	# La Dame n'est pas recrutable mais doit exister pour la promotion.
	if not Balance.UNITS.has(Balance.DAME):
		_fail("la Dame est absente de Balance.UNITS")
	if Balance.UNIT_TYPES.has(Balance.DAME):
		_fail("la Dame ne doit pas etre recrutable")

	# Le pion doit rester disponible des le depart : sans lui, aucune armee
	# n'est possible avant le premier niveau de chateau.
	if Balance.is_unlockable(Balance.PION):
		_fail("le pion ne devrait pas avoir de seuil de deblocage")
	# Le cavalier accompagne les pions des le depart : seuls le Cloitre et le
	# Donjon restent a debloquer au niveau de chateau.
	if Balance.is_unlockable(Balance.CAVALIER):
		_fail("les ecuries ne devraient plus avoir de seuil de deblocage")
	for type in [Balance.FOU, Balance.TOUR]:
		var required := Balance.unlock_castle_level(type)
		if required < 2 or required > Balance.max_level(Balance.CASTLE):
			_fail("%s : seuil de deblocage chateau incoherent (%d)" % [type, required])

	# L'ouverture du pion : une case au niveau 1, le double pas ensuite.
	if Balance.first_move_range(Balance.PION, 1) != Balance.move_range(Balance.PION, 1):
		_fail("le pion niveau 1 a deja une ouverture allongee")
	if Balance.first_move_range(Balance.PION, 2) < 2:
		_fail("le pion niveau 2 n'a pas gagne son double pas d'ouverture")
	for level in range(2, levels + 1):
		if Balance.first_move_range(Balance.PION, level) < Balance.first_move_range(Balance.PION, level - 1):
			_fail("l'ouverture du pion recule au niveau %d" % level)
		if Balance.first_move_range(Balance.PION, level) < Balance.move_range(Balance.PION, level):
			_fail("le pion niveau %d ouvre moins loin qu'il n'avance" % level)

	# La Dame doit rester la piece la plus CHERE pour l'IA, tout en restant
	# posable : son poids de deploiement ne peut pas depasser la charge d'un
	# chateau niveau 1, sinon la recompense d'une promotion est injouable.
	if Balance.unit_value(Balance.DAME) <= Balance.unit_value(Balance.TOUR):
		_fail("la Dame ne vaut pas plus qu'une Tour aux yeux de l'IA")
	if Balance.deploy_weight(Balance.DAME) > Balance.deploy_capacity(1):
		_fail("la Dame ne rentre pas dans la charge d'un chateau niveau 1")

	# Le niveau de jeu de l'IA doit monter, jamais redescendre.
	var previous_skill := -1
	for battle in Balance.CAMPAIGN:
		var skill := Balance.battle_ai_skill(battle)
		if skill < Balance.AI_NOVICE or skill > Balance.AI_EXPERT:
			_fail("bataille %d : niveau d'IA inconnu (%d)" % [int(battle["id"]), skill])
		if skill < previous_skill:
			_fail("bataille %d : l'IA joue moins bien que la precedente" % int(battle["id"]))
		previous_skill = skill

	var min_rows: int = Balance.DEPLOY_ROWS * 2 + 1
	for battle in Balance.CAMPAIGN:
		var cols := int(battle["cols"])
		var rows := int(battle["rows"])
		if rows < min_rows:
			_fail("bataille %d : %d rangees, minimum %d" % [int(battle["id"]), rows, min_rows])

		var enemy_count := 0
		for type in battle["enemies"].keys():
			enemy_count += int(battle["enemies"][type])
		if enemy_count > cols * Balance.DEPLOY_ROWS:
			_fail("bataille %d : %d ennemis pour %d cases" % [
				int(battle["id"]), enemy_count, cols * Balance.DEPLOY_ROWS])

	print("  %d pieces sur %d niveaux, %d batailles verifiees" % [
		Balance.UNIT_TYPES.size(), levels, Balance.battle_count()])
	_done("donnees")


# ------------------------------- MISSIONS ------------------------------------

## Les missions guident tout le debut du jeu : une chaine cassee (mission qui
## exige une mission inexistante, ou boucle de dependances) laisserait le
## joueur sans objectif, sans que rien ne plante.
func _check_missions() -> void:
	print("
[2] Missions")

	var ids: Dictionary = {}
	for mission in Balance.MISSIONS:
		var id := String(mission["id"])
		if ids.has(id):
			_fail("deux missions portent l'identifiant %s" % id)
		ids[id] = true
		if int(mission["target"]) <= 0:
			_fail("mission %s : objectif nul" % id)
		if int(mission["gold"]) <= 0:
			_fail("mission %s : aucune recompense" % id)

	# Chaque prerequis doit exister ET etre declare AVANT : sans cet ordre,
	# une mission pourrait n'apparaitre jamais.
	var seen: Dictionary = {}
	for mission in Balance.MISSIONS:
		for required in mission.get("requires", []):
			var key := String(required)
			if not ids.has(key):
				_fail("mission %s exige %s, qui n'existe pas" % [String(mission["id"]), key])
			elif not seen.has(key):
				_fail("mission %s exige %s, declaree apres elle" % [String(mission["id"]), key])
		seen[String(mission["id"])] = true

	Game.reset_progress()

	# Au demarrage, une seule mission doit etre visible : celle qui n'exige
	# rien. Un mur d'objectifs au premier lancement, c'est l'inverse du but.
	var visible := Game.missions_visible()
	if visible.size() != 1:
		_fail("%d missions visibles au premier lancement, une seule attendue" % visible.size())
	if Game.claimable_missions() != 0:
		_fail("une mission est deja reclamable avant d'avoir joue")

	# Gagner une bataille termine la premiere mission, la reclamer paie et
	# devoile la suivante.
	Game.record_battle(true, 0, 4, 0)
	if Game.claimable_missions() != 1:
		_fail("la premiere mission n'est pas reclamable apres une victoire")

	var first := String(Balance.MISSIONS[0]["id"])
	var gold_before := Game.gold
	var reward := Game.claim_mission(first)
	if reward != int(Balance.MISSIONS[0]["gold"]):
		_fail("la recompense versee (%d) ne correspond pas a la mission" % reward)
	if Game.gold != gold_before + reward:
		_fail("l'or de la mission n'a pas ete credite")
	if Game.claim_mission(first) != 0:
		_fail("une mission deja reclamee paie une seconde fois")
	if Game.missions_visible().is_empty():
		_fail("aucune mission ne prend la suite de la premiere")

	# Une victoire sans perte compte aussi comme une victoire tout court.
	if Game.mission_progress("flawless_wins") != 1:
		_fail("la victoire sans perte n'a pas ete comptee")
	if Game.mission_progress("captures") != 4:
		_fail("les captures ne sont pas comptees")

	Game.reset_progress()
	if not Game.missions_visible().is_empty() and Game.is_mission_claimed(first):
		_fail("la remise a zero n'efface pas les missions reclamees")

	print("  chaine de deverrouillage, progression, reclamation : OK")
	_done("missions")


# ------------------------------- SAUVEGARDE ----------------------------------

func _check_save() -> void:
	print("\n[2] Sauvegarde et economie")

	Game.reset_progress()
	if Game.gold != Balance.STARTING_GOLD:
		_fail("or de depart incorrect : %d" % Game.gold)

	var before := Game.units_owned(Balance.PION)
	var cost := Game.recruit_cost(Balance.PION)
	if not Game.recruit(Balance.PION):
		_fail("recrutement d'un pion refuse alors que l'or suffit")
	if Game.units_owned(Balance.PION) != before + 1:
		_fail("le pion recrute n'apparait pas")
	if Game.gold != Balance.STARTING_GOLD - cost:
		_fail("l'or n'a pas ete debite correctement")

	Game.add_gold(50000)

	# La campagne doit offrir une Dame au moins une fois : sans ca, tout le
	# systeme du Chateau Royal peut rester eteint une partie entiere.
	var dames_offered := 0
	for battle in Balance.CAMPAIGN:
		dames_offered += Balance.battle_dame_reward(battle)
	if dames_offered <= 0:
		_fail("aucune bataille de la campagne n'offre de Dame")

	# Le donjon n'existe pas au depart : il apparait seul quand le chateau
	# atteint le niveau requis (Balance.UNLOCK_CASTLE_LEVEL), sans achat.
	if Game.is_building_unlocked(Balance.TOUR):
		_fail("le donjon est deja construit au depart, il ne devrait pas l'etre")
	if Game.start_upgrade(Balance.TOUR):
		_fail("amelioration d'un batiment non construit acceptee")
	if Game.recruit(Balance.TOUR):
		_fail("recrutement dans un batiment non construit accepte")

	while Game.castle_level() < Balance.unlock_castle_level(Balance.TOUR):
		Game.start_upgrade(Balance.CASTLE)
		Game.force_finish_upgrade(Balance.CASTLE)

	if not Game.is_building_unlocked(Balance.TOUR):
		_fail("le donjon n'apparait pas au niveau de chateau requis")
	if Game.building_level(Balance.TOUR) != 1:
		_fail("le donjon apparu ne demarre pas au niveau 1")

	if not Game.start_upgrade(Balance.TOUR):
		_fail("amelioration du donjon refusee")
	if Game.upgrade_remaining(Balance.TOUR) <= 0:
		_fail("le compte a rebours d'amelioration est deja fini")
	Game.force_finish_upgrade(Balance.TOUR)
	if Game.building_level(Balance.TOUR) != 2:
		_fail("le donjon n'est pas passe niveau 2")

	Game.reset_progress()
	print("  or, recrutement, amelioration : OK")
	_done("sauvegarde")


# ------------------------------- FORMATION MEMORISEE -------------------------

## DERNIERE FORMATION - le placement que le joueur a valide est retenu par
## bataille, et lui est repropose la fois suivante.
##
## Remplace l'ancien bouton AUTO du placement, qui rangeait l'armee a la place
## du joueur : ici c'est SA decision qu'on lui rend, pas celle de l'ordinateur.
## Sans ce filet, une serie de trois combats demande de reposer onze pieces une
## par une, trois fois de suite.
func _check_formation() -> void:
	print("\n[2b] Formation memorisee")
	Game.reset_progress()

	if Game.has_remembered_formation(1):
		_fail("une formation est memorisee alors qu'aucune bataille n'a ete jouee")
	if not Game.remembered_formation(1).is_empty():
		_fail("la formation d'une bataille jamais jouee doit etre vide")

	var formation := [
		[Balance.PION, 1, 4],
		[Balance.PION, 2, 4],
		[Balance.CAVALIER, 0, 5],
	]
	Game.remember_formation(1, formation)

	if not Game.has_remembered_formation(1):
		_fail("la formation validee n'a pas ete retenue")

	var read: Array = Game.remembered_formation(1)
	if read.size() != 3:
		_fail("la formation relue compte %d pieces au lieu de 3" % read.size())
	elif String(read[2][0]) != Balance.CAVALIER or int(read[2][1]) != 0 or int(read[2][2]) != 5:
		_fail("la formation relue ne correspond pas a celle qui a ete posee")

	# Chaque bataille garde la sienne : revenir sur un terrain ne doit pas y
	# reposer l'armee d'un autre.
	if Game.has_remembered_formation(2):
		_fail("la formation de la bataille 1 fuit sur la bataille 2")

	# Aller-retour par le disque. Le JSON rend TOUT flottant : une case relue
	# "1.0" n'est pas une case, et la formation se reposerait de travers ou pas
	# du tout. C'est le meme piege que pour l'or et les niveaux (cf.
	# GameState._normalize).
	Game._load()
	var stored: Array = Game.remembered_formation(1)
	if stored.size() != 3:
		_fail("la formation ne survit pas a la relecture du disque (%d pieces)" % stored.size())
	elif typeof(stored[0][1]) != TYPE_INT or typeof(stored[0][2]) != TYPE_INT:
		_fail("les coordonnees relues ne sont pas des entiers mais des %s" % [
			type_string(typeof(stored[0][1]))])
	elif String(stored[0][0]) != Balance.PION or int(stored[0][1]) != 1 or int(stored[0][2]) != 4:
		_fail("la formation relue depuis le disque ne correspond pas a celle qui a ete posee")

	# CE QUI RESTE JOUABLE. Une formation memorisee vaut pour une armee qui a
	# fondu depuis - c'est meme le cas courant, puisque le bouton sert surtout
	# entre deux combats d'une serie, ou l'usure a deja mordu. Les pieces qu'on
	# n'a plus sont sautees, les autres gardent leur case.
	Game.remember_formation(4, [
		[Balance.PION, 0, 5],
		[Balance.TOUR, 1, 5],
		[Balance.PION, 2, 5],
		[Balance.PION, 3, 5],
	])

	var available := {Balance.PION: 2, Balance.TOUR: 1}
	var playable: Array = Game.playable_formation(4, available)
	if playable.size() != 3:
		_fail("il reste 2 pions et 1 tour : la formation jouable devrait compter 3 pieces, pas %d" % playable.size())
	elif String(playable[2][0]) != Balance.PION or int(playable[2][1]) != 2:
		_fail("les pieces gardees doivent conserver leur case d'origine, dans l'ordre")

	# L'effectif passe en argument ne doit pas etre consomme au passage : c'est
	# celui de l'ecran de placement, qui s'en sert encore apres.
	if int(available.get(Balance.PION, 0)) != 2:
		_fail("playable_formation a vide l'effectif qu'on lui a passe en lecture")

	# Un type entierement disparu est saute sans emporter le reste.
	var without_tour: Array = Game.playable_formation(4, {Balance.PION: 4})
	if without_tour.size() != 3:
		_fail("sans tour, les 3 pions de la formation devraient rester (%d gardes)" % without_tour.size())
	for piece in without_tour:
		if String(piece[0]) == Balance.TOUR:
			_fail("une tour est reposee alors que le joueur n'en a plus")

	if not Game.playable_formation(4, {}).is_empty():
		_fail("sans une seule piece disponible, rien ne doit etre repose")

	Game.reset_progress()
	if Game.has_remembered_formation(1):
		_fail("la remise a zero laisse une formation derriere elle")

	print("  memorisation, relecture, cloisonnement, effectif fondu : OK")
	_done("formation")


# ------------------------------- MENACES -------------------------------------

## LE LISERE DE MENACE. Dans un jeu sans points de vie, ou une capture est une
## mort definitive, toute la tension tient a VOIR la piece qui attaque. Le jeu
## allumait les coups du joueur et ne lui disait jamais ce que l'adversaire
## pouvait prendre au coup suivant : le danger existait sans etre visible.
##
## Le moteur sait deja repondre (MovementRules.is_cell_threatened, dont vit
## l'IA depuis toujours) ; il ne le disait simplement a personne.
func _check_threats() -> void:
	print("\n[2c] Pieces menacees")

	# Plateau nu, pieces posees a la main : le seul moyen d'avoir une menace
	# dont on connait la reponse a l'avance.
	var engine := BattleEngine.new(5, 6)

	# Tour ennemie en (0,0), portee 2 en ligne : elle tient (0,1) et (0,2).
	engine.add_unit(Balance.TOUR, 1, BattleUnit.TEAM_ENEMY, Vector2i(0, 0))
	var expose := engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_PLAYER, Vector2i(0, 2))
	var abri := engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_PLAYER, Vector2i(4, 5))

	var menacees: Array = engine.threatened_cells(BattleUnit.TEAM_PLAYER)

	if not menacees.has(expose.cell):
		_fail("le pion sous la tour ennemie n'est pas signale comme menace")
	if menacees.has(abri.cell):
		_fail("un pion hors de portee est signale comme menace")
	if menacees.size() != 1:
		_fail("%d cases menacees au lieu d'une seule" % menacees.size())

	# Une piece morte ne menace plus rien.
	engine.remove_unit(engine.grid.unit_at(Vector2i(0, 0)))
	if not engine.threatened_cells(BattleUnit.TEAM_PLAYER).is_empty():
		_fail("la tour capturee menace encore")

	# Et le camp adverse se lit de la meme facon : c'est la meme fonction, ce
	# qui evite d'en ecrire une deuxieme le jour ou on voudra l'afficher.
	var solo := BattleEngine.new(5, 6)
	solo.add_unit(Balance.TOUR, 1, BattleUnit.TEAM_PLAYER, Vector2i(2, 5))
	var proie := solo.add_unit(Balance.PION, 1, BattleUnit.TEAM_ENEMY, Vector2i(2, 3))
	if not solo.threatened_cells(BattleUnit.TEAM_ENEMY).has(proie.cell):
		_fail("les pieces ennemies menacees ne se lisent pas avec la meme fonction")

	print("  detection des pieces prenables au coup suivant : OK")
	_done("menaces")


# ------------------------------- PERTES --------------------------------------

func _check_losses() -> void:
	print("\n[3] Pertes definitives")

	# On recrute au-dessus du plancher de garnison, sinon les pertes testees
	# seraient immediatement compensees et le test ne prouverait rien.
	Game.reset_progress()
	Game.add_gold(5000)
	for i in range(6):
		Game.recruit(Balance.PION)
	var pions := Game.units_owned(Balance.PION)
	Game.apply_losses({Balance.PION: 2})
	if Game.units_owned(Balance.PION) != pions - 2:
		_fail("les pions perdus ne sont pas retires de l'armee (%d au lieu de %d)" % [
			Game.units_owned(Balance.PION), pions - 2])

	# On ne descend jamais sous zero, meme si la bataille rapporte des pertes
	# superieures a ce que le village possede.
	Game.apply_losses({Balance.PION: 999})
	if Game.units_owned(Balance.PION) < 0:
		_fail("le compte de pions est devenu negatif")

	# Garnison minimale : une armee balayee doit revenir au plancher, sinon le
	# joueur ne peut plus rejouer une bataille pour refaire de l'or.
	Game.apply_losses({Balance.PION: 99, Balance.CAVALIER: 99, Balance.FOU: 99, Balance.TOUR: 99})
	Game.spend_gold(Game.gold)
	for type in Balance.GARRISON_MINIMUM.keys():
		var floor_count := int(Balance.GARRISON_MINIMUM[type])
		if Game.units_owned(type) < floor_count:
			_fail("%s : garnison minimale non retablie (%d au lieu de %d)" % [
				type, Game.units_owned(type), floor_count])
	if Game.total_units() == 0:
		_fail("armee vide et or nul : la partie est sans issue")

	# Une Dame ramenee vivante : le pion promu quitte la caserne, la Dame
	# s'installe au Chateau Royal, qui s'allume au village a cette occasion.
	# C'est la seule facon d'en obtenir une.
	Game.reset_progress()
	if Game.dames_owned() != 0:
		_fail("une Dame est deja au chateau avant la premiere promotion")

	# Au-dessus du plancher de garnison, sinon les pions convertis en Dames
	# seraient aussitot rendus gratuitement et le test ne prouverait rien.
	Game.add_gold(5000)
	while Game.units_owned(Balance.PION) < 6:
		if not Game.recruit(Balance.PION):
			break
	var pions_before := Game.units_owned(Balance.PION)
	if Game.dame_gold_bonus(100) != 0:
		_fail("une aura de Dame s'applique alors qu'aucune n'est rentree")
	var stored := Game.store_promotions(2)
	if stored != 2:
		_fail("2 pions promus et rentres vivants n'ont pas donne 2 Dames (%d)" % stored)
	if Game.dames_owned() != 2:
		_fail("les Dames ne sont pas stockees : %d" % Game.dames_owned())
	if Game.units_owned(Balance.PION) != pions_before - 2:
		_fail("les pions promus n'ont pas quitte la caserne")

	# Aura : deux Dames au repos rapportent deux parts, une Dame deployee
	# renonce a la sienne, et une Dame emmenee ne rapporte plus rien.
	var expected := int(round(1000.0 * Balance.DAME_GOLD_BONUS * 2.0))
	if Game.dame_gold_bonus(1000) != expected:
		_fail("l'aura de deux Dames au repos vaut %d au lieu de %d" % [
			Game.dame_gold_bonus(1000), expected])
	if Game.dame_gold_bonus(1000, 1) != int(round(1000.0 * Balance.DAME_GOLD_BONUS)):
		_fail("deployer une Dame ne retire pas sa seule part de l'aura")
	if Game.dame_gold_bonus(1000, 2) != 0:
		_fail("des Dames toutes deployees rapportent encore de l'or")

	# La Dame n'a pas de batiment a elle : son niveau est le plus faible du
	# niveau du chateau et du nombre de Dames abritees.
	Game.add_gold(50000)
	if Game.start_upgrade(Balance.DAME):
		_fail("la Dame propose une amelioration alors qu'elle suit le chateau")
	if Game.dame_level() != 1:
		_fail("2 Dames dans un chateau Nv.1 ne devraient pas depasser le Nv.1")

	Game.start_upgrade(Balance.CASTLE)
	Game.force_finish_upgrade(Balance.CASTLE)
	if Game.dame_level() != 2:
		_fail("2 Dames dans un chateau Nv.2 devraient etre Nv.2 (%d)" % Game.dame_level())

	Game.start_upgrade(Balance.CASTLE)
	Game.force_finish_upgrade(Balance.CASTLE)
	if Game.dame_level() != 2:
		_fail("le nombre de Dames doit plafonner leur niveau, chateau Nv.3 compris")
	if Game.dames_owned() != 2:
		_fail("l'amelioration du chateau a consomme des Dames")

	# Une Dame capturee se perd comme n'importe quelle piece - et son aura
	# avec elle.
	Game.apply_losses({Balance.DAME: 1})
	if Game.dames_owned() != 1:
		_fail("une Dame capturee n'a pas ete retiree de l'armee")
	if Game.dame_gold_bonus(1000) != int(round(1000.0 * Balance.DAME_GOLD_BONUS)):
		_fail("l'aura n'a pas baisse apres la perte d'une Dame")

	# Et elle ne s'achete a aucun prix.
	Game.add_gold(9999)
	if Game.recruit(Balance.DAME):
		_fail("la Dame a pu etre recrutee, elle ne doit s'obtenir que par promotion")

	Game.reset_progress()
	print("  retrait des pertes, plancher a zero, garnison minimale, Dames : OK")
	_done("pertes")


# ------------------------------- REGLES DE PIECES ----------------------------
#
#  Scenarios minuscules et deterministes : une regle par test, sur un plateau
#  monte a la main. C'est ce qui permet de toucher a l'IA sans casser les regles.

func _check_rules() -> void:
	print("\n[4] Regles de deplacement et de capture")

	# Le pion avance sur une case vide mais ne prend pas devant lui.
	var engine := BattleEngine.new(5, 8)
	var pawn := engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_PLAYER, Vector2i(2, 4))
	var blocker := engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_ENEMY, Vector2i(2, 3))
	var moves := MovementRules.legal_moves(pawn, engine.grid)
	if moves.has(Vector2i(2, 3)):
		_fail("le pion capture droit devant, il ne devrait pas")
	if not moves.is_empty():
		_fail("le pion bloque devant devrait etre immobile, il a %d coups" % moves.size())

	# Il prend en diagonale avant.
	engine.remove_unit(blocker)
	engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_ENEMY, Vector2i(3, 3))
	moves = MovementRules.legal_moves(pawn, engine.grid)
	if not moves.has(Vector2i(3, 3)):
		_fail("le pion ne prend pas en diagonale avant")
	if not moves.has(Vector2i(2, 3)):
		_fail("le pion ne peut plus avancer alors que la case est libre")

	# La tour est bloquee par une piece alliee, et prend la premiere ennemie.
	var engine2 := BattleEngine.new(8, 8)
	var rook := engine2.add_unit(Balance.TOUR, 5, BattleUnit.TEAM_PLAYER, Vector2i(0, 4))
	engine2.add_unit(Balance.PION, 1, BattleUnit.TEAM_PLAYER, Vector2i(2, 4))
	engine2.add_unit(Balance.PION, 1, BattleUnit.TEAM_ENEMY, Vector2i(0, 2))
	var rook_moves := MovementRules.legal_moves(rook, engine2.grid)
	if rook_moves.has(Vector2i(2, 4)) or rook_moves.has(Vector2i(3, 4)):
		_fail("la tour traverse une piece alliee")
	if not rook_moves.has(Vector2i(0, 2)):
		_fail("la tour ne prend pas la premiere piece ennemie de sa ligne")
	if rook_moves.has(Vector2i(0, 1)):
		_fail("la tour depasse la piece qu'elle capture")

	# LE SACRE. Un pion qui atteint le fond ne devient pas Dame d'office : il
	# faut une bataille encore disputee, et un pion qui a fait ses preuves.
	#
	# Le sacre etait AUSSI differe d'un tour ; la regle a ete retiree apres
	# mesure - elle ne coutait pas une seule Dame sur les deux bancs, et elle
	# contredisait les echecs sans laisser aucune prise au joueur.
	#
	# Cas 1 : le pion capture en chemin, donc il a droit a la couronne.
	var engine3 := BattleEngine.new(5, 8)
	var runner := engine3.add_unit(Balance.PION, 4, BattleUnit.TEAM_PLAYER, Vector2i(2, 2))
	engine3.add_unit(Balance.PION, 1, BattleUnit.TEAM_ENEMY, Vector2i(1, 1))
	# Tour ennemie reléguee au fond : elle tient la bataille en vie sans jamais
	# pouvoir atteindre la case du sacre.
	engine3.add_unit(Balance.TOUR, 1, BattleUnit.TEAM_ENEMY, Vector2i(4, 7))

	engine3.play_move(runner, Vector2i(1, 1))     # prise en diagonale
	if runner.captures != 1:
		_fail("la prise du pion n'a pas ete comptee")
	engine3.step()                                 # reponse ennemie

	var crowned := ""
	for event in engine3.play_move(runner, Vector2i(1, 0)):
		if String(event["type"]) == "promotion":
			crowned = String(event["result"])
	if crowned != Balance.DAME:
		_fail("le pion qui a capture devrait etre fait Dame en arrivant : %s" % crowned)
	if runner.type != Balance.DAME:
		_fail("la promotion doit etre IMMEDIATE, sans tour d'attente")

	# Une seule couronne par camp et par bataille : le compteur se tenait dans
	# le chemin differe, et l'oublier en le retirant aurait laisse un camp
	# couronner autant de Dames qu'il amenait de pions au fond.
	var second := engine3.add_unit(Balance.PION, 4, BattleUnit.TEAM_PLAYER, Vector2i(3, 1))
	second.captures = 1
	var again := ""
	for event in engine3.play_move(second, Vector2i(3, 0)):
		if String(event["type"]) == "promotion":
			again = String(event["result"])
	if again == Balance.DAME:
		_fail("un camp a couronne une DEUXIEME Dame dans la meme bataille")
	if runner.origin_type != Balance.PION:
		_fail("la piece promue a perdu son type d'origine, elle ne redeviendra pas un pion")
	if runner.move_range != Balance.move_range(Balance.DAME, 4):
		_fail("la Dame promue ne garde pas la mobilite du niveau de son pion")

	# Cas 2 : un pion qui n'a jamais capture traverse un couloir vide. Il
	# promeut quand meme, mais en piece intermediaire, et sans attendre.
	var engine4 := BattleEngine.new(5, 8)
	var idler := engine4.add_unit(Balance.PION, 4, BattleUnit.TEAM_PLAYER, Vector2i(2, 1))
	engine4.add_unit(Balance.TOUR, 1, BattleUnit.TEAM_ENEMY, Vector2i(4, 7))
	var lesser := ""
	for event in engine4.play_move(idler, Vector2i(2, 0)):
		if String(event["type"]) == "promotion":
			lesser = String(event["result"])
	if lesser != Balance.PROMOTION_FALLBACK:
		_fail("un pion qui n'a rien pris ne devrait pas etre fait Dame : %s" % lesser)

	print("  pion, tour, et conditions de la couronne : OK")
	_done("regles")


# ------------------------------- BATAILLES -----------------------------------

func _play_all_battles() -> void:
	print("\n[4] Simulation des batailles")
	print("  Joueur suppose au niveau de la bataille qu'il affronte.")
	print("")

	var wins := 0
	for battle in Balance.CAMPAIGN:
		# Le niveau du JOUEUR, qui n'est plus celui de l'ennemi : son avantage
		# n'est plus fait de nombre mais de qualite (cf. battle_player_level).
		if _is_winnable(battle, Balance.battle_player_level(battle)):
			wins += 1
		else:
			_fail("bataille %d : aucune composition ne passe" % int(battle["id"]))

	print("")
	_check_first_run()
	print("  Batailles gagnables avec la progression attendue : %d / %d" % [
		wins, Balance.battle_count()])
	print("  Promotions observees : %d" % _promotions_seen)
	if wins < Balance.battle_count():
		_fail("la campagne n'est pas franchissable en jouant normalement")
	_done("batailles")


## "GAGNABLE" veut dire : le joueur peut TROUVER une facon de gagner.
##
## Deux compositions - une armee variee, une armee de pions - et jusqu'a
## FORMATIONS rangements differents de chacune. Exiger qu'une composition unique
## gagne partout nierait l'interet du choix d'armee : contre des pions, ce sont
## les pions qui repondent.
##
## POURQUOI PLUSIEURS RANGEMENTS. Le combat est deterministe, d'ou l'idee qu'un
## seul essai suffisait a prouver un resultat. C'est faux, et ca s'est vu : la
## bataille 10 basculait de VICTOIRE a defaite selon le rangement, alors que
## l'armee, la charge et l'adversaire ne bougeaient pas d'un pouce. Un coup
## different au troisieme tour envoie la partie ailleurs. Juger une bataille sur
## UN tirage, c'est tirer a pile ou face et appeler ca une mesure.
##
## Le premier rangement est essaye d'abord et seul : tant qu'il gagne - le cas
## des neuf premieres batailles - le banc ne paie rien de plus. On ne va
## chercher les variantes que la ou la reponse n'est pas franche.
const FORMATIONS := 5


func _is_winnable(battle: Dictionary, level: int) -> bool:
	for variante in range(FORMATIONS):
		for style in ["variee", "pions"]:
			if _play_battle(battle, level, level, style, variante):
				return true
	return false


## La toute premiere partie : armee de depart exacte, sans un seul recrutement.
##
## Le reste de la simulation suppose des casernes pleines, ce qui masque le cas
## le plus important - un joueur qui lance sa premiere bataille et perd des
## pieces definitivement.
##
## Le combat n'a plus aucune source d'alea (la promotion est desormais
## deterministe, voir BattleEngine.step) : un seul essai suffit a prouver
## le resultat.
func _check_first_run() -> void:
	var battle := Balance.battle(1)
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = Balance.battle_ai_skill(battle)
	var cells: Array = engine.grid.free_enemy_cells()
	var enemy_count := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for j in range(int(battle["enemies"][type])):
			engine.add_unit(type, int(battle["level"]), BattleUnit.TEAM_ENEMY, cells[enemy_count])
			enemy_count += 1

	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		pool[type] = int(Balance.STARTING_UNITS.get(type, 0))

	var placed := _deploy(engine, pool, Balance.deploy_capacity(1), 1)

	while not engine.finished:
		engine.step()

	var victory := engine.winner == BattleUnit.TEAM_PLAYER
	print("  Premiere partie (armee de depart, sans recrutement) : %d vs %d  ->  %s" % [
		placed, enemy_count, "VICTOIRE" if victory else "defaite"])
	if not victory:
		_fail("la toute premiere bataille ne se gagne pas avec l'armee de depart")


## Joue une bataille avec un joueur au niveau donne. Le combat est
## entierement deterministe (placement + IA fixes, plus aucun alea) : un seul
## passage par composition suffit.
func _play_battle(battle: Dictionary, castle_level: int, unit_level: int, style: String = "variee",
		variante: int = 0) -> bool:
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = Balance.battle_ai_skill(battle)

	var level := int(battle["level"])
	var cells: Array = engine.grid.free_enemy_cells()
	var enemy_count := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[enemy_count])
			enemy_count += 1

	var slots := Balance.deploy_capacity(castle_level)
	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		# Armee de pions : casernes lourdes volontairement presque vides.
		if style == "pions" and type != Balance.PION:
			pool[type] = 1
		else:
			pool[type] = Balance.capacity(type, unit_level)

	var placed := _deploy(engine, pool, slots, unit_level, variante)

	if placed == 0:
		_fail("bataille %d : aucune piece joueur placee" % int(battle["id"]))
		return false

	# La RAISON de la fin, pas seulement l'issue : "NUL" ne dit pas si c'est un
	# pat, une position morte ou un enlisement, et ces trois-la ne se reglent
	# pas au meme endroit.
	var reason := ""
	while not engine.finished:
		for event in engine.step():
			if String(event["type"]) == "promotion":
				_promotions_seen += 1
			elif String(event["type"]) == "end":
				reason = String(event.get("reason", ""))

	var victory := engine.winner == BattleUnit.TEAM_PLAYER
	var lost := 0
	for count in engine.losses(BattleUnit.TEAM_PLAYER).values():
		lost += int(count)

	print("  Bataille %2d  %-20s  Nv.%d  armee %-7s n%d  %2d vs %2d  ->  %-8s  %2d perdues, %3d activations  %s" % [
		int(battle["id"]), String(battle["name"]), unit_level, style, variante + 1, placed, enemy_count,
		"NUL" if engine.is_draw() else ("VICTOIRE" if victory else "defaite"),
		lost, engine.activation_count, reason
	])

	if engine.activation_count >= int(Balance.COMBAT["max_activations"]):
		_fail("bataille %d : limite d'activations atteinte (combat bloque ?)" % int(battle["id"]))

	return victory


## Deploie l'armee exactement comme le bouton Auto du jeu : alternance des
## types, puis pions devant et pieces lourdes derriere. Retourne le nombre de
## pieces posees.
## `capacity` est un budget de poids (cf. CASTLE_DATA.deploy_capacity), pas un
## nombre de pieces : chaque type ajoute pese Balance.deploy_weight(type).
func _deploy(engine: BattleEngine, pool: Dictionary, capacity: int, level: int,
		variante: int = 0) -> int:
	var order: Array = []
	var weight := 0
	var exhausted: Dictionary = {}
	while true:
		var type := _pick_round_robin(pool, order.size(), exhausted)
		if type.is_empty():
			break
		var type_weight := Balance.deploy_weight(type)
		if weight + type_weight > capacity:
			exhausted[type] = true
			continue
		order.append(type)
		weight += type_weight
		pool[type] = int(pool[type]) - 1

	order.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))

	# La variante fait tourner les cases sous une armee inchangee : meme
	# effectif, meme charge, rangement different. C'est ce que fait un joueur
	# qui repose son armee autrement. Meme decalage que tools/tune_probe.gd,
	# pour que les deux bancs parlent des memes formations.
	var cells: Array = engine.grid.free_player_cells()
	var decalage := (variante * 3) % maxi(1, cells.size())
	var placed := mini(order.size(), cells.size())
	for i in range(placed):
		engine.add_unit(String(order[i]), level, BattleUnit.TEAM_PLAYER,
			cells[(i + decalage) % cells.size()])
	return placed


## Alterne les types pour obtenir une armee variee plutot qu'un mur de pions.
## `exhausted` exclut les types qui ne rentrent plus dans le poids restant.
func _pick_round_robin(pool: Dictionary, cursor: int, exhausted: Dictionary = {}) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(cursor + offset) % types.size()]
		if exhausted.has(type):
			continue
		if int(pool[type]) > 0:
			return type
	return ""


# ------------------------------- FIN DE PARTIE -------------------------------

## Un combat doit FINIR, et finir juste. Ces trois verifications sont nees d'un
## bug reel : sur les deux premieres batailles - les seules en AI_NOVICE -
## l'IA restait plantee alors qu'elle avait des coups legaux, le moteur passait
## son tour, et comme le coup du JOUEUR remettait le compteur de passes a zero,
## la partie ne se terminait jamais. Mesure avant correction : 48 passes
## illegitimes sur 60 parties.
func _check_endgame() -> void:
	print("")
	print("[3c] Fin de partie")
	_check_no_idle_pass()
	_check_stalemate_is_draw()
	_check_dead_position_is_draw()
	_done("fin de partie")


## PAT - le camp au trait n'a plus aucun coup legal. Comme aux echecs, c'est un
## NUL, quel que soit le materiel restant.
func _check_stalemate_is_draw() -> void:
	var engine := BattleEngine.new(5, 6)
	engine.auto_mode = false
	# Pion du joueur bloque par un pion ennemi pile devant : un pion ne prend
	# pas tout droit, et ses deux diagonales sont vides ou hors du plateau.
	engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_PLAYER, Vector2i(0, 5))
	engine.add_unit(Balance.PION, 1, BattleUnit.TEAM_ENEMY, Vector2i(0, 4))
	# Une tour ennemie a l'autre bout, pour que l'ennemi, LUI, ait un coup.
	engine.add_unit(Balance.TOUR, 1, BattleUnit.TEAM_ENEMY, Vector2i(4, 0))

	if engine.has_any_move(BattleUnit.TEAM_PLAYER):
		_fail("pat : le pion du joueur n'est pas bloque, le test ne prouve rien")
		return

	engine.current_team = BattleUnit.TEAM_ENEMY
	engine.step()

	var draw_expected := bool(Balance.COMBAT["stalemate_is_draw"])
	if not engine.finished:
		_fail("pat : le joueur n'a aucun coup legal et la bataille continue")
	elif draw_expected and not engine.is_draw():
		_fail("pat : la bataille designe un vainqueur alors que le reglage dit NUL")
	elif not draw_expected and engine.winner != BattleUnit.TEAM_ENEMY:
		_fail("pat : le camp bloque ne perd pas alors que le reglage le prevoit")
	else:
		print("  pat (plus aucun coup legal) : %s" % ("NUL" if draw_expected else "le camp bloque perd"))


## POSITION MORTE - les deux camps peuvent encore bouger, mais plus aucune
## capture n'est possible, jamais.
##
## Un cavalier Nv.1 ne saute qu'en diagonale d'une case : il ne quitte donc
## jamais la couleur de case ou il est pose. Poses sur des couleurs opposees,
## deux cavaliers peuvent se courir apres indefiniment sans jamais se toucher.
##
## Le compteur d'enlisement finirait par trancher - mais 80 activations plus
## tard. Le joueur a le droit de le savoir tout de suite.
func _check_dead_position_is_draw() -> void:
	var engine := BattleEngine.new(5, 6)
	engine.auto_mode = false
	engine.add_unit(Balance.CAVALIER, 1, BattleUnit.TEAM_PLAYER, Vector2i(0, 5))
	engine.add_unit(Balance.CAVALIER, 1, BattleUnit.TEAM_ENEMY, Vector2i(0, 0))
	engine.add_unit(Balance.CAVALIER, 1, BattleUnit.TEAM_ENEMY, Vector2i(2, 0))

	var guard := 0
	while not engine.finished and guard < 400:
		guard += 1
		engine.step()

	if not engine.finished:
		_fail("position morte : la bataille ne se termine pas")
		return
	if not engine.is_draw():
		_fail("position morte : la bataille designe un vainqueur au lieu d'un nul")
		return
	if engine.activation_count > 20:
		_fail(("position morte : %d activations avant le nul - le jeu a attendu le "
			+ "compteur d'enlisement au lieu de voir que plus aucune capture "
			+ "n'etait possible") % engine.activation_count)
	else:
		print("  position morte (plus aucune capture possible) : NUL en %d activations"
			% engine.activation_count)


## Un camp qui a des coups legaux ne doit JAMAIS passer son tour. La passe est
## reservee au camp reellement bloque - et celui-la fait desormais nul.
func _check_no_idle_pass() -> void:
	var bad := 0
	for id in range(1, Balance.battle_count() + 1):
		var battle := Balance.battle(id)
		for variante in range(2):
			bad += _count_idle_passes(battle, variante)
	if bad > 0:
		_fail("%d passe(s) de tour alors que le camp avait un coup legal" % bad)
	else:
		print("  aucun camp ne passe son tour en ayant un coup legal")


## Rejoue une bataille dans les conditions REELLES du bug : le joueur joue a la
## main (auto_mode = false, coups tires ici), l'ennemi repond par step().
## Retourne le nombre d'activations ou l'IA a passe en ayant un coup jouable.
func _count_idle_passes(battle: Dictionary, variante: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 * int(battle["id"]) + variante

	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = Balance.battle_ai_skill(battle)
	engine.auto_mode = false

	var level := int(battle["level"])
	var cells: Array = engine.grid.free_enemy_cells()
	var placed := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[placed])
			placed += 1

	var player_level := Balance.battle_player_level(battle)
	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		pool[type] = Balance.capacity(type, player_level)
	_deploy(engine, pool, Balance.deploy_capacity(player_level), player_level, variante)

	var passes := 0
	var guard := 0
	while not engine.finished and guard < 2000:
		guard += 1
		if engine.current_team == BattleUnit.TEAM_PLAYER:
			var options: Array = []
			for unit in engine.living(BattleUnit.TEAM_PLAYER):
				for move in engine.legal_moves(unit):
					options.append([unit, move])
			if options.is_empty():
				# Joueur pat : c'est _check_stalemate_is_draw qui en repond.
				break
			var pick: Array = options[rng.randi_range(0, options.size() - 1)]
			engine.play_move(pick[0], pick[1])
			continue

		var had_moves := engine.has_any_move(engine.current_team)
		for event in engine.step():
			if String(event["type"]) == "pass" and had_moves:
				passes += 1
	return passes


# ------------------------------- SCENES --------------------------------------

## Instancie chaque ecran pour verifier les chemins de noeuds et les _ready().
func _check_scenes() -> void:
	print("\n[5] Chargement des ecrans")

	Game.reset_progress()
	Router.current_battle_id = 1

	for path in [Router.SPLASH_SCENE, Router.INTRO_SCENE, Router.VILLAGE_SCENE,
			Router.CASTLE_SCENE, Router.CODEX_SCENE, Router.CAMPAIGN_SCENE,
			Router.PREP_SCENE, Router.BATTLE_SCENE]:
		var packed: PackedScene = load(path)
		if packed == null:
			_fail("scene introuvable : %s" % path)
			continue
		var instance: Node = packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame
		print("  %s : OK" % path.get_file())
		instance.queue_free()
		await get_tree().process_frame

	await _check_last_formation_button()
	_done("ecrans")


## DERNIERE FORMATION sur un VRAI ecran de bataille.
##
## Le reste du banc ne touche jamais la couche interface : il parle au moteur
## et a GameState. Une erreur de cablage entre les deux - un mauvais numero de
## bataille, une case hors zone, un signal mal branche - ne se verrait donc
## qu'a la main, ecran par ecran.
func _check_last_formation_button() -> void:
	Game.reset_progress()
	Router.current_battle_id = 1

	# Bataille 1 : 5 colonnes, 6 rangees, 2 rangees de deploiement. Les cases
	# du joueur sont donc en y = 4 et 5.
	Game.remember_formation(1, [[Balance.PION, 0, 4], [Balance.PION, 1, 4]])

	var packed: PackedScene = load(Router.BATTLE_SCENE)
	var screen: Node = packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	screen._on_last_formation()
	if screen._placed.size() != 2:
		_fail("DERNIERE FORMATION repose %d pieces au lieu des 2 memorisees" % screen._placed.size())
	elif screen._placed[0].cell != Vector2i(0, 4) or screen._placed[1].cell != Vector2i(1, 4):
		_fail("DERNIERE FORMATION ne repose pas les pieces sur leurs cases d'origine")
	else:
		print("  DERNIÈRE FORMATION : 2 pieces reposees sur leurs cases")

	screen.queue_free()
	await get_tree().process_frame
	Game.reset_progress()


# ------------------------------- BOUCLE DE JEU -------------------------------

## Verifie le circuit complet : victoire -> or -> bataille suivante debloquee.
func _check_campaign_loop() -> void:
	print("\n[6] Boucle de progression")

	Game.reset_progress()
	var gold_before := Game.gold
	var battle := Balance.battle(1)
	Game.win_battle(1, int(battle["reward"]))

	if Game.gold != gold_before + int(battle["reward"]):
		_fail("la recompense n'a pas ete creditee")
	if Game.unlocked_battle() != 2:
		_fail("la bataille 2 n'est pas debloquee apres la victoire")
	if not Game.is_battle_won(1):
		_fail("la bataille 1 n'est pas marquee comme gagnee")

	Game._load()
	if Game.unlocked_battle() != 2:
		_fail("la progression n'a pas ete relue depuis le disque")

	# Rejouer une bataille deja gagnee doit rapporter moins.
	var full := int(battle["reward"])
	var replay := Game.reward_for(1)
	if replay >= full:
		_fail("rejouer la bataille 1 rapporte autant qu'une premiere victoire")
	if replay <= 0:
		_fail("rejouer une bataille ne rapporte rien : le farm est impossible")

	print("  victoire, recompense, deblocage, relecture disque : OK")
	print("  rejouer la bataille 1 : %d or au lieu de %d" % [replay, full])
	Game.reset_progress()
	_done("boucle")


# ------------------------------- BOUTIQUE ------------------------------------

## La boutique (cf. Balance.SHOP et chantier_h_boutique.md).
##
## Deux choses a garder a l'oeil, et ce sont des REGLES, pas des reglages :
## une gemme n'accelere jamais un coffre gratuit, et un pack d'or ne doit
## jamais valoir de quoi sauter la campagne.
func _check_shop() -> void:
	# --- coherence des donnees -------------------------------------------
	var ids: Array = []
	var previous_gems := 0
	for chest in Balance.SHOP["chests"]:
		if ids.has(chest["id"]):
			_fail("deux coffres portent l'identifiant '%s'" % chest["id"])
		ids.append(chest["id"])
		if int(chest["gems"]) <= previous_gems:
			_fail("le coffre '%s' ne coute pas plus cher que le precedent" % chest["id"])
		previous_gems = int(chest["gems"])

	var unlimited := 0
	for chest in Balance.SHOP["chests"]:
		if int(chest["seconds"]) < 0:
			unlimited += 1
	if unlimited != 1:
		_fail("il doit y avoir exactement un coffre qui termine tout, il y en a %d" % unlimited)

	for id in Balance.free_chest_ids():
		var free := Balance.free_chest(id)
		if int(free["seconds"]) <= 0 or int(free["gems"]) <= 0:
			_fail("le coffre gratuit '%s' ne rend rien ou n'attend rien" % id)

	# --- le garde-fou economique -----------------------------------------
	#
	# Le pack dessine a 25000 or valait plus que le cumul d'ameliorations
	# demande a la bataille 10 : il proposait de sauter la campagne. Un
	# cinquieme de ce que verse une traversee simple est la limite.
	var campaign_gold := 0
	for battle in Balance.CAMPAIGN:
		campaign_gold += int(battle["reward"]) * Balance.battle_fights(battle)
	var biggest := 0
	for pack in Balance.SHOP["gold_packs"]:
		biggest = maxi(biggest, int(pack["gold"]))
	if biggest * 5 > campaign_gold:
		_fail("le plus gros pack d'or (%d) depasse un cinquieme de ce que verse la campagne (%d)"
			% [biggest, campaign_gold])

	# Un pack qui grossit doit devenir MEILLEUR. Le premier reglage rendait 10
	# or par gemme sur le petit pack et 7,5 sur le gros : qui achetait le plus
	# cher se faisait avoir, et seul un joueur qui fait la division s'en
	# apercevait.
	var previous_rate := 0.0
	for pack in Balance.SHOP["gold_packs"]:
		var rate := float(pack["gold"]) / float(pack["gems"])
		if rate < previous_rate:
			_fail("le pack a %d gemmes rend %.2f or/gemme, moins que le precedent (%.2f)"
				% [int(pack["gems"]), rate, previous_rate])
		previous_rate = rate

	# ⚠️ Ce garde-fou-la ne suffit PAS a lui seul : il ne regarde qu'un pack a
	# la fois. Ce qu'un joueur peut convertir en tout sur une campagne se
	# mesure dans tools/shop_probe.tscn, qui seul connait le robinet.

	# --- le robinet -------------------------------------------------------
	Game.reset_progress()
	if Game.gems != 0:
		_fail("une partie neuve ne demarre pas a zero gemme")
	if not Game.free_chest_ready("horaire"):
		_fail("le coffre horaire n'est pas pret sur une partie neuve")

	var gained := Game.claim_free_chest("horaire")
	if gained != int(Balance.free_chest("horaire")["gems"]):
		_fail("le coffre horaire ne rend pas ses gemmes")
	if Game.gems != gained:
		_fail("les gemmes ramassees n'arrivent pas en poche")
	if Game.free_chest_ready("horaire"):
		_fail("le coffre horaire se reprend deux fois de suite")
	if Game.claim_free_chest("horaire") != 0:
		_fail("un coffre non pret rend quand meme des gemmes")

	# --- un coffre achete accelere une amelioration -----------------------
	Game.add_gems(2000)
	Game.add_gold(50000)
	var gems_before := Game.gems
	if Game.buy_chest("rare", Balance.PION):
		_fail("un coffre s'achete alors qu'aucune amelioration ne tourne")
	if Game.gems != gems_before:
		_fail("un achat refuse a quand meme debite des gemmes")

	# Le retranchement exact se mesure sur un petit nombre de secondes : tous
	# les premiers paliers du jeu durent moins qu'un coffre Rare (le chateau
	# 120 s, le pion 30 s), et une soustraction bornee a zero ne prouve rien.
	Game.start_upgrade(Balance.CASTLE)
	var remaining_before := Game.upgrade_remaining(Balance.CASTLE)
	if not Game.accelerate_upgrade(Balance.CASTLE, 20):
		_fail("l'acceleration refuse une amelioration qui tourne pourtant")
	var lost := remaining_before - Game.upgrade_remaining(Balance.CASTLE)
	if lost < 20 or lost > 21:
		_fail("20 secondes achetees en ont retranche %d" % lost)

	# Un coffre plus long que ce qui reste TERMINE l'amelioration : c'est le
	# cas courant, un coffre Rare valant une heure et les premiers paliers
	# quelques minutes.
	var castle_level := Game.building_level(Balance.CASTLE)
	if not Game.buy_chest("rare", Balance.CASTLE):
		_fail("le coffre Rare ne s'achete pas alors que le chateau monte")
	if Game.is_upgrading(Balance.CASTLE):
		_fail("un coffre plus long que l'attente n'a pas termine l'amelioration")
	if Game.building_level(Balance.CASTLE) != castle_level + 1:
		_fail("l'amelioration terminee par un coffre n'a pas fait monter le chateau")

	# --- une gemme n'accelere JAMAIS un coffre gratuit --------------------
	gems_before = Game.gems
	var chest_ready_before := Game.free_chest_remaining("horaire")
	if Game.buy_chest("rare", "horaire"):
		_fail("un coffre payant accelere un coffre gratuit - le robinet imprime")
	if Game.gems != gems_before or Game.free_chest_remaining("horaire") != chest_ready_before:
		_fail("viser un coffre gratuit a quand meme eu un effet")

	# --- le Legendaire termine TOUT ---------------------------------------
	Game.start_upgrade(Balance.CAVALIER)
	if Game.upgrades_in_progress().is_empty():
		_fail("aucune amelioration ne tourne avant le coffre Legendaire")
	if not Game.buy_chest("legendaire"):
		_fail("le coffre Legendaire ne s'achete pas")
	if not Game.upgrades_in_progress().is_empty():
		_fail("le coffre Legendaire a laisse une amelioration en cours")

	# --- un pack d'or -----------------------------------------------------
	var pack: Dictionary = Balance.SHOP["gold_packs"][0]
	var gold_before := Game.gold
	gems_before = Game.gems
	if not Game.buy_gold_pack(0):
		_fail("le premier pack d'or ne s'achete pas")
	if Game.gold != gold_before + int(pack["gold"]):
		_fail("le pack d'or n'a pas verse son or")
	if Game.gems != gems_before - int(pack["gems"]):
		_fail("le pack d'or n'a pas debite ses gemmes")

	# --- une vieille sauvegarde n'a ni gemmes ni coffres ------------------
	Game.reset_progress()
	if Game.gems != 0 or Game.free_chest_remaining("horaire") != 0:
		_fail("l'etat de la boutique ne se remet pas a neuf")

	_done("boutique")
