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

	# Ouvrir la caserne des pions (label cliquable, pas un Button - cf. village.gd)
	_check(village._building_buttons.has(Balance.PION), "le label de la caserne existe")
	village._on_building_pressed(Balance.PION)
	await _frames(3)
	_check(is_instance_valid(village._popup), "le popup de batiment s'ouvre")
	if not is_instance_valid(village._popup):
		village.queue_free()
		return

	# Recruter
	var gold_before := Game.gold
	var owned_before := Game.units_owned(Balance.PION)
	var cost := Game.recruit_cost(Balance.PION)
	var recruit := _find_clickable(village._popup, "RECRUTER")
	_check(recruit != null, "le bouton Recruter est present")
	if recruit != null:
		_press(recruit)
		await _frames(3)
		_check(Game.units_owned(Balance.PION) == owned_before + 1, "le pion est ajoute a l'armee")
		_check(Game.gold == gold_before - cost, "l'or est debite du bon montant (%d)" % cost)

	# Ameliorer : l'or doit suffire
	Game.add_gold(5000)
	await _frames(2)
	var upgrade := _find_clickable(village._popup, "AMELIORER")
	_check(upgrade != null, "le bouton Ameliorer est present")
	if upgrade != null:
		_press(upgrade)
		await _frames(3)
		_check(Game.is_upgrading(Balance.PION), "l'amelioration demarre")
		_check(Game.upgrade_remaining(Balance.PION) > 0, "le compte a rebours est arme")

		# Le raccourci de test doit appliquer le niveau
		var skip := _find_clickable(village._popup, "Terminer")
		_check(skip != null, "le bouton de fin immediate est present")
		if skip != null:
			_press(skip)
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

	# Fermeture (croix de la modale, cf. scenes/ui/components/modal.gd)
	var modal: Modal = village._popup.get_node("Modal")
	_check(modal != null, "la modale du popup est presente")
	if modal != null:
		modal.close()
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
	var weight := 0
	for unit in battle._placed:
		weight += Balance.deploy_weight(unit.type)
	_check(weight <= Game.deploy_capacity(), "la charge posee respecte la limite du chateau")

	# Reinitialiser puis replacer
	battle._on_reset_placement()
	await _frames(2)
	_check(battle._placed.is_empty(), "Reinitialiser vide la grille")
	battle._on_auto_place()
	await _frames(2)
	_check(battle._placed.size() == placed, "le replacement redonne le meme effectif")

	# Repositionnement au doigt : une piece posee glisse vers une case libre
	# de la zone de deploiement.
	var moved: BattleUnit = battle._placed[0]
	var free_cells: Array = battle._engine.grid.free_player_cells()
	if not free_cells.is_empty():
		var target: Vector2i = free_cells[0]
		battle._on_piece_dropped(moved.cell, target)
		await _frames(2)
		_check(moved.cell == target, "glisser une piece posee la repositionne")
		_check(battle._placed.size() == placed, "le repositionnement ne cree ni ne perd d'unite")

	# Le point i : les regles doivent etre accessibles depuis le plateau, et
	# le bareme des poids y figurer - c'est le seul endroit du jeu ou on peut
	# le lire.
	battle._open_help()
	await _frames(3)
	var help: Modal = null
	for child in battle.get_children():
		if child is Modal:
			help = child
	_check(help != null, "le point i ouvre l'aide")
	if help != null:
		_check(_contains_text(help, "SURVEILLE LA CHARGE"), "l'aide explique la charge")
		_check(_contains_text(help, "POIDS"), "l'aide dit que la charge est un poids")
		help.close()
		await _frames(3)

	# Combat : le joueur joue lui-meme son premier coup
	var gold_before := Game.gold
	battle._speed = 4.0
	battle._start_combat()
	_check(battle._phase == 1, "le combat demarre")
	_check(battle._engine.current_team == BattleUnit.TEAM_PLAYER, "le joueur ouvre la bataille")

	# Selection d'une piece : ses coups legaux doivent s'allumer sur la grille.
	var mine: BattleUnit = battle._engine.living(BattleUnit.TEAM_PLAYER)[0]
	for candidate in battle._engine.living(BattleUnit.TEAM_PLAYER):
		if not battle._engine.legal_moves(candidate).is_empty():
			mine = candidate
			break
	battle._on_cell_pressed(mine.cell)
	await _frames(2)
	_check(battle._selected_unit == mine, "taper une piece la selectionne")
	_check(not battle._grid_view.legal_targets.is_empty(), "ses coups legaux sont surlignes")

	# Coup illegal : rien ne doit bouger.
	var illegal := Vector2i(mine.cell.x, mine.cell.y)
	battle._try_player_move(mine, illegal)
	await _frames(2)
	_check(mine.cell == illegal, "un coup illegal ne deplace rien")

	# Coup legal, puis reponse de l'IA.
	var destination: Vector2i = battle._engine.legal_moves(mine)[0]
	var turn_before: int = battle._engine.turn
	battle._on_piece_dropped(mine.cell, destination)
	await _frames(6)
	_check(mine.cell == destination, "le glisser-deposer joue le coup du joueur")

	var wait_ai := 0
	while battle._engine.turn == turn_before and battle._phase == 1 and wait_ai < 600:
		await get_tree().process_frame
		wait_ai += 1
	_check(battle._engine.turn > turn_before or battle._phase == 2, "l'IA repond et le tour avance")

	# Le reste de la bataille est confie a la resolution automatique.
	battle._on_auto_pressed()
	_check(battle._auto, "le bouton AUTO enclenche la resolution automatique")

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
		_check(_find_clickable(battle, "BATAILLE SUIVANTE") != null, "le bouton Bataille suivante existe")
	else:
		_check(Game.gold == gold_before, "aucune recompense en cas de defaite")
		_check(_find_clickable(battle, "REESSAYER") != null, "le bouton Reessayer existe")

	_check(_find_clickable(battle, "RETOUR AU VILLAGE") != null, "le retour au village est propose")

	battle.queue_free()
	await _frames(2)
	Game.reset_progress()


