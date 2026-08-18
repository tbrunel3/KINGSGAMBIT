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
	while not engine3.finished and guard < 60:
		for event in engine3.step():
			if String(event["type"]) == "promotion":
				promoted = true
		guard += 1
	if not promoted:
		_fail("aucune promotion alors qu'un pion pouvait atteindre le fond")
	else:
		var queen: BattleUnit = engine3.living(BattleUnit.TEAM_PLAYER)[0] if not engine3.living(BattleUnit.TEAM_PLAYER).is_empty() else null
		if queen != null:
			if queen.type != Balance.DAME:
				_fail("le pion promu n'est pas devenu une Dame")
			if queen.origin_type != Balance.PION:
				_fail("la Dame promue a perdu son type d'origine, elle ne redeviendra pas un pion")

	print("  pion (avance, prise diagonale), tour (blocage, prise), promotion : OK")


# ------------------------------- BATAILLES -----------------------------------

func _play_all_battles() -> void:
	print("\n[4] Simulation des batailles")
	print("  Joueur suppose au niveau de la bataille qu'il affronte.")
	print("")

	var wins := 0
	for battle in Balance.CAMPAIGN:
		var level := int(battle["level"])
		if _play_battle(battle, level, level):
			wins += 1

	print("")
	print("  Batailles gagnables avec la progression attendue : %d / %d" % [
		wins, Balance.battle_count()])
	print("  Promotions observees : %d" % _promotions_seen)
	if wins < Balance.battle_count():
		_fail("la campagne n'est pas franchissable en jouant normalement")


## Joue une bataille avec un joueur au niveau donne. Retourne true si victoire.
func _play_battle(battle: Dictionary, castle_level: int, unit_level: int) -> bool:
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
		pool[type] = Balance.capacity(type, unit_level)

	var placed := 0
	var cursor := 0
	for cell in engine.grid.free_player_cells():
		if placed >= slots:
			break
		var type := _pick_round_robin(pool, cursor)
		if type.is_empty():
			break
		engine.add_unit(type, unit_level, BattleUnit.TEAM_PLAYER, cell)
		pool[type] = int(pool[type]) - 1
		cursor += 1
		placed += 1

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

	print("  Bataille %2d  %-20s  Nv.%d  %2d vs %2d  ->  %-8s  %2d pieces perdues, %d activations" % [
		int(battle["id"]), String(battle["name"]), unit_level, placed, enemy_count,
		"VICTOIRE" if victory else "defaite", lost, engine.activation_count
	])

	if engine.activation_count >= int(Balance.COMBAT["max_activations"]):
		_fail("bataille %d : limite d'activations atteinte (combat bloque ?)" % int(battle["id"]))

	return victory


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
