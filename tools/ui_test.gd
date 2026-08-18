extends Node
##
## TEST D'INTERFACE - appuie reellement sur les boutons du jeu.
##
## Le banc de test (smoke_test) verifie les regles ; celui-ci verifie que
## l'interface les declenche : ouvrir un batiment, recruter, ameliorer, jouer
## une bataille entiere et encaisser la recompense.
##
## Lancement :
##   godot --headless --path . tools/ui_test.tscn
##

var _failures: int = 0


func _ready() -> void:
	print("=== KING'S GAMBIT - test d'interface ===")
	await _test_village()
	await _test_battle()

	print("")
	if _failures == 0:
		print("RESULTAT : toutes les interactions repondent correctement.")
	else:
		print("RESULTAT : %d probleme(s) detecte(s)." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		_failures += 1
		print("  ECHEC %s" % label)


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


# ------------------------------- VILLAGE -------------------------------------

func _test_village() -> void:
	print("\n[1] Village : ouvrir un batiment, recruter, ameliorer")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	# Ouvrir la caserne des pions
	var building_button: Button = village._building_buttons[Balance.PION]
	building_button.pressed.emit()
	await _frames(3)
	_check(is_instance_valid(village._popup), "le popup de batiment s'ouvre")
	if not is_instance_valid(village._popup):
		village.queue_free()
		return

	# Recruter
	var gold_before := Game.gold
	var owned_before := Game.units_owned(Balance.PION)
	var cost := Game.recruit_cost(Balance.PION)
	var recruit := _find_button(village._popup, "Recruter")
	_check(recruit != null, "le bouton Recruter est present")
	if recruit != null:
		recruit.pressed.emit()
		await _frames(3)
		_check(Game.units_owned(Balance.PION) == owned_before + 1, "le pion est ajoute a l'armee")
		_check(Game.gold == gold_before - cost, "l'or est debite du bon montant (%d)" % cost)

	# Ameliorer : l'or doit suffire
	Game.add_gold(5000)
	await _frames(2)
	var upgrade := _find_button(village._popup, "Ameliorer")
	_check(upgrade != null, "le bouton Ameliorer est present")
	if upgrade != null:
		upgrade.pressed.emit()
		await _frames(3)
		_check(Game.is_upgrading(Balance.PION), "l'amelioration demarre")
		_check(Game.upgrade_remaining(Balance.PION) > 0, "le compte a rebours est arme")

		# Le raccourci de test doit appliquer le niveau
		var skip := _find_button(village._popup, "Terminer")
		_check(skip != null, "le bouton de fin immediate est present")
		if skip != null:
			skip.pressed.emit()
			await _frames(3)
			_check(Game.building_level(Balance.PION) == 2, "la caserne passe niveau 2")
			_check(not Game.is_upgrading(Balance.PION), "l'amelioration est cloturee")

	# Capacite : le recrutement doit se bloquer une fois la caserne pleine
	var capacity := Balance.capacity(Balance.PION, Game.building_level(Balance.PION))
	while Game.units_owned(Balance.PION) < capacity:
		if not Game.recruit(Balance.PION):
			break
	_check(Game.is_at_capacity(Balance.PION), "la caserne atteint sa capacite (%d)" % capacity)
	_check(not Game.recruit(Balance.PION), "le recrutement est refuse caserne pleine")

	# Fermeture
	var close := _find_button(village._popup, "Fermer")
	if close != null:
		close.pressed.emit()
		await _frames(3)
		_check(not is_instance_valid(village._popup), "le popup se ferme")

	village.queue_free()
	await _frames(2)


# ------------------------------- BATAILLE ------------------------------------

func _test_battle() -> void:
	print("\n[2] Bataille : placement, combat, recompense")

	Game.reset_progress()
	Router.current_battle_id = 1
	var data := Balance.battle(1)

	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await _frames(3)

	_check(battle._phase == 0, "la bataille demarre en phase de placement")
	_check(battle._engine.living(BattleUnit.TEAM_ENEMY).size() > 0, "l'armee ennemie est en place")

	# Placement automatique
	battle._on_auto_place()
	await _frames(2)
	var placed: int = battle._placed.size()
	_check(placed > 0, "le placement automatique pose %d unites" % placed)
	_check(placed <= Game.deploy_slots(), "le nombre d'unites respecte la limite du chateau")

	# Reinitialiser puis replacer
	battle._on_reset_placement()
	await _frames(2)
	_check(battle._placed.is_empty(), "Reinitialiser vide la grille")
	battle._on_auto_place()
	await _frames(2)
	_check(battle._placed.size() == placed, "le replacement redonne le meme effectif")

	# Combat en vitesse maximale
	var gold_before := Game.gold
	battle._speed = 4.0
	battle._start_combat()
	_check(battle._phase == 1, "le combat demarre")

	var guard := 0
	while battle._phase != 2 and guard < 8000:
		await get_tree().process_frame
		guard += 1
	_check(battle._phase == 2, "le combat se termine et affiche le resultat")

	var victory: bool = battle._engine.winner == BattleUnit.TEAM_PLAYER
	print("  ---> issue : %s" % ("victoire" if victory else "defaite"))
	if victory:
		_check(Game.gold == gold_before + int(data["reward"]),
			"la recompense de %d or est creditee" % int(data["reward"]))
		_check(Game.unlocked_battle() == 2, "la bataille 2 est debloquee")
		_check(_find_button(battle, "Bataille suivante") != null, "le bouton Bataille suivante existe")
	else:
		_check(Game.gold == gold_before, "aucune recompense en cas de defaite")
		_check(_find_button(battle, "Reessayer") != null, "le bouton Reessayer existe")

	_check(_find_button(battle, "Retour au village") != null, "le retour au village est propose")

	battle.queue_free()
	await _frames(2)
	Game.reset_progress()


# ------------------------------- OUTILS --------------------------------------

func _find_button(root: Node, prefix: String) -> Button:
	for child in root.get_children():
		if child is Button and String(child.text).begins_with(prefix):
			return child
		var found := _find_button(child, prefix)
		if found != null:
			return found
	return null
