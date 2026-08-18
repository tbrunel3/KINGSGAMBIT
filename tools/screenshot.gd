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

	await _capture_combat()
	get_tree().quit()


## Joue reellement une bataille : placement automatique, combat en x4, puis
## capture pendant les echanges et sur l'ecran de fin. C'est le seul passage qui
## exerce la boucle animee et l'ecran de resultat.
func _capture_combat() -> void:
	Router.current_battle_id = 1
	var battle: Node = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(battle)
	for i in range(4):
		await RenderingServer.frame_post_draw

	# Armee posee : c'est ici que les fleches d'apercu doivent apparaitre.
	battle._on_auto_place()
	for i in range(4):
		await RenderingServer.frame_post_draw
	_save(battle, "5_apercu.png")

	battle._speed = 4.0
	battle._start_combat()

	for i in range(40):
		await RenderingServer.frame_post_draw
	_save(battle, "6_combat.png")

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
