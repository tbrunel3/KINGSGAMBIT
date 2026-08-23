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

const Driver := preload("res://tools/battle_driver.gd")

var _failures: int = 0


func _ready() -> void:
	# Un banc ne joue pas la mise en scene : sans ca, chaque changement
	# d'ecran ajoute un fondu complet et le banc ralentit sans rien
	# mesurer de plus. Meme doctrine que BattleAI.budget_ms = 0.
	ScreenVeil.instant = true
	# Idem : la regle d'abandon s'applique, mais sans modale a attendre.
	Router.ask_before_leaving = false
	print("=== KING'S GAMBIT - test d'interface ===")
	await _test_village()
	await _test_codex()
	await _test_battle()
	await _test_composition()
	await _test_series_chaining()
	await _test_shop()
	await _test_modal_entry()
	await _test_shop_entry()
	await _test_result_entries()
	await _test_mission_claim()
	await _test_guide_popups()
	await _test_campaign_drag()

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


## Pousse toutes les animations en cours jusqu'a leur fin.
##
## ⚠️ INDISPENSABLE DEPUIS QUE LE VILLAGE ZOOME. Ouvrir un batiment ne pose
## plus le popup tout de suite : le decor zoome d'abord vers le point touche
## (0,35 s), et le popup n'arrive qu'apres. Un banc qui regarde trois images
## apres le clic ne voit donc RIEN, et conclut que le bouton ne repond pas.
##
## Meme reflexe que screenshot.tscn et resolutions.tscn : on saute a la fin des
## tweens plutot que d'attendre - c'est instantane, et c'est exact.
func _skip_animations() -> void:
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(10.0)
	await get_tree().process_frame


## Tous les boutons batis par le composant partage, dans un ecran.
func _corner_buttons(root: Node) -> Array[Control]:
	var script := load("res://scenes/ui/components/corner_button.gd")
	var found: Array[Control] = []
	for node in root.find_children("*", "Control", true, false):
		if node.get_script() == script:
			found.append(node)
	return found


## L'ENTREE DE MODALE, une seule fois pour six appelants.
##
## Une modale qui apparait d'un coup se lit comme un bug d'affichage. Ce test
## ne juge pas l'esthetique : il verifie que l'entree EXISTE (la modale part
## transparente et rapetissee) et qu'elle SE TERMINE (elle finit opaque et a
## l'echelle 1). Une entree qui ne se termine pas laisserait un ecran a moitie
## la, et aucune capture ne le dirait.
func _test_modal_entry() -> void:
	print("\n[8] Modales : l'entree se joue, et elle se termine")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	village._on_building_pressed(Balance.PION)
	# Le zoom du village d'abord, la modale ensuite.
	await _skip_animations()
	await _frames(2)

	var modal: Modal = village._popup.find_child("Modal", true, false)
	if modal == null:
		_check(false, "la modale du popup de batiment est introuvable")
		village.queue_free()
		return

	var panel: Control = modal.get_node("Center/Panel")
	_check(panel.modulate.a < 0.9, "la modale part transparente (%.2f)" % panel.modulate.a)
	_check(panel.scale.x < 0.99, "et rapetissee (%.3f)" % panel.scale.x)

	await _skip_animations()
	await _frames(2)
	_check(panel.modulate.a > 0.99, "elle finit opaque (%.2f)" % panel.modulate.a)
	_check(absf(panel.scale.x - 1.0) < 0.01, "et a l'echelle 1 (%.3f)" % panel.scale.x)

	village.queue_free()
	await _frames(2)


## LA CASCADE DE LA BOUTIQUE - et surtout : elle ne se rejoue PAS a l'achat.
##
## L'ecran se reconstruit en entier a chaque gemme depensee. Une entree qui se
## rejouerait ferait re-tomber toute la boutique dans le dos du joueur au
## moment ou il achete. C'est le vrai risque de cette animation, et c'est ce
## que ce test garde.
func _test_shop_entry() -> void:
	print("\n[9] Boutique : la cascade s'ouvre une fois, et une seule")

	Game.reset_progress()
	Game.add_gems(2000)
	var shop: Node = load("res://scenes/village/shop.tscn").instantiate()
	add_child(shop)
	await _frames(4)

	var faded := 0
	for section in shop._sections:
		if section.modulate.a < 0.9:
			faded += 1
	_check(faded > 0, "la boutique part en fondu (%d sections)" % faded)

	await _skip_animations()
	await _frames(2)
	var late := 0
	for section in shop._sections:
		if section.modulate.a < 0.99 or absf(section.scale.x - 1.0) > 0.01:
			late += 1
	_check(late == 0, "tout est en place a la fin (%d en retard)" % late)

	# Un achat reconstruit l'ecran : la cascade ne doit pas repartir.
	Game.add_gold(50000)
	Game.start_upgrade(Balance.CASTLE)
	await _frames(3)
	shop._on_buy_chest(Balance.shop_chest("rare"))
	await _frames(5)
	var replayed := 0
	for section in shop._sections:
		if is_instance_valid(section) and section.modulate.a < 0.99:
			replayed += 1
	_check(replayed == 0, "elle ne se rejoue pas a l'achat (%d relancees)" % replayed)

	shop.queue_free()
	await _frames(2)


