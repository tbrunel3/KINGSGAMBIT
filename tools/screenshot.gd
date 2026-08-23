extends Node
##
## CAPTURE D'ECRAN - outil de developpement.
##
## Ouvre chaque ecran, attend quelques images, enregistre un PNG au format
## iPhone portrait, puis quitte. Sert a relire la mise en page sans avoir a
## naviguer dans le jeu a la main.
##
## Lancement :
##   godot --path . tools/screenshot.tscn
##
## Les fichiers atterrissent dans tools/screenshots/ (ignore par Git).
##

const Driver := preload("res://tools/battle_driver.gd")

const OUTPUT_DIR := "res://tools/screenshots"

const SHOTS := [
	{"scene": "res://scenes/village/village.tscn", "file": "1_village.png", "battle": 1},
	{"scene": "res://scenes/battle/campaign.tscn", "file": "2_campagne.png", "battle": 1},
	{"scene": "res://scenes/battle/battle_prep.tscn", "file": "3_preparation.png", "battle": 3},
	# La derniere bataille est la seule a porter le bandeau de la Dame captive
	# (cf. battle_prep._build_stake_band) : sans cette capture, rien ne le
	# montre jamais.
	{"scene": "res://scenes/battle/battle_prep.tscn", "file": "3b_preparation_dame.png", "battle": 10},
	{"scene": "res://scenes/battle/battle.tscn", "file": "4_placement.png", "battle": 3},
	{"scene": "res://scenes/village/codex_popup.tscn", "file": "1i_codex.png", "battle": 1},
	{"scene": "res://scenes/ui/ui_kit_showcase.tscn", "file": "0_ui_kit.png", "battle": 1},
]



## Pousse toutes les animations en cours jusqu'a leur fin.
##
## Depuis que les ecrans ont une entree animee (preparation, resultat, bandeau
## de serie), une capture prise quatre images apres l'instanciation photographie
## un ecran a MOITIE APPARU - la preparation ressortait quasiment vide, et le
## banc accusait la mise en page. On saute donc a la fin des tweens plutot que
## d'attendre : c'est instantane, et c'est exact.
func _finish_animations() -> void:
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(10.0)
	await RenderingServer.frame_post_draw

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	# Etat de depart previsible : la capture doit toujours montrer la meme chose.
	Game.reset_progress()

	for shot in SHOTS:
		Router.current_battle_id = int(shot["battle"])
		var instance: Node = load(String(shot["scene"])).instantiate()
		add_child(instance)

		# Quelques images pour laisser les conteneurs se disposer.
		for i in range(4):
			await RenderingServer.frame_post_draw
		await _finish_animations()

		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s" % [OUTPUT_DIR, String(shot["file"])]
		image.save_png(path)
		print("capture : %s (%d x %d)" % [path, image.get_width(), image.get_height()])

		instance.queue_free()
		await get_tree().process_frame

	await _capture_composition()
	await _capture_series()
	await _capture_dame_tower()
	await _capture_combat()
	await _capture_run()
	await _capture_defeat()
	await _capture_draw()
	await _capture_splash()
	await _capture_intro()
	await _capture_shop()
	await _capture_village_advanced()
	get_tree().quit()


## La preparation une fois COMPOSEE : sans cette capture, on ne voit jamais
## que l'etat vide, et c'est justement l'etat rempli qui dit ce que l'ecran
## fait. La composition est posee en memoire plutot que tapee : la capture doit
## montrer la meme chose a chaque fois.
func _capture_composition() -> void:
	# Une capture precedente a instancie battle.tscn sur cette bataille, ce qui
	# laisse une serie ouverte sans composition - et une serie EN COURS ne se
	# recompose pas depuis la memoire, c'est la regle. On repart d'avant.
	Game.clear_run()
	Game.remember_lineup(3, {Balance.PION: 3, Balance.CAVALIER: 1})
	Router.current_battle_id = 3

	var prep: Node = load("res://scenes/battle/battle_prep.tscn").instantiate()
	add_child(prep)
	for i in range(4):
		await RenderingServer.frame_post_draw
	await _finish_animations()

	var path := "%s/3c_preparation_composee.png" % OUTPUT_DIR
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("capture : %s (%d x %d)" % [path, image.get_width(), image.get_height()])

	prep.queue_free()
	await get_tree().process_frame
	Game.reset_progress()


