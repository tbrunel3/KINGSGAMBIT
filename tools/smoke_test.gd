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


func _ready() -> void:
	print("=== KING'S GAMBIT - banc de test ===")
	_check_balance()
	_check_save()
	_check_losses()
	_check_rules()
	_play_all_battles()
	await _check_scenes()
	_check_campaign_loop()

	print("")
	if _failures == 0:
		print("RESULTAT : tout est passe.")
	else:
		print("RESULTAT : %d probleme(s) detecte(s)." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _fail(message: String) -> void:
	_failures += 1
	print("  ECHEC : %s" % message)


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

	if Balance.CASTLE_DATA["deploy_slots"].size() != levels:
		_fail("chateau : deploy_slots a %d entrees pour %d niveaux" % [
			Balance.CASTLE_DATA["deploy_slots"].size(), levels])

	# La Dame n'est pas recrutable mais doit exister pour la promotion.
	if not Balance.UNITS.has(Balance.DAME):
		_fail("la Dame est absente de Balance.UNITS")
	if Balance.UNIT_TYPES.has(Balance.DAME):
		_fail("la Dame ne doit pas etre recrutable")

	# Le pion doit rester disponible des le depart : sans lui, aucune armee
	# n'est possible avant le premier niveau de chateau.
	if Balance.is_unlockable(Balance.PION):
		_fail("le pion ne devrait pas avoir de seuil de deblocage")
	for type in [Balance.CAVALIER, Balance.FOU, Balance.TOUR]:
		var required := Balance.unlock_castle_level(type)
		if required < 2 or required > Balance.max_level(Balance.CASTLE):
			_fail("%s : seuil de deblocage chateau incoherent (%d)" % [type, required])

	if Balance.PROMOTION_DAME_CHANCE.size() != Balance.MAX_LEVEL:
		_fail("PROMOTION_DAME_CHANCE a %d entrees pour %d niveaux" % [
			Balance.PROMOTION_DAME_CHANCE.size(), Balance.MAX_LEVEL])
	for level in range(1, Balance.MAX_LEVEL + 1):
		var chance := Balance.promotion_dame_chance(level)
		if chance <= 0 or chance >= 100:
			_fail("promotion_dame_chance niveau %d : %d%% hors plage" % [level, chance])
	for level in range(2, Balance.MAX_LEVEL + 1):
		if Balance.promotion_dame_chance(level) < Balance.promotion_dame_chance(level - 1):
			_fail("promotion_dame_chance : la chance de Dame baisse au niveau %d" % level)

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

	Game.reset_progress()
	print("  retrait des pertes, plancher a zero, garnison minimale : OK")


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

	# Promotion : un pion qui atteint la rangee 0 devient Dame.
	var engine3 := BattleEngine.new(5, 8)
	engine3.add_unit(Balance.PION, 1, BattleUnit.TEAM_PLAYER, Vector2i(2, 1))
	engine3.add_unit(Balance.TOUR, 1, BattleUnit.TEAM_ENEMY, Vector2i(4, 0))
	var promoted := false
	var guard := 0
	var promotion_result := ""
	while not engine3.finished and guard < 60:
		for event in engine3.step():
			if String(event["type"]) == "promotion":
				promoted = true
				promotion_result = String(event["result"])
		guard += 1
	if not promoted:
		_fail("aucune promotion alors qu'un pion pouvait atteindre le fond")
	else:
		if not Balance.PROMOTION_TYPES.has(promotion_result):
			_fail("la loterie de promotion a produit un type inattendu : %s" % promotion_result)
		var piece: BattleUnit = engine3.living(BattleUnit.TEAM_PLAYER)[0] if not engine3.living(BattleUnit.TEAM_PLAYER).is_empty() else null
		if piece != null:
			if piece.type != promotion_result:
				_fail("la piece promue n'a pas le type tire par la loterie")
			if piece.origin_type != Balance.PION:
				_fail("la piece promue a perdu son type d'origine, elle ne redeviendra pas un pion")

	# La loterie doit vraiment etre aleatoire : sur beaucoup de tirages, les
	# trois issues apparaissent, et la Dame reste rare a bas niveau.
	var counts := {Balance.CAVALIER: 0, Balance.FOU: 0, Balance.DAME: 0}
	for i in range(600):
		var result := Balance.roll_promotion(1)
		counts[result] = int(counts[result]) + 1
	for type in counts.keys():
		if int(counts[type]) == 0:
			_fail("la loterie de promotion n'a jamais produit %s en 600 tirages" % type)
	if int(counts[Balance.DAME]) >= int(counts[Balance.CAVALIER]) or int(counts[Balance.DAME]) >= int(counts[Balance.FOU]):
		_fail("la Dame n'est pas plus rare que cavalier/fou au niveau 1 (%s)" % counts)

	print("  pion (avance, prise diagonale), tour (blocage, prise), promotion : OK")


# ------------------------------- BATAILLES -----------------------------------

func _play_all_battles() -> void:
	print("\n[4] Simulation des batailles")
	print("  Joueur suppose au niveau de la bataille qu'il affronte.")
	print("")

	# Deux compositions par bataille : une armee variee et une armee de pions.
	# Exiger qu'une seule composition gagne partout reviendrait a nier l'interet
	# du choix d'armee - contre des pions, ce sont les pions qui repondent.
	var wins := 0
	for battle in Balance.CAMPAIGN:
		var level := int(battle["level"])
		var varied := _play_battle(battle, level, level, "variee")
		var massed := _play_battle(battle, level, level, "pions") if not varied else false
		if varied or massed:
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


## La toute premiere partie : armee de depart exacte, sans un seul recrutement.
##
## Le reste de la simulation suppose des casernes pleines, ce qui masque le cas
## le plus important - un joueur qui lance sa premiere bataille et perd des
## pieces definitivement.
##
## La loterie de promotion (voir Balance.roll_promotion) rend le combat non
## deterministe : un seul essai ne prouve plus rien. On mesure donc un taux de
## victoire sur plusieurs essais plutot qu'un pass/fail sur un seul tirage -
## une bataille perdue reste rejouable en jeu, mais le tout premier combat doit
## rester gagnable largement plus souvent qu'il n'est perdu.
const _FIRST_RUN_TRIALS := 80
const _FIRST_RUN_MIN_RATE := 0.5

func _check_first_run() -> void:
	var battle := Balance.battle(1)
	var wins := 0
	var placed := 0
	var enemy_count := 0

	for i in range(_FIRST_RUN_TRIALS):
		var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
		var cells: Array = engine.grid.free_enemy_cells()
		enemy_count = 0
		for type in Balance.UNIT_TYPES:
			if not battle["enemies"].has(type):
				continue
			for j in range(int(battle["enemies"][type])):
				engine.add_unit(type, int(battle["level"]), BattleUnit.TEAM_ENEMY, cells[enemy_count])
				enemy_count += 1

		var pool: Dictionary = {}
		for type in Balance.UNIT_TYPES:
			pool[type] = int(Balance.STARTING_UNITS.get(type, 0))

		placed = _deploy(engine, pool, Balance.deploy_slots(1), 1)

		while not engine.finished:
			engine.step()

		if engine.winner == BattleUnit.TEAM_PLAYER:
			wins += 1

	var rate := float(wins) / float(_FIRST_RUN_TRIALS)
	print("  Premiere partie (armee de depart, sans recrutement) : %d vs %d  ->  %d/%d essais gagnes (%.0f%%)" % [
		placed, enemy_count, wins, _FIRST_RUN_TRIALS, rate * 100.0])
	if rate < _FIRST_RUN_MIN_RATE:
		_fail("la toute premiere bataille ne se gagne que %.0f%% du temps (minimum %.0f%%)" % [
			rate * 100.0, _FIRST_RUN_MIN_RATE * 100.0])


## Joue une bataille avec un joueur au niveau donne, jusqu'a _BATTLE_ATTEMPTS
## essais. Retourne true des la premiere victoire : la loterie de promotion
## rend un essai isole non concluant, mais une bataille perdue reste rejouable
## en jeu, donc n'echoue vraiment que si aucun essai ne passe.
const _BATTLE_ATTEMPTS := 5

func _play_battle(battle: Dictionary, castle_level: int, unit_level: int, style: String = "variee") -> bool:
	for attempt in range(_BATTLE_ATTEMPTS):
		if _play_battle_once(battle, castle_level, unit_level, style, attempt + 1):
			return true
	return false


func _play_battle_once(battle: Dictionary, castle_level: int, unit_level: int, style: String, attempt: int) -> bool:
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))

	var level := int(battle["level"])
	var cells: Array = engine.grid.free_enemy_cells()
	var enemy_count := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[enemy_count])
			enemy_count += 1

	var slots := Balance.deploy_slots(castle_level)
	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		# Armee de pions : casernes lourdes volontairement presque vides.
		if style == "pions" and type != Balance.PION:
			pool[type] = 1
		else:
			pool[type] = Balance.capacity(type, unit_level)

	var placed := _deploy(engine, pool, slots, unit_level)

	if placed == 0:
		_fail("bataille %d : aucune piece joueur placee" % int(battle["id"]))
		return false

	while not engine.finished:
		for event in engine.step():
			if String(event["type"]) == "promotion":
				_promotions_seen += 1

	var victory := engine.winner == BattleUnit.TEAM_PLAYER
	var lost := 0
	for count in engine.losses(BattleUnit.TEAM_PLAYER).values():
		lost += int(count)

	var attempt_note := "" if attempt == 1 else "  (essai %d/%d)" % [attempt, _BATTLE_ATTEMPTS]
	print("  Bataille %2d  %-20s  Nv.%d  armee %-7s  %2d vs %2d  ->  %-8s  %2d perdues, %d activations%s" % [
		int(battle["id"]), String(battle["name"]), unit_level, style, placed, enemy_count,
		"VICTOIRE" if victory else "defaite", lost, engine.activation_count, attempt_note
	])

	if engine.activation_count >= int(Balance.COMBAT["max_activations"]):
		_fail("bataille %d : limite d'activations atteinte (combat bloque ?)" % int(battle["id"]))

	return victory