# ------------------------------- OUTILS --------------------------------------

## Retrouve un element cliquable par son texte, qu'il s'agisse d'un vrai
## Button ou d'un PanelContainer habille en bouton - la Phase 2 a remplace la
## plupart des Button par des panneaux, pour poser une icone vectorielle a
## cote du texte (cf. _icon_button dans battle.gd).
##
## La comparaison ignore la casse et les accents : le texte affiche est
## "RECRUTER" ou "RESSAYER", les tests parlent en clair.
func _find_clickable(root: Node, text: String) -> Control:
	var wanted := _normalize(text)
	for child in root.get_children():
		if child is Button and _normalize(String(child.text)).begins_with(wanted):
			return child
		# Un panneau cliquable est un panneau qui ECOUTE : sans ce filtre, on
		# retomberait sur la carte qui l'entoure, dont le titre commence
		# souvent par le meme mot que le bouton ("RECRUTER PION" / "RECRUTER").
		var listens: bool = child is PanelContainer and not child.gui_input.get_connections().is_empty()
		if listens and _panel_text(child).begins_with(wanted):
			return child
		var found := _find_clickable(child, text)
		if found != null:
			return found
	return null


## Vrai si un Label quelque part sous ce noeud contient ce texte (casse et
## accents ignores).
func _contains_text(root: Node, needle: String) -> bool:
	var wanted := _normalize(needle)
	for child in root.get_children():
		if child is Label and _normalize(String(child.text)).contains(wanted):
			return true
		if _contains_text(child, needle):
			return true
	return false


## Texte porte par le premier Label d'un panneau cliquable.
func _panel_text(panel: Node) -> String:
	for child in panel.get_children():
		if child is Label:
			return _normalize(String(child.text))
		var inner := _panel_text(child)
		if not inner.is_empty():
			return inner
	return ""


func _normalize(text: String) -> String:
	var out := text.to_upper()
	var accents := {
		"É": "E", "È": "E", "Ê": "E", "À": "A", "Â": "A", "Ç": "C",
		"Î": "I", "Ï": "I", "Ô": "O", "Û": "U", "Ù": "U",
	}
	for accented in accents.keys():
		out = out.replace(accented, String(accents[accented]))
	return out


## Declenche un clic sur un element trouve par _find_clickable.
func _press(node: Control) -> void:
	if node is Button:
		node.pressed.emit()
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	node.gui_input.emit(event)