## Les deux ecrans de la SERIE : l'avertissement qui l'explique une fois, et le
## bandeau qui enchaine deux combats sans passer par la victoire.
func _capture_series() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)

	var popup: Control = load("res://scenes/battle/series_popup.tscn").instantiate()
	host.add_child(popup)
	popup.setup(3)
	for i in range(6):
		await RenderingServer.frame_post_draw
	_save(host, "1j_serie_avertissement.png")
	host.queue_free()
	await get_tree().process_frame

	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	var banner := SeriesBanner.new()
	board.add_child(banner)
	banner.show_fight(2, 3, {Balance.PION: 2, Balance.CAVALIER: 1},
		{Balance.PION: 1}, 7)
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_save(board, "4c_serie_bandeau.png")
	board.queue_free()
	await get_tree().process_frame


## Le Chateau Royal avec une Dame retrouvee : l'ecran n'existe qu'apres avoir
## ramene un pion promu vivant d'une bataille. On force la Dame par le
## raccourci de test plutot que de jouer la bataille qui la donne.
func _capture_dame_tower() -> void:
	Game.reset_progress()
	Game.dev_grant_dame()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	for i in range(4):
		await RenderingServer.frame_post_draw
	# Le panneau des missions, avec une mission terminee prete a etre encaissee.
	Game.record_battle(true, 0, 5, 0)
	village._on_missions_pressed()
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(village, "1d_missions.png")
	if is_instance_valid(village._popup):
		village._popup.queue_free()
	for i in range(3):
		await RenderingServer.frame_post_draw

	# LES POPUPS DE BATIMENT, qui n'avaient aucune capture alors qu'ils portent
	# a eux seuls quatre ecrans de la maquette (08 chateau, 09 batiment, 10
	# verrouille, 11 amelioration en cours) dans une seule scene. Sans image de
	# reference, l'ecart avec la V2 ne se voyait nulle part.
	#
	# Deux etats, qui couvrent les deux formes du popup :
	#   - une caserne ouverte, ou l'on recrute et ou l'on ameliore
	#   - un batiment VERROUILLE, qui n'affiche qu'une condition d'ouverture
	#
	# Pas le Chateau Royal : le toucher ne l'ouvre pas en popup, il CHANGE DE
	# SCENE vers la salle du trone (deja capturee en 1b). L'ajouter ici faisait
	# derailler tout le reste de la campagne de captures.
	for shot in [
		{"type": Balance.CAVALIER, "file": "1e_popup_caserne.png"},
		{"type": Balance.TOUR, "file": "1f_popup_verrouille.png"},
	]:
		village._on_building_pressed(String(shot["type"]))
		for i in range(4):
			await RenderingServer.frame_post_draw
		_save(village, String(shot["file"]))
		if is_instance_valid(village._popup):
			village._popup.queue_free()
		for i in range(3):
			await RenderingServer.frame_post_draw

	# LA MODALE DE CONFIRMATION D'AMELIORATION, que le jeu n'avait pas avant la
	# revision : elle s'ouvre par-dessus le village, comme en partie.
	Game.add_gold(5000)
	var confirm: Node = load("res://scenes/village/confirm_upgrade.tscn").instantiate()
	village.add_child(confirm)
	confirm.open(Balance.PION)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(village, "1g_confirmer_amelioration.png")
	confirm.queue_free()
	for i in range(3):
		await RenderingServer.frame_post_draw

	# LE POPUP PENDANT L'AMELIORATION (ecran 11 de la maquette) : compte a
	# rebours arme, plus de bouton d'amelioration. C'est un troisieme etat du
	# meme popup, et il n'avait aucune image de reference.
	Game.start_upgrade(Balance.PION)
	village._on_building_pressed(Balance.PION)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(village, "1h_popup_amelioration.png")
	if is_instance_valid(village._popup):
		village._popup.queue_free()
	for i in range(3):
		await RenderingServer.frame_post_draw

	# Le village AVANT d'ouvrir le popup : c'est la qu'on voit le halo dore du
	# Chateau Royal, allume par la Dame rentree.
	_save(village, "1a_chateau_qui_brille.png")

	village.queue_free()
	await get_tree().process_frame

	# La salle du trone, Dame rentree : c'est l'ecran qui raconte l'histoire.
	var castle: Node = load("res://scenes/village/castle_screen.tscn").instantiate()
	add_child(castle)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(castle, "1b_chateau_avec_dame.png")
	castle.queue_free()
	await get_tree().process_frame

	# Et le meme, trone vide : l'etat de depart de la campagne.
	Game.reset_progress()
	var empty: Node = load("res://scenes/village/castle_screen.tscn").instantiate()
	add_child(empty)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(empty, "1b2_chateau_sans_dame.png")
	empty.queue_free()
	await get_tree().process_frame
	Game.dev_grant_dame()

	# Et le placement avec la Dame en reserve : son chip apparait a cote des
	# casernes, et elle pese 5 de charge (cf. Balance.deploy_weight).
	Router.current_battle_id = 3
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw
	Driver.auto_place(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "1c_dame_au_placement.png")
	battle.queue_free()
	await get_tree().process_frame
	Game.reset_progress()