## LES TROIS ECRANS DE RESULTAT ONT TROIS ENTREES, et le jeu n'en jouait
## qu'une - celle du match nul, sur les trois peaux.
##
## Ce test ne juge pas l'esthetique : il verifie que les trois timelines sont
## bel et bien DIFFERENTES, et dans le bon sens. Une regression les aplatirait
## sans qu'aucune capture ne le montre, puisqu'une capture attend la fin des
## tweens.
func _test_result_entries() -> void:
	print("\n[10] Resultats : trois ecrans, trois entrees")

	var script := load("res://scenes/battle/battle_result.gd")
	_check(script.ENTRY.size() == 3, "trois timelines declarees (%d)" % script.ENTRY.size())

	var win: Dictionary = script.ENTRY["win"]
	var loss: Dictionary = script.ENTRY["loss"]
	var draw: Dictionary = script.ENTRY["draw"]

	_check(float(win["title_scale"]) < 1.0,
		"la victoire jaillit du petit (%.2f)" % float(win["title_scale"]))
	_check(float(win["title_rise"]) > 0.0,
		"et elle monte (%.0f)" % float(win["title_rise"]))
	_check(float(loss["title_rise"]) < 0.0,
		"la defaite tombe d'en haut (%.0f)" % float(loss["title_rise"]))
	_check(int(loss["title_trans"]) != Tween.TRANS_BACK,
		"et elle ne rebondit pas")
	_check(float(draw["title_scale"]) > 1.0,
		"le nul s'abat du grand (%.2f)" % float(draw["title_scale"]))
	_check(is_zero_approx(float(draw["title_rise"])), "et il ne bouge pas")
	_check(float(loss["buttons_delay"]) > float(win["buttons_delay"]),
		"la defaite est plus lente que la victoire (%.1f contre %.1f)"
			% [float(loss["buttons_delay"]), float(win["buttons_delay"])])

	# Et la peau choisit bien SA timeline.
	var screen: Node = script.new()
	add_child(screen)
	screen.open(true, "")
	await _frames(2)
	_check(screen._entry_key == "win", "la victoire prend la sienne (%s)" % screen._entry_key)
	screen.queue_free()
	await _frames(2)


## LE POPUP DE MISSIONS PORTE DEUX ANIMATIONS, pas une.
##
## La maquette les met dans une seule timeline parce que Figma ne sait pas dire
## "au clic". Les porter ensemble ferait voler les pieces a l'OUVERTURE, sans
## que le joueur ait rien reclame - et c'est exactement l'erreur que ce test
## empeche.
func _test_mission_claim() -> void:
	print("\n[11] Missions : l'ouverture et la reclamation sont deux animations")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	village._on_missions_pressed()
	await _frames(3)
	var popup: Node = village._popup
	_check(is_instance_valid(popup), "le popup de missions s'ouvre")
	if not is_instance_valid(popup):
		village.queue_free()
		return

	_check(popup.purse != null, "il a recu la bourse du village")

	# A l'ouverture, RIEN de la reclamation ne doit avoir demarre.
	await _skip_animations()
	await _frames(2)
	_check(get_tree().root.find_child("CoinFlight", true, false) == null,
		"aucune piece ne vole tant que rien n'est reclame")

	# Les barres, elles, ont fait leur compte - chacune jusqu'a SA valeur.
	#
	# ⚠️ Sur une sauvegarde neuve la seule mission visible est a 0/1 : sa cible
	# EST zero. Verifier "la barre est remplie" ferait echouer un code juste -
	# c'est ce que la premiere version de ce test faisait.
	var wrong := 0
	for entry in popup._fills:
		var fill: Control = entry["node"]
		if is_instance_valid(fill) and absf(fill.anchor_right - float(entry["target"])) > 0.01:
			wrong += 1
	_check(wrong == 0, "les %d barres ont atteint leur cible (%d en ecart)"
		% [popup._fills.size(), wrong])

	village.queue_free()
	await _frames(2)


