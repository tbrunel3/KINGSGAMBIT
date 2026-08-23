extends Node
##
## OU TOMBENT LES ZONES DE CLIC DU VILLAGE ?
##
## Les rectangles de BUILDING_HITBOX sont releves A L'OEIL sur le rendu de
## reference : aucun banc numerique ne peut dire s'ils couvrent le bon
## batiment, seulement s'ils existent. Cet outil les peint en rouge par-dessus
## l'illustration, sur les quatre formats qui comptent.
##
## Il est garde plutot que jete parce que la question se reposera : toute
## retouche d'un rectangle demande de revoir ou il tombe, et un decalage de
## trente points ne se voit sur aucune autre capture.
##
## Lancement (SANS --headless, il ecrit des PNG) :
##   godot --path . tools/hitbox_debug.tscn
##

const OUTPUT_DIR := "res://tools/screenshots/hitbox"

const SIZES := [
	{"w": 393, "h": 852, "name": "base-393x852"},
	{"w": 393, "h": 700, "name": "web-393x700"},
	{"w": 360, "h": 620, "name": "court-360x620"},
	{"w": 430, "h": 1080, "name": "tres-long-430x1080"},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	Game.reset_progress()

	for size in SIZES:
		DisplayServer.window_set_size(Vector2i(int(size["w"]), int(size["h"])))
		for i in range(3):
			await RenderingServer.frame_post_draw

		var village: Node = load("res://scenes/village/village.tscn").instantiate()
		add_child(village)
		for i in range(4):
			await RenderingServer.frame_post_draw

		for zone in village.find_children("Hitbox_*", "Control", true, false):
			var paint := ColorRect.new()
			paint.color = Color(1, 0.2, 0.2, 0.35)
			paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			zone.add_child(paint)

		for i in range(3):
			await RenderingServer.frame_post_draw

		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/hitbox_%s.png" % [OUTPUT_DIR, String(size["name"])])
		print("hitbox %-20s %d x %d" % [String(size["name"]),
			image.get_width(), image.get_height()])

		village.queue_free()
		await get_tree().process_frame

	get_tree().quit(0)
