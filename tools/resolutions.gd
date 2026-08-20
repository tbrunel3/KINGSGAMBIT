extends Node
##
## BANC DE MISE A L'ECHELLE - le meme ecran, sur plusieurs telephones.
##
## Le jeu est cale sur 393 x 852. Sur un telephone au format different, le
## mode d'etirement "canvas_items / expand" ne redimensionne pas : il REVELE
## l'espace en plus. Tout ce qui est pose en coordonnees absolues se retrouve
## alors decale, flottant, ou hors de l'ecran.
##
## Cet outil rend chaque ecran a plusieurs definitions reelles et enregistre
## une capture par combinaison. C'est la seule facon de voir le probleme sans
## avoir dix telephones sur le bureau - et c'est plus rapide qu'un export.
##
## Lancement :
##   godot --path . tools/resolutions.tscn
##
## Les captures atterrissent dans tools/screenshots/echelle/.
##

const OUTPUT_DIR := "res://tools/screenshots/echelle"

## Definitions choisies pour encadrer le marche : la plus etroite et la plus
## large des tailles courantes, plus la base du projet.
const SIZES := [
	{"w": 393, "h": 852, "name": "base-393x852"},        # reference du projet
	{"w": 360, "h": 800, "name": "android-360x800"},     # Android d'entree de gamme
	{"w": 375, "h": 812, "name": "iphone-375x812"},      # iPhone 13 mini / X
	{"w": 412, "h": 915, "name": "pixel-412x915"},       # Pixel 7
	{"w": 430, "h": 932, "name": "iphone-430x932"},      # iPhone 15 Pro Max
]

const SCREENS := [
	{"scene": "res://scenes/village/village.tscn", "name": "village", "battle": 1},
	{"scene": "res://scenes/battle/campaign.tscn", "name": "campagne", "battle": 1},
	{"scene": "res://scenes/battle/battle_prep.tscn", "name": "preparation", "battle": 3},
	{"scene": "res://scenes/battle/battle.tscn", "name": "placement", "battle": 3},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	Game.reset_progress()

	for size in SIZES:
		DisplayServer.window_set_size(Vector2i(int(size["w"]), int(size["h"])))
		# Deux images pour que l'etirement recalcule la zone de jeu, sinon la
		# premiere capture montre encore l'ancienne definition.
		for i in range(3):
			await RenderingServer.frame_post_draw

		for screen in SCREENS:
			Router.current_battle_id = int(screen["battle"])
			var instance: Node = load(String(screen["scene"])).instantiate()
			add_child(instance)
			for i in range(4):
				await RenderingServer.frame_post_draw

			var image := get_viewport().get_texture().get_image()
			var path := "%s/%s_%s.png" % [OUTPUT_DIR, String(screen["name"]), String(size["name"])]
			image.save_png(path)
			print("%-12s %-18s %d x %d" % [
				String(screen["name"]), String(size["name"]),
				image.get_width(), image.get_height()])

			instance.queue_free()
			await get_tree().process_frame

	print("\nCaptures dans %s" % OUTPUT_DIR)
	get_tree().quit()