## LES POPUPS D'ACCOMPAGNEMENT - chantier E.
##
## Ce test garde les deux regles de forme, qui sont tout ce qui les rend
## supportables : chacun se montre UNE FOIS, et aucun n'ecrit ses chiffres en
## dur.
func _test_guide_popups() -> void:
	print("
[12] Accompagnement : chaque popup se montre une fois")

	Game.reset_progress()
	var host := Control.new()
	add_child(host)
	await _frames(2)

	for key in [GuidePopup.STALEMATE, GuidePopup.LINEUP,
			GuidePopup.DAME_AURA, GuidePopup.REALTIME]:
		_check(not Game.has_seen_guide(key), "%s : jamais vu au depart" % key)
		_check(GuidePopup.show_once(host, key), "%s : s'ouvre la premiere fois" % key)
		await _frames(2)
		_check(not GuidePopup.show_once(host, key), "%s : ne se rouvre PAS" % key)

	# Et les chiffres viennent bien de Balance, pas du texte.
	var popup: Node = null
	for child in host.get_children():
		if child is GuidePopup:
			popup = child
			break
	_check(popup != null, "les popups vivent bien dans l'arbre")

	# ⚠️ AUCUN CHIFFRE ECRIT DANS LE TEXTE : la charge et le pourcentage de
	# l'aura sont relus dans Balance a l'affichage. Un popup qui les
	# transcrirait se mettrait a mentir des qu'on regle le jeu - c'est
	# exactement ce qui avait produit le codex faux.
	var source := FileAccess.get_file_as_string("res://scenes/ui/guide_popup.gd")
	_check(source.contains("Game.deploy_capacity()"),
		"la charge est relue, pas transcrite")
	_check(source.contains("Balance.DAME_GOLD_BONUS"),
		"l'aura est relue, pas transcrite")
	_check(source.contains("Balance.deploy_weight"),
		"les poids sont relus, pas transcrits")

	host.queue_free()
	await _frames(2)


# ------------------------------- VILLAGE -------------------------------------

func _test_village() -> void:
	print("\n[1] Village : ouvrir un batiment, recruter, ameliorer")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	# Ouvrir la caserne des pions (label cliquable, pas un Button - cf. village.gd)
	_check(village._building_buttons.has(Balance.PION), "le label de la caserne existe")

	# LES BOUTONS DE COIN : deux tailles, plus six.
	#
	# Ce test ne regarde pas a quoi ils ressemblent - il verifie qu'aucun ne
	# revient a une taille inventee, et qu'ils repondent toujours. Une reprise
	# graphique qui casse un bouton ne se voit sur aucune capture.
	const CornerButton := preload("res://scenes/ui/components/corner_button.gd")
	var corners := _corner_buttons(village)
	_check(corners.size() >= 3,
		"le village porte au moins trois boutons de coin (%d)" % corners.size())
	for button in corners:
		_check(button.size.x == CornerButton.FLOATING_SIZE
				or button.size.x == CornerButton.BACK_SIZE
				or button.size.x == 45.0,
			"%s : taille %.0f (34, 52, ou 45 pour la boutique)"
				% [button.name, button.size.x])
	_check(is_instance_valid(village._codex_button), "le bouton codex repond encore")
	_check(is_instance_valid(village._shop_button), "le bouton boutique repond encore")

	# LE BOUTON DE DEVELOPPEMENT A QUITTE L'ECRAN, mais pas le jeu : le joueur
	# teste sur le build web EXPORTE, donc en release, et un masquage en debug
	# lui retirerait son seul raccourci.
	_check(village.find_child("DevGesture", true, false) != null,
		"la zone de geste du panneau dev existe")
	_check(village.find_child("DevButton", true, false) == null,
		"le bouton dev n'est plus a l'ecran")
	# La zone doit s'arreter AU-DESSUS de la barre haute, sinon elle vole ses
	# taps a l'engrenage.
	var gesture: Control = village.find_child("DevGesture", true, false)
	if gesture != null:
		_check(gesture.get_global_rect().end.y <= village.TOP_BAR_Y,
			"elle ne mord pas sur la barre haute (%.0f <= %.0f)"
				% [gesture.get_global_rect().end.y, village.TOP_BAR_Y])

	# Et l'ACCES survit : c'est tout l'interet du geste plutot que du masquage
	# en build de debug.
	village._on_dev_pressed()
	await _frames(3)
	_check(is_instance_valid(village._popup), "le panneau dev s'ouvre encore")
	if is_instance_valid(village._popup):
		village._popup.queue_free()
		village._popup = null
		await _frames(2)

	# LES BATIMENTS EUX-MEMES SONT CLIQUABLES, pas seulement leurs enseignes.
	# Les zones vivent sur le calque de decor : elles suivent l'illustration,
	# donc elles tombent sur le bon batiment quel que soit le format.
	var hitboxes := village.find_children("Hitbox_*", "Control", true, false)
	_check(hitboxes.size() == 5,
		"les cinq batiments portent une zone de clic (%d)" % hitboxes.size())
	for zone in hitboxes:
		_check(zone.size.x > 0.0 and zone.size.y > 0.0,
			"%s a une surface (%.0f x %.0f)" % [zone.name, zone.size.x, zone.size.y])

	village._on_building_pressed(Balance.PION)
	await _skip_animations()
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

		# L'AMELIORATION SE CONFIRME depuis la revision de l'ecran : elle engage a
		# la fois de l'or et des heures de temps reel, et c'est la seule action du
		# village a le faire. Le banc doit donc suivre le vrai parcours - sans quoi
		# il ne teste plus ce que le joueur fait.
		_check(not Game.is_upgrading(Balance.PION),
			"rien ne demarre tant que la confirmation n'est pas donnee")
		var confirm := _find_clickable(get_tree().root, "CONFIRMER")
		_check(confirm != null, "la modale de confirmation s'ouvre")
		if confirm != null:
			_press(confirm)
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

	# Les missions : le bouton de la barre du haut ouvre le panneau, et une
	# mission terminee se reclame d'un clic. A tester popup de batiment ferme,
	# le village n'en affichant qu'un a la fois.
	Game.record_battle(true, 0, 3, 0)
	await _frames(3)
	village._on_missions_pressed()
	await _frames(3)
	_check(is_instance_valid(village._popup), "le bouton MISSIONS ouvre le panneau")
	if is_instance_valid(village._popup):
		var claim := _find_clickable(village._popup, "RECLAMER")
		_check(claim != null, "une mission terminee propose de reclamer")
		if claim != null:
			var before_claim := Game.gold
			_press(claim)
			await _frames(4)
			_check(Game.gold > before_claim, "reclamer une mission verse l'or")
			# La mission suivante peut etre deja remplie (le test a recrute
			# plus haut) : ce qui compte est que celle qu'on vient d'encaisser
			# disparaisse.
			var first_id := String(Balance.MISSIONS[0]["id"])
			var still_listed := false
			for mission in Game.missions_visible():
				if String(mission["id"]) == first_id:
					still_listed = true
			_check(Game.is_mission_claimed(first_id) and not still_listed,
				"la mission reclamee quitte la liste")
			_check(not Game.missions_visible().is_empty(), "la mission suivante se devoile")

	village.queue_free()
	await _frames(2)


# ------------------------------- CODEX ---------------------------------------

## Le codex se REGENERE depuis Balance a chaque ouverture (cf. codex_popup.gd).
## Ce test ne relit pas ses chiffres un par un - il verifie qu'il en produit
## autant que le jeu a de pieces, et surtout que les mots de l'ancienne
## maquette, qui decrivaient un autre jeu, n'y sont jamais revenus.
func _test_codex() -> void:
	print("\n[2] Codex : une carte par piece, et rien de l'autre jeu")

	Game.reset_progress()
	var codex: Node = load("res://scenes/village/codex_popup.tscn").instantiate()
	add_child(codex)
	await _frames(3)

	var body: Node = codex.get_node("Safe/Root/Scroll/Body")
	# Une carte par piece de l'armee, plus la section des batiments et celle
	# des regles.
	_check(body.get_child_count() == Balance.ARMY_TYPES.size() + 2,
		"le codex affiche %d cartes + 2 sections" % Balance.ARMY_TYPES.size())

	var texte := _collect_text(codex)
	for word in ["PV", "ATK", "Roque", "Cathédrale", "Donjon de Fer", "Académie",
			"Chapelle", "8 × 11", "×2", "Bouclier"]:
		_check(texte.find(word) < 0, "le codex ne dit nulle part \"%s\"" % word)

	# Les vrais chiffres du jeu, pris a la source : s'ils manquent, le codex a
	# cesse de lire Balance.
	var last := Balance.move_description(Balance.CAVALIER, Balance.MAX_LEVEL)
	_check(texte.find(last) >= 0, "la mobilite du cavalier au niveau max y figure")
	_check(texte.find("%d" % Balance.deploy_capacity(Balance.MAX_LEVEL)) >= 0,
		"la charge maximale du chateau y figure")

	# Le filtre : une seule carte, et plus de sections.
	codex._on_filter(Balance.DAME)
	await _frames(2)
	_check(body.get_child_count() == 1, "filtrer sur la Dame ne laisse qu'une carte")

	codex.queue_free()
	await _frames(2)


## Tout le texte affiche par un ecran, mis bout a bout.
##
## Les BOUTONS en font partie. Ils ont ete oublies au depart, et ca ne se
## voyait pas : un test qui verifie l'ABSENCE d'un mot passait alors meme
## quand ce mot etait ecrit sur un bouton, en plein milieu de l'ecran.
func _collect_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	for child in node.get_children():
		out += _collect_text(child)
	return out


# ------------------------------- BATAILLE ------------------------------------

func _test_battle() -> void:
	print("\n[3] Bataille : placement, combat, recompense")

	Game.reset_progress()
	Router.current_battle_id = 1
	var data := Balance.battle(1)

	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await _frames(3)

	_check(battle._phase == 0, "la bataille demarre en phase de placement")
	_check(battle._engine.living(BattleUnit.TEAM_ENEMY).size() > 0, "l'armee ennemie est en place")

	# Placement automatique (pilote de test : le jeu ne le propose plus)
	Driver.auto_place(battle)
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
	Driver.auto_place(battle)
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

	# Le reste de la bataille est confie au pilote de test. Il n'y a plus de
	# bouton pour ca dans le jeu : c'est le joueur qui joue, toujours.
	Driver.resolve(battle)

	var guard := 0
	while battle._phase != 2 and guard < 8000:
		await get_tree().process_frame
		guard += 1
	_check(battle._phase == 2, "le combat se termine et affiche le resultat")

	var victory: bool = battle._engine.winner == BattleUnit.TEAM_PLAYER
	var drawn: bool = battle._engine.is_draw()
	print("  ---> issue : %s" % ("nul" if drawn else ("victoire" if victory else "defaite")))

	# UN COMBAT N'EST PAS UNE BATAILLE. Un niveau de campagne se joue en
	# plusieurs combats d'affilee (cf. CampaignRun) : gagner le premier ne
	# paie rien et ne debloque rien - tout attend la fin de la serie.
	var fights := Balance.battle_fights(data)
	if victory and fights == 1:
		# Les premieres batailles se jouent en un seul combat : la victoire
		# paie et debloque tout de suite, sans serie a poursuivre.
		_check(Game.gold == gold_before + int(data["reward"]),
			"la recompense de %d or est creditee" % int(data["reward"]))
		_check(Game.unlocked_battle() == 2, "la bataille 2 est debloquee")
		_check(_find_clickable(battle, "BATAILLE SUIVANTE") != null,
			"le bouton Bataille suivante existe")
		_check(Game.current_run() == null, "la serie d'un seul combat est cloturee")
	elif victory:
		_check(Game.gold == gold_before,
			"le premier combat gagne ne paie pas encore (serie de %d)" % fights)
		_check(Game.unlocked_battle() == 1,
			"la bataille 2 reste fermee tant que la serie n'est pas finie")
		_check(_find_clickable(battle, "COMBAT 2 SUR %d" % fights) != null,
			"le bouton enchaine sur le combat suivant")
		var run := Game.current_run(1)
		_check(run != null and run.fight == 2, "la serie est sauvegardee au combat 2")
		_check(run != null and run.reward == int(data["reward"]),
			"l'or du combat gagne est promis, pas verse")
	elif drawn:
		_check(Game.gold == gold_before, "un combat nul ne paie rien")
		if fights == 1:
			# ⚠️ CETTE ASSERTION A CHANGE AVEC LA REGLE, le 24/08/2026.
			#
			# Avant, un nul cloturait la serie et le bouton "REPRENDRE LA
			# SERIE" en rouvrait une neuve au combat 1 : le libelle promettait
			# de reprendre, le code recommencait, et le joueur l'a vu.
			#
			# Un nul REJOUE maintenant le meme combat, avec les survivants et
			# les blesses releves - un tour d'usure paye pour rien n'a pas a
			# faire avancer le compteur. La serie reste donc en cours, et le
			# plafond de Balance.RUN_DRAWS_ALLOWED est ce qui l'empeche de
			# devenir un abri.
			_check(_find_clickable(battle, "REJOUER LE COMBAT 1 SUR 1") != null,
				"un nul propose de rejouer LE MEME combat")
			var drawn_run := Game.current_run()
			_check(drawn_run != null, "le nul ne cloture PAS la serie")
			_check(drawn_run != null and drawn_run.fight == 1,
				"le combat nul se rejoue au meme numero")
			_check(drawn_run != null and drawn_run.draws == 1,
				"le nul est compte (1 sur %d)" % Balance.RUN_DRAWS_ALLOWED)
		else:
			_check(_find_clickable(battle, "COMBAT 2 SUR %d" % fights) != null,
				"un nul ne rompt pas la serie")
	else:
		_check(Game.gold == gold_before, "aucune recompense en cas de defaite")
		_check(_find_clickable(battle, "REPRENDRE LA SERIE") != null,
			"la defaite propose de reprendre la serie")

	_check(_find_clickable(battle, "ROYAUME") != null, "le retour au royaume est propose")
	_check(_find_clickable(battle, "CAMPAGNE") != null, "la carte de campagne est proposee")

	battle.queue_free()
	await _frames(2)
	Game.reset_progress()


# ------------------------------- SERIE ---------------------------------------

## Une serie ne se couronne qu'une fois. Un combat intermediaire gagne rend la
## main au suivant par un BANDEAU court - pas par un ecran de victoire, qui
## imposait trois clics pour un seul enjeu et vidait la victoire de son sens.
##
## Le combat est force plutot que joue : ce qui est teste ici est l'ENCHAINEMENT,
## et la bataille 2 peut tres bien finir nulle avec la formation de reference.
# ------------------------------- COMPOSITION ---------------------------------
#
#  L'ecran de preparation ne se contente plus d'annoncer : le joueur y COMPOSE
#  l'armee qui part, dans la limite de la charge du chateau. Ce que ce test
#  verifie vraiment est la derniere assertion : le placement ne propose QUE ce
#  qui a ete choisi. Sans elle, l'ecran serait de la decoration.

func _test_composition() -> void:
	print("")
	print("[4] Preparation : composer l'armee qui part au combat")

	Game.reset_progress()
	# On remplit la caserne au-dela de ce que la charge laissera partir : c'est
	# tout le propos du chantier. Recruter fait une RESERVE, la charge decide
	# de l'ARMEE - et le jeu ne montrait cette difference nulle part.
	while Game.units_owned(Balance.PION) < 10:
		Game.add_gold(Game.recruit_cost(Balance.PION))
		if not Game.recruit(Balance.PION):
			break
	var owned := Game.units_owned(Balance.PION)

	Router.current_battle_id = 1
	var prep: Node = load("res://scenes/battle/battle_prep.tscn").instantiate()
	add_child(prep)
	await _frames(3)

	_check(prep._chosen_weight() == 0, "la composition s'ouvre vide")
	_check(prep._cta.modulate.a < 1.0, "on ne part pas au combat sans une piece")
	_check(_contains_text(prep, "CASERNE"), "la caserne est affichee")
	_check(_contains_text(prep, "DEPLOIEMENT") or _contains_text(prep, "D\u00c9PLOIEMENT"),
		"le panneau de deploiement est affiche")

	# Les cartes sont RECONSTRUITES a chaque changement : on retrouve la carte
	# avant chaque tap, sinon on appuie sur un noeud deja libere.
	for i in range(3):
		var card := _find_clickable(prep, "PION")
		if card == null:
			break
		_press(card)
		await _frames(1)
	_check(int(prep._chosen.get(Balance.PION, 0)) == 3, "trois taps engagent trois pions")
	_check(prep._chosen_weight() == 3 * Balance.deploy_weight(Balance.PION),
		"la charge suit le POIDS des pieces, pas leur nombre")

	# Une case occupee renvoie sa piece a la caserne.
	var before := int(prep._chosen.get(Balance.PION, 0))
	if prep._slot_flow.get_child_count() > 0:
		_press(prep._slot_flow.get_child(0))
		await _frames(1)
	_check(int(prep._chosen.get(Balance.PION, 0)) == before - 1,
		"toucher une case posee renvoie la piece a la caserne")

	# On pousse jusqu'au refus, puis on renvoie deux pieces a la caserne : ce
	# qui compte n'est pas le maximum, c'est que la composition puisse etre
	# PLUS PETITE que la caserne - sinon l'ecran ne deciderait de rien.
	var capacity := Game.deploy_capacity()
	for i in range(60):
		var card := _find_clickable(prep, "PION")
		if card == null:
			break
		_press(card)
		await _frames(1)
	_check(prep._chosen_weight() <= capacity,
		"la charge ne se depasse pas (%d/%d)" % [prep._chosen_weight(), capacity])
	for i in range(2):
		if prep._slot_flow.get_child_count() > 0:
			_press(prep._slot_flow.get_child(0))
			await _frames(1)
	_check(int(prep._chosen.get(Balance.PION, 0)) < owned,
		"la caserne garde une reserve que la charge ne laisse pas partir")

	# Le mur de charge lui-meme se mesure sans l'ecran : au chateau Nv.1 la
	# caserne des pions plafonne a 8, et 8 pions ne pesent que 8 pour 16 de
	# charge. C'est la regle qu'on verifie, pas ce que l'ecran peut atteindre.
	var probe := CampaignRun.new()
	probe.roster = {Balance.PION: 999}
	probe.set_lineup({Balance.PION: 999}, capacity)
	_check(probe.lineup_weight() == capacity,
		"la charge borne la composition quelle que soit la reserve")

	_check(_find_clickable(prep, "LANCER LE COMBAT") != null,
		"le bouton de depart est en place")

	# Verse la composition sans partir : declencher la navigation depuis un
	# banc emporterait le banc avec lui (cf. battle_prep._commit_lineup).
	_check(prep._commit_lineup(), "la composition se verse dans la serie")
	var chosen := int(prep._chosen.get(Balance.PION, 0))
	var run := Game.current_run(1)
	_check(run != null and int(run.lineup.get(Balance.PION, 0)) == chosen,
		"la serie retient la composition")
	prep.queue_free()
	await _frames(2)

	# LA verification du chantier : le placement ne propose que les pieces
	# choisies, alors que la caserne en contient davantage.
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await _frames(3)
	_check(int(battle._remaining.get(Balance.PION, 0)) == chosen,
		"le placement ne propose que les %d pions composes" % chosen)
	_check(Game.units_owned(Balance.PION) > chosen,
		"...alors que la caserne en compte %d" % Game.units_owned(Balance.PION))
	battle.queue_free()
	await _frames(2)


func _test_series_chaining() -> void:
	print("")
	print("[5] Serie : un combat gagne encha\u00eene sans ecran de victoire")

	Game.reset_progress()
	var battle_id := 0
	for id in range(1, Balance.battle_count() + 1):
		if Balance.battle_fights(Balance.battle(id)) > 1:
			battle_id = id
			break
	if battle_id == 0:
		print("  (aucune bataille en serie : rien a verifier)")
		return

	Router.current_battle_id = battle_id
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	await _frames(3)

	# L'avertissement s'ouvre a la premiere serie, et une seule fois.
	var popup: Node = null
	for child in battle.get_children():
		if child.get_script() != null and String(child.name).begins_with("SeriesPopup"):
			popup = child
	_check(popup != null, "la premiere serie s'explique dans un popup")
	_check(Game.has_seen_series_warning(), "l'avertissement ne se reverra plus")
	if popup != null:
		popup.queue_free()
		await _frames(2)

	Driver.auto_place(battle)
	await _frames(2)
	battle._start_combat()
	await _frames(2)

	# Victoire forcee : on retire l'armee ennemie, puis le joueur joue un coup,
	# ce qui declenche le verdict.
	for foe in battle._engine.living(BattleUnit.TEAM_ENEMY):
		foe.captured = true
		battle._engine.grid.remove_unit(foe)
	var mover: BattleUnit = null
	for unit in battle._engine.living(BattleUnit.TEAM_PLAYER):
		if not battle._engine.legal_moves(unit).is_empty():
			mover = unit
			break
	if mover == null:
		_check(false, "aucun coup jouable pour declencher la fin du combat")
		battle.queue_free()
		return
	battle._try_player_move(mover, battle._engine.legal_moves(mover)[0])

	var waited := 0
	while battle._phase != 2 and waited < 600:
		await get_tree().process_frame
		waited += 1

	var banner: Node = null
	var result: Node = null
	for child in battle.get_children():
		if child is SeriesBanner:
			banner = child
		elif child is BattleResult:
			result = child
	_check(banner != null, "le combat gagne affiche le bandeau d'enchainement")
	_check(result == null, "aucun ecran de victoire entre deux combats")

	var run := Game.current_run(battle_id)
	_check(run != null and run.fight == 2, "la serie est sauvegardee au combat 2")

	battle.queue_free()
	await _frames(2)


# ------------------------------- OUTILS --------------------------------------

## Retrouve un element cliquable par son texte, quelle que soit la classe qui
## lui sert d'habillage : un vrai Button, un PanelContainer habille en bouton
## (Phase 2), ou une RoyalPlate (V2, qui est un MarginContainer qui se
## dessine). Ce qui fait un bouton ici n'est pas son type, c'est qu'il
## ECOUTE - sans ce filtre on retomberait sur la carte qui l'entoure, dont le
## titre commence souvent par le meme mot ("RECRUTER PION" / "RECRUTER").
##
## La comparaison ignore la casse et les accents : le texte affiche est
## "RECRUTER" ou "RESSAYER", les tests parlent en clair.
func _find_clickable(root: Node, text: String) -> Control:
	var wanted := _normalize(text)
	for child in root.get_children():
		if child is Button and _normalize(String(child.text)).begins_with(wanted):
			return child
		var listens: bool = child is Control 			and not (child as Control).gui_input.get_connections().is_empty()
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


# ------------------------------- BOUTIQUE ------------------------------------

## La boutique : l'ecran s'ouvre, les coffres se ramassent, un achat sans
## gemmes est refuse, et un achat valide RACCOURCIT vraiment un chantier.
func _test_shop() -> void:
	print("\n[6] Boutique : ramasser, acheter, accelerer")

	Game.reset_progress()
	var shop: Node = load("res://scenes/village/shop.tscn").instantiate()
	add_child(shop)
	await _frames(4)

	var texte := _collect_text(shop)
	for word in ["BOUTIQUE", "COFFRES", "GEMMES", "OR"]:
		_check(texte.find(word) >= 0, "la section \"%s\" est affichee" % word)

	# Les euros n'existent pas tant qu'aucun store n'est branche.
	_check(texte.find("Bientôt") >= 0, "les packs en euros disent \"Bientôt\"")
	_check(texte.find("€") < 0, "aucun prix en euros n'est affiche")

	# La maquette portait un tableau de probabilites ; il n'y a aucun tirage
	# au sort dans ce jeu, et ce test empeche qu'il revienne par recopie.
	_check(texte.find("%") < 0, "aucun pourcentage de butin n'a survecu")
	_check(texte.find("termine tout") >= 0, "la legende annonce ce que fait le Legendaire")

	# --- ramasser un coffre gratuit --------------------------------------
	var gems_before := Game.gems
	shop._on_claim("horaire")
	await _frames(3)
	_check(Game.gems > gems_before, "le coffre horaire rend ses gemmes")
	_check(not Game.free_chest_ready("horaire"), "il ne se reprend pas dans la foulee")

	# --- acheter sans rien a accelerer ------------------------------------
	Game.add_gems(2000)
	Game.add_gold(50000)
	await _frames(3)
	var gems_kept := Game.gems
	shop._on_buy_chest(Balance.shop_chest("rare"))
	await _frames(2)
	_check(Game.gems == gems_kept, "un coffre ne se paie pas quand aucun chantier ne tourne")

	# --- acheter avec un seul chantier ouvert -----------------------------
	Game.start_upgrade(Balance.CASTLE)
	await _frames(2)
	var level_before := Game.building_level(Balance.CASTLE)
	gems_kept = Game.gems
	shop._on_buy_chest(Balance.shop_chest("rare"))
	await _frames(3)
	_check(Game.gems < gems_kept, "le coffre est debite")
	_check(Game.building_level(Balance.CASTLE) == level_before + 1,
		"une heure achetee termine le palier en cours du chateau")

	# --- un pack d'or ------------------------------------------------------
	var gold_before := Game.gold
	shop._on_buy_gold(0)
	await _frames(3)
	_check(Game.gold > gold_before, "le pack d'or verse son or")

	shop.queue_free()
	await _frames(2)

	# --- la porte d'entree au village -------------------------------------
	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)
	_check(is_instance_valid(village._shop_button), "le village porte une entree vers la boutique")
	village.queue_free()
	await _frames(2)


