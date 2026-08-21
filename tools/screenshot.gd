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

const OUTPUT_DIR := "res://tools/screenshots"

const SHOTS := [
	{"scene": "res://scenes/village/village.tscn", "file": "1_village.png", "battle": 1},
	{"scene": "res://scenes/battle/campaign.tscn", "file": "2_campagne.png", "battle": 1},
	{"scene": "res://scenes/battle/battle_prep.tscn", "file": "3_preparation.png", "battle": 3},
	{"scene": "res://scenes/battle/battle.tscn", "file": "4_placement.png", "battle": 3},
	{"scene": "res://scenes/ui/ui_kit_showcase.tscn", "file": "0_ui_kit.png", "battle": 1},
]


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

		var image := get_viewport().get_texture().get_image()
		var path := "%s/%s" % [OUTPUT_DIR, String(shot["file"])]
		image.save_png(path)
		print("capture : %s (%d x %d)" % [path, image.get_width(), image.get_height()])

		instance.queue_free()
		await get_tree().process_frame

	await _capture_dame_tower()
	await _capture_combat()
	await _capture_defeat()
	await _capture_splash()
	await _capture_intro()
	get_tree().quit()


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
	battle._on_auto_place()
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "1c_dame_au_placement.png")
	battle.queue_free()
	await get_tree().process_frame
	Game.reset_progress()


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

	# Une seule piece plutot que _on_auto_place() : l'IA gagne meme en sous-nombre
	# (cf. son propre chantier de reglage), il faut donc forcer un ecart net
	# pour obtenir une defaite fiable ici.
	var only_cell: Vector2i = battle._engine.grid.free_player_cells()[0]
	battle._on_cell_clicked(only_cell)
	battle._speed = 4.0
	battle._start_combat()
	battle._on_auto_pressed()

	var guard := 0
	while battle._phase != 2 and guard < 6000:
		await get_tree().process_frame
		guard += 1
	if guard >= 6000:
		print("ATTENTION : le combat (defaite) ne s'est pas termine dans le temps imparti")

	for i in range(3):
		await RenderingServer.frame_post_draw
	_save(battle, "7b_defaite.png")

	battle.queue_free()
	await get_tree().process_frame
	Game.reset_progress()


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
	battle._on_auto_place()
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

	battle._speed = 4.0
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

	# Le reste de la bataille tourne en resolution automatique.
	battle._on_auto_pressed()
	for i in range(40):
		await RenderingServer.frame_post_draw
	_save(battle, "6b_combat.png")

	var guard := 0
	while battle._phase != 2 and guard < 6000:
		await get_tree().process_frame
		guard += 1
	if guard >= 6000:
		print("ATTENTION : le combat ne s'est pas termine dans le temps imparti")

	for i in range(3):
		await RenderingServer.frame_post_draw
	_save(battle, "7_resultat.png")

	battle.queue_free()
	await get_tree().process_frame


func _save(_owner: Node, file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	image.save_png(path)
	print("capture : %s (%d x %d)" % [path, image.get_width(), image.get_height()])