## Deploie l'armee exactement comme le bouton Auto du jeu : alternance des
## types, puis pions devant et pieces lourdes derriere. Retourne le nombre de
## pieces posees.
func _deploy(engine: BattleEngine, pool: Dictionary, slots: int, level: int) -> int:
	var order: Array = []
	while order.size() < slots:
		var type := _pick_round_robin(pool, order.size())
		if type.is_empty():
			break
		order.append(type)
		pool[type] = int(pool[type]) - 1

	order.sort_custom(func(a, b): return Balance.unit_value(a) < Balance.unit_value(b))

	var cells: Array = engine.grid.free_player_cells()
	var placed := mini(order.size(), cells.size())
	for i in range(placed):
		engine.add_unit(String(order[i]), level, BattleUnit.TEAM_PLAYER, cells[i])
	return placed


## Alterne les types pour obtenir une armee variee plutot qu'un mur de pions.
func _pick_round_robin(pool: Dictionary, cursor: int) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(cursor + offset) % types.size()]
		if int(pool[type]) > 0:
			return type
	return ""


# ------------------------------- SCENES --------------------------------------

## Instancie chaque ecran pour verifier les chemins de noeuds et les _ready().
func _check_scenes() -> void:
	print("\n[5] Chargement des ecrans")

	Game.reset_progress()
	Router.current_battle_id = 1

	for path in [Router.VILLAGE_SCENE, Router.CAMPAIGN_SCENE, Router.PREP_SCENE, Router.BATTLE_SCENE]:
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
