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

const Driver := preload("res://tools/battle_driver.gd")

const OUTPUT_DIR := "res://tools/screenshots/echelle"

## Definitions choisies pour encadrer le marche : la plus etroite et la plus
## large des tailles courantes, plus la base du projet.
##
## ⚠️ LES CINQ PREMIERES ONT TOUTES LE MEME FORMAT (0,45 a 0,46). Le banc ne
## pouvait donc PAS attraper un probleme de format - il ne mesurait que la
## largeur. C'est ce qui l'a laisse passer un ecran casse dans un navigateur
## de telephone, ou la barre d'URL mange la hauteur et fait monter le rapport
## a 0,55.
##
## Les trois dernieres tailles existent pour ca, et ce sont elles qu'il faut
## regarder en premier : un ecran qui tient en 393x852 et casse en 393x700 est
## un ecran qui suppose une hauteur.
const SIZES := [
	{"w": 393, "h": 852, "name": "base-393x852"},        # reference du projet
	{"w": 360, "h": 800, "name": "android-360x800"},     # Android d'entree de gamme
	{"w": 375, "h": 812, "name": "iphone-375x812"},      # iPhone 13 mini / X
	{"w": 412, "h": 915, "name": "pixel-412x915"},       # Pixel 7
	{"w": 430, "h": 932, "name": "iphone-430x932"},      # iPhone 15 Pro Max
	# --- hors format : c'est ici que ca casse ---
	{"w": 393, "h": 700, "name": "web-393x700"},         # navigateur, barre d'URL visible
	{"w": 360, "h": 620, "name": "court-360x620"},       # le plus court plausible
	{"w": 430, "h": 1080, "name": "tres-long-430x1080"}, # le plus allonge
]

const SCREENS := [
	{"scene": "res://scenes/village/village.tscn", "name": "village", "battle": 1},
	{"scene": "res://scenes/battle/campaign.tscn", "name": "campagne", "battle": 1},
	{"scene": "res://scenes/battle/battle_prep.tscn", "name": "preparation", "battle": 3},
	# La derniere bataille ajoute le bandeau de la Dame captive AU-DESSUS des
	# trois panneaux, dans un corps qui defile deja : c'est l'ecran le plus
	# serre du jeu en hauteur.
	{"scene": "res://scenes/battle/battle_prep.tscn", "name": "preparation-dame", "battle": 10},
	{"scene": "res://scenes/village/codex_popup.tscn", "name": "codex", "battle": 1},
	{"scene": "res://scenes/battle/battle.tscn", "name": "placement", "battle": 3},
	# Le COMBAT est l'ecran le plus expose au changement de format : il n'a plus
	# de bandeau du bas, donc le plateau prend toute la hauteur restante, et
	# c'est justement la hauteur qui varie d'un telephone a l'autre. Il se
	# capture sur le plus GRAND plateau du jeu (bataille 10, 8x9), ou les cases
	# sont les plus petites et ou un debordement se voit en premier.
	{"scene": "res://scenes/battle/battle.tscn", "name": "combat", "battle": 10,
		"combat": true},
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
			await _finish_animations()

			# L'ecran de bataille s'ouvre en placement : pour photographier le
			# combat il faut poser une armee et lancer les hostilites. C'est le
			# pilote de test qui le fait, le jeu n'offrant plus aucun moyen de
			# se jouer tout seul.
			if bool(screen.get("combat", false)):
				Driver.auto_place(instance)
				instance._start_combat()
				for i in range(6):
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