## Deuxieme combat d'une serie : c'est l'ecran qui prouve que l'usure marche.
## _capture_combat() vient de gagner le premier combat de la bataille 1, donc
## la serie est sauvegardee au combat 2 - on rouvre la scene et on regarde
## avec quoi le joueur repart.
func _capture_run() -> void:
	Router.current_battle_id = 1
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "4b_serie_combat2.png")
	battle.queue_free()
	await get_tree().process_frame


## Meme passage que _capture_combat(), mais contre la derniere bataille (Nv.6)
## avec une armee de depart (Nv.1) : verifie l'ecran de defaite redessine
## (blason couronne brisee, bouton Reessayer rouge) sans dependre du hasard.
func _capture_defeat() -> void:
	Game.reset_progress()
	Router.current_battle_id = Balance.battle_count()
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw

	# Une seule piece plutot que la formation complete : l'IA gagne meme en sous-nombre
	# (cf. son propre chantier de reglage), il faut donc forcer un ecart net
	# pour obtenir une defaite fiable ici.
	var only_cell: Vector2i = battle._engine.grid.free_player_cells()[0]
	battle._on_cell_clicked(only_cell)
	battle._start_combat()
	Driver.resolve(battle)

	var guard := 0
	while battle._phase != 2 and guard < 6000:
		await get_tree().process_frame
		guard += 1
	if guard >= 6000:
		print("ATTENTION : le combat (defaite) ne s'est pas termine dans le temps imparti")

	for i in range(3):
		await RenderingServer.frame_post_draw
	await _settle_result()
	_save(battle, "7b_defaite.png")

	battle.queue_free()
	await get_tree().process_frame
	Game.reset_progress()


