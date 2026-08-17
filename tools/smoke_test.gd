extends Node
##
## BANC DE TEST - verifie la coherence des donnees et joue les 10 batailles.
##
## Lancement :
##   godot --headless --path . tools/smoke_test.tscn
##
## Ne fait pas partie du jeu : c'est un outil de developpement. Il sert surtout
## a detecter les combats qui ne se terminent pas et les batailles impossibles
## a peupler apres un reglage dans Balance.
##

var _failures: int = 0


func _ready() -> void:
	print("=== KING'S GAMBIT - banc de test ===")
	_check_balance()
	_check_save()
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

	for type in Balance.UNIT_TYPES:
		var data: Dictionary = Balance.UNITS[type]
		var levels: int = data["levels"].size()
		if data["capacity"].size() != levels:
			_fail("%s : capacity a %d entrees pour %d niveaux" % [type, data["capacity"].size(), levels])
		if data["upgrade_cost"].size() != levels - 1:
			_fail("%s : upgrade_cost devrait avoir %d entrees" % [type, levels - 1])
		if data["upgrade_seconds"].size() != levels - 1:
			_fail("%s : upgrade_seconds devrait avoir %d entrees" % [type, levels - 1])

	var min_rows: int = Balance.DEPLOY_ROWS * 2 + 1
	for battle in Balance.CAMPAIGN:
		var cols := int(battle["cols"])
		var rows := int(battle["rows"])
		if rows < min_rows:
			_fail("bataille %d : %d rangees, minimum %d" % [int(battle["id"]), rows, min_rows])

		var enemy_count := 0
		for type in battle["enemies"].keys():
			enemy_count += int(battle["enemies"][type])
		var enemy_cells: int = cols * Balance.DEPLOY_ROWS
		if enemy_count > enemy_cells:
			_fail("bataille %d : %d ennemis pour %d cases" % [int(battle["id"]), enemy_count, enemy_cells])

	print("  %d unites, %d batailles verifiees" % [Balance.UNIT_TYPES.size(), Balance.battle_count()])


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

	# Amelioration : le timer doit repousser la fin dans le futur.
	Game.add_gold(5000)
	if not Game.start_upgrade(Balance.TOUR):
		_fail("amelioration du donjon refusee")
	if Game.upgrade_remaining(Balance.TOUR) <= 0:
		_fail("le compte a rebours d'amelioration est deja fini")
	Game.force_finish_upgrade(Balance.TOUR)
	if Game.building_level(Balance.TOUR) != 2:
		_fail("le donjon n'est pas passe niveau 2")

	Game.reset_progress()
	print("  or, recrutement, amelioration : OK")


# ------------------------------- BATAILLES -----------------------------------

func _play_all_battles() -> void:
	print("\n[3] Simulation des batailles")
	print("  Le joueur simule est suppose avoir suivi la progression normale :")
	print("  batailles 1-3 au niveau 1, 4-7 au niveau 2, 8-10 au niveau 3.")
	print("")

	var expected_wins := 0
	for battle in Balance.CAMPAIGN:
		var id := int(battle["id"])
		var player_level := 1
		if id >= 8:
			player_level = 3
		elif id >= 4:
			player_level = 2
		if _play_battle(battle, player_level, player_level):
			expected_wins += 1

	print("")
	print("  Batailles gagnables avec la progression attendue : %d / %d" % [
		expected_wins, Balance.battle_count()])
	if expected_wins < Balance.battle_count():
		_fail("la campagne n'est pas franchissable en jouant normalement")


## Joue une bataille avec un joueur au niveau donne. Retourne true si victoire.
func _play_battle(battle: Dictionary, castle_level: int, unit_level: int) -> bool:
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))

	# Armee ennemie
	var level := int(battle["level"])
	var cells: Array = engine.grid.free_enemy_cells()
	var enemy_count := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[enemy_count])
			enemy_count += 1

	# Armee du joueur : casernes pleines pour son niveau, deploiement en
	# alternant les types (comme le bouton Auto du jeu).
	var slots := Balance.deploy_slots(castle_level)
	var pool: Dictionary = {}
	for type in Balance.UNIT_TYPES:
		pool[type] = Balance.capacity(type, unit_level)

	var placed := 0
	var cursor := 0
	for y in range(engine.grid.rows - 1, engine.grid.player_zone_first_row() - 1, -1):
		for x in range(engine.grid.cols):
			if placed >= slots:
				break
			var type := _pick_round_robin(pool, cursor)
			if type.is_empty():
				break
			engine.add_unit(type, unit_level, BattleUnit.TEAM_PLAYER, Vector2i(x, y))
			pool[type] = int(pool[type]) - 1
			cursor += 1
			placed += 1

	if placed == 0:
		_fail("bataille %d : aucune unite joueur placee" % int(battle["id"]))
		return false

	while not engine.finished:
		engine.step()

	var victory := engine.winner == BattleUnit.TEAM_PLAYER
	var survivors := engine.living(BattleUnit.TEAM_PLAYER).size() if victory \
		else engine.living(BattleUnit.TEAM_ENEMY).size()

	print("  Bataille %2d  %-20s  Nv.%d  %2d vs %2d  ->  %s (%d survivants, %d activations)" % [
		int(battle["id"]), String(battle["name"]), unit_level, placed, enemy_count,
		"VICTOIRE" if victory else "defaite", survivors, engine.activation_count
	])

	if engine.activation_count >= int(Balance.COMBAT["max_activations"]):
		_fail("bataille %d : limite d'activations atteinte (combat bloque ?)" % int(battle["id"]))

	return victory


# ------------------------------- SCENES --------------------------------------

## Instancie chaque ecran pour verifier les chemins de noeuds et les _ready().
func _check_scenes() -> void:
	print("\n[4] Chargement des ecrans")

	Game.reset_progress()
	Router.current_battle_id = 1

	for path in [Router.VILLAGE_SCENE, Router.PREP_SCENE, Router.BATTLE_SCENE]:
		var packed: PackedScene = load(path)
		if packed == null:
			_fail("scene introuvable : %s" % path)
			continue
		var instance: Node = packed.instantiate()
		if instance == null:
			_fail("instanciation impossible : %s" % path)
			continue
		add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame
		print("  %s : OK" % path.get_file())
		instance.queue_free()
		await get_tree().process_frame


# ------------------------------- BOUCLE DE JEU -------------------------------

## Verifie le circuit complet : victoire -> or -> bataille suivante debloquee.
func _check_campaign_loop() -> void:
	print("\n[5] Boucle de progression")

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

	# La sauvegarde doit survivre a un rechargement complet.
	Game._load()
	if Game.unlocked_battle() != 2:
		_fail("la progression n'a pas ete relue depuis le disque")

	print("  victoire, recompense, deblocage, relecture disque : OK")
	Game.reset_progress()


## Alterne les types pour obtenir une armee variee plutot qu'un mur de pions.
func _pick_round_robin(pool: Dictionary, cursor: int) -> String:
	var types: Array = Balance.UNIT_TYPES
	for offset in range(types.size()):
		var type: String = types[(cursor + offset) % types.size()]
		if int(pool[type]) > 0:
			return type
	return ""