# ------------------------------- LA CARTE AU DOIGT ---------------------------

const CampaignScene := preload("res://scenes/battle/campaign.tscn")

## Faire glisser la carte en partant d'un CACHET doit la faire defiler, pas
## lancer la bataille.
##
## ⚠️ CE TEST N'EXISTAIT PAS, ET AUCUN BANC NE POUVAIT LE PASSER. _press()
## n'envoie qu'un APPUI, jamais de relachement : un banc qui ne sait pas lever
## le doigt ne peut pas distinguer un appui d'un geste. C'est exactement le
## defaut qu'il fallait attraper.
##
## ⚠️ ET _press() N'APPUYAIT SUR RIEN ICI. `gui_input` est un SIGNAL ; `_gui_input`
## est une methode VIRTUELLE. Emettre le signal n'appelle pas la virtuelle : le
## banc croyait presser campaign_seal, grid_view et series_banner, et ne pressait
## rien. Seuls les controles qui font `gui_input.connect(...)` explicitement -
## corner_button, selection_chip - repondaient. D'ou l'appel direct ci-dessous.
##
## Le cachet emettait `pressed` sur l'evenement ENFONCE, et campaign.gd lance
## _play_transition() dans la foulee : zoom, fondu au noir, changement d'ecran.
## Poser le doigt sur un cachet partait donc en bataille avant meme d'avoir
## bouge - et la carte porte dix cachets sur toute sa hauteur, exactement la ou
## le pouce se pose pour faire defiler.
func _test_campaign_drag() -> void:
	print("
[12] La carte de campagne au doigt")

	var screen: Control = CampaignScene.instantiate()
	add_child(screen)
	await _frames(3)
	await _skip_animations()

	var seal: Control = screen._nodes.get(1, null)
	_check(seal != null, "le cachet de la bataille 1 existe")
	if seal == null:
		screen.queue_free()
		return

	# 1. Poser le doigt sur un cachet ne doit RIEN lancer.
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = seal.size * 0.5
	seal._gui_input(down)
	await _frames(2)
	_check(not screen._transitioning,
		"poser le doigt sur un cachet ne lance pas la bataille")

	# 2. Le relever LOIN du point de depart : c'est un geste, pas un appui.
	var up_far := InputEventMouseButton.new()
	up_far.button_index = MOUSE_BUTTON_LEFT
	up_far.pressed = false
	up_far.position = seal.size * 0.5 + Vector2(0, 60)
	seal._gui_input(up_far)
	await _frames(2)
	_check(not screen._transitioning,
		"glisser depuis un cachet ne lance pas la bataille")

	# 3. LE DOIGT ET LA CARTE VONT A LA MEME VITESSE.
	#
	# ⚠️ Le defilement tactile de Godot ne suit PAS le doigt : il ajoute une
	# inertie au relachement, et sur le Web le geste peut etre compte deux fois
	# (le tactile emule aussi la souris). Le joueur l'a decrit apres test :
	# "ca defile mais ca devrait suivre le doigt, la ca va tres vite".
	#
	# L'attrapeur fixe scroll_vertical a la difference exacte parcourue. Ce
	# test est ce qui garantit le "exacte" - un pixel de doigt, un pixel de
	# carte, sans inertie ni double comptage.
	var catcher: Control = screen._drag_catcher
	_check(catcher != null, "l'attrapeur de geste existe")
	if catcher != null:
		screen._scroll.scroll_vertical = 200
		await _frames(1)
		var before: int = screen._scroll.scroll_vertical

		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = Vector2(180, 400)
		catcher.gui_input.emit(press)

		var slide := InputEventMouseMotion.new()
		slide.position = Vector2(180, 300)
		catcher.gui_input.emit(slide)
		await _frames(1)

		var moved: int = screen._scroll.scroll_vertical - before
		_check(moved == 100,
			"100 points de doigt deplacent la carte de 100 (%d)" % moved)

		var lift := InputEventMouseButton.new()
		lift.button_index = MOUSE_BUTTON_LEFT
		lift.pressed = false
		lift.position = Vector2(180, 300)
		catcher.gui_input.emit(lift)
		await _frames(1)
		_check(screen._scroll.scroll_vertical - before == 100,
			"la carte s'arrete net au relachement, sans inertie")

	# 4. Appuyer puis relever AU MEME ENDROIT : la, c'est un appui.
	seal._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = seal.size * 0.5
	seal._gui_input(up)
	await _frames(2)
	_check(screen._transitioning,
		"relever le doigt au meme endroit lance bien la bataille")

	# 4. TOUTE LA CHAINE doit laisser passer le geste jusqu'au ScrollContainer.
	#
	# ⚠️ Corriger le cachet seul N'A PAS SUFFI, et c'est le joueur qui l'a
	# signale apres coup : le noeud `Content` de campaign.tscn n'avait aucun
	# mouse_filter, donc STOP par defaut, et il avalait le geste avant le
	# ScrollContainer. La carte ne defilait NULLE PART, pas seulement sur les
	# cachets. Un seul maillon en STOP suffit a tout bloquer - d'ou une garde
	# sur la chaine entiere plutot que sur un noeud.
	var scroll: ScrollContainer = screen.get_node("Scroll")
	var blockers: Array[String] = []
	var node: Node = seal.get_parent()
	while node != null and node != scroll:
		var ctrl := node as Control
		if ctrl != null and ctrl.mouse_filter == Control.MOUSE_FILTER_STOP:
			blockers.append(ctrl.name)
		node = node.get_parent()
	_check(blockers.is_empty(),
		"aucun maillon n'avale le geste entre le cachet et la carte (%s)"
			% ("rien" if blockers.is_empty() else ", ".join(blockers)))
	_check(seal.mouse_filter == Control.MOUSE_FILTER_PASS,
		"le cachet laisse le geste remonter a la carte (PASS, pas STOP)")


	screen.queue_free()
	await _frames(1)