## L'ecran de match nul. Il ne se produit qu'au bout d'un enlisement complet
## a materiel strictement egal : on monte donc l'ecran directement plutot que
## d'esperer tomber dessus en jouant.
func _capture_draw() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)

	var screen := BattleResult.new()
	host.add_child(screen)
	screen.open_draw("COMBAT 2 SUR 3 — NUL")
	screen.add_reward_row("Butin promis", 90)
	screen.add_stat_row("Combat nul", "Aucun camp n'a plié")
	screen.add_stat_row("Pertes du combat", "1 Pion", 1)
	screen.add_icon_row("Blessés relevés", "check", "1 Pion", Color("5fb37a"))
	screen.add_stat_row("Armée restante", "5 pièces", 1)
	screen.add_primary_button("COMBAT 3 SUR 3", func(): pass)
	screen.add_action_button("ROYAUME", "castle", func(): pass)
	screen.add_action_button("CAMPAGNE", "compass", func(): pass)

	for i in range(4):
		await RenderingServer.frame_post_draw
	await _settle_result()
	_save(host, "7c_nul.png")
	host.queue_free()
	await get_tree().process_frame

	# Et la SERIE nulle, celle qui porte le grand mot grave (Figma 348:2). Le
	# combat intermediaire ci-dessus garde sa plaque ecrite : le grand lettrage
	# est reserve a la fin, comme pour la victoire.
	var final_host := Control.new()
	final_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(final_host)
	var final_screen := BattleResult.new()
	final_host.add_child(final_screen)
	final_screen.open_draw("")
	final_screen.add_reward_row("Consolation", 50)
	final_screen.add_stat_row("Pertes subies", "4 Pions, 1 Cavalier", 1)
	final_screen.add_primary_button("RÉESSAYER", func(): pass)
	final_screen.add_action_button("ROYAUME", "castle", func(): pass)
	final_screen.add_action_button("CAMPAGNE", "compass", func(): pass)
	await _settle_result()
	_save(final_host, "7d_nul_serie.png")
	final_host.queue_free()
	await get_tree().process_frame


## L'ecran de resultat ENTRE en scene (cf. BattleResult._animate_entry, releve
## sur la timeline Figma 348:2) : le fond monte en deux images, le titre en
## sept, les plaques en dix-huit. Une capture prise a quatre images ne
## montrerait qu'un ecran presque vide.
func _settle_result() -> void:
	await get_tree().create_timer(2.6).timeout
	await RenderingServer.frame_post_draw


## Capture apres la sequence d'apparition (logo, chargement, credit) mais
## avant le fondu au noir de sortie.
func _capture_splash() -> void:
	var splash: Node = load("res://scenes/intro/splash_screen.tscn").instantiate()
	add_child(splash)
	await get_tree().create_timer(1.8).timeout
	_save(splash, "8_splash.png")
	splash.queue_free()
	await get_tree().process_frame


## Capture pendant la frappe (texte a moitie ecrit) puis une fois le bouton
## debloque, pour verifier les deux etats sans attendre toute la sequence.
func _capture_intro() -> void:
	Game.reset_progress()
	var intro: Node = load("res://scenes/intro/king_intro_dialogue.tscn").instantiate()
	add_child(intro)

	# Premier temps : le Roi seul, et l'invite a s'approcher.
	await get_tree().create_timer(0.6).timeout
	_save(intro, "9a_intro_approche.png")

	# Puis le dialogue, declenche comme le ferait un doigt sur l'ecran.
	intro.skip_approach()
	await get_tree().create_timer(1.4).timeout
	_save(intro, "9_intro_typing.png")
	await get_tree().create_timer(3.2).timeout
	_save(intro, "9_intro_ready.png")
	intro.queue_free()
	await get_tree().process_frame


## Joue reellement une bataille : placement automatique, combat en x4, puis
## capture pendant les echanges et sur l'ecran de fin. C'est le seul passage qui
## exerce la boucle animee et l'ecran de resultat.
func _capture_combat() -> void:
	Router.current_battle_id = 1
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw

	# Armee posee : zones de deploiement, chips et charge du chateau.
	Driver.auto_place(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "5_placement.png")

	# Le point i : les regles ecrites noir sur blanc, seul endroit du jeu ou
	# le bareme des poids est visible.
	battle._open_help()
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "5b_aide_placement.png")
	for child in battle.get_children():
		if child is Modal:
			child.close()
	for i in range(4):
		await RenderingServer.frame_post_draw

	battle._start_combat()
	for i in range(4):
		await RenderingServer.frame_post_draw

	# Piece selectionnee : c'est l'ecran que le joueur voit le plus souvent
	# maintenant qu'il joue chaque coup - pastilles de deplacement, anneaux
	# de capture, case de depart surlignee.
	for unit in battle._engine.living(BattleUnit.TEAM_PLAYER):
		if not battle._engine.legal_moves(unit).is_empty():
			battle._on_cell_pressed(unit.cell)
			break
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "6_coups_possibles.png")

	battle._open_help()
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "6a_aide_combat.png")
	for child in battle.get_children():
		if child is Modal:
			child.close()
	for i in range(4):
		await RenderingServer.frame_post_draw

	# Quelques coups joues A L'ECRAN, avec leurs animations, pour photographier
	# un combat en cours - puis on termine la bataille par le chemin rapide.
	# Le jeu, lui, n'offre plus aucun moyen de se jouer tout seul : c'est le
	# pilote de test qui tient les deux camps.
	await Driver.resolve(battle, true, 8)
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "6b_combat.png")
	Driver.resolve(battle)

	var guard := 0
	while battle._phase != 2 and guard < 6000:
		await get_tree().process_frame
		guard += 1
	if guard >= 6000:
		print("ATTENTION : le combat ne s'est pas termine dans le temps imparti")

	for i in range(3):
		await RenderingServer.frame_post_draw
	await _settle_result()
	_save(battle, "7_resultat.png")

	battle.queue_free()
	await get_tree().process_frame


func _save(_owner: Node, file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	image.save_png(path)
	print("capture : %s (%d x %d)" % [path, image.get_width(), image.get_height()])


## La boutique, dans son etat UTILE : des gemmes en poche et un chantier en
## cours. Sans les deux, tout l'ecran est grise et la capture ne montre que
## des cartes eteintes - ce qui est un etat legitime, mais pas celui qu'on
## compare a la maquette.
func _capture_shop() -> void:
	Game.reset_progress()
	Game.add_gems(1450)
	Game.add_gold(50000)
	Game.start_upgrade(Balance.CASTLE)
	var shop: Node = load("res://scenes/village/shop.tscn").instantiate()
	add_child(shop)
	for i in range(5):
		await RenderingServer.frame_post_draw
	await _finish_animations()
	_save(shop, "1k_boutique.png")
	shop.queue_free()
	for i in range(3):
		await RenderingServer.frame_post_draw


## Le village D'UNE PARTIE AVANCEE, et non du tout premier lancement.
##
## La capture ordinaire part d'une sauvegarde neuve : tout au niveau 1, deux
## batiments encore verrouilles, zero gemme. Compare a la maquette - qui montre
## un chateau Nv.5 et quatre casernes ouvertes - elle donne l'impression d'un
## ecran different, alors que c'est le meme a un autre moment de la partie.
##
## Les niveaux sont montes par les VRAIES fonctions du jeu (start_upgrade puis
## force_finish_upgrade), pas en ecrivant dans l'etat : c'est le seul moyen que
## la capture montre ce que le joueur verra vraiment.
func _capture_village_advanced() -> void:
	Game.reset_progress()
	Game.add_gold(500000)
	Game.add_gems(145)

	var targets := {
		Balance.CASTLE: 5, Balance.PION: 3, Balance.CAVALIER: 2,
		Balance.FOU: 2, Balance.TOUR: 1,
	}
	# Le chateau d'abord : c'est lui qui deverrouille le Cloitre (Nv.2) et le
	# Donjon (Nv.3). Sans cet ordre, les deux dernieres casernes n'existent pas
	# encore et rien ne monte.
	for type in [Balance.CASTLE, Balance.PION, Balance.CAVALIER, Balance.FOU, Balance.TOUR]:
		var wanted := int(targets[type])
		var guard := 0
		while Game.building_level(type) < wanted and guard < 20:
			guard += 1
			if not Game.start_upgrade(type):
				break
			Game.force_finish_upgrade(type)

	# On rend l'or de test : une bourse a 496 350 rend la capture absurde et
	# incomparable a la maquette, qui en montre 2 450.
	Game.spend_gold(maxi(0, Game.gold - 2450))

	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	for i in range(5):
		await RenderingServer.frame_post_draw
	await _finish_animations()
	_save(village, "1_village_avance.png")
	village.queue_free()
	for i in range(3):
		await RenderingServer.frame_post_draw
	Game.reset_progress()
