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
## BattleResult n'a pas de .tscn : c'est un script monte a la main.
const BattleResultScript := preload("res://scenes/battle/battle_result.gd")
const GuidePopupScript := preload("res://scenes/ui/guide_popup.gd")

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
	{"scene": "res://scenes/village/shop.tscn", "name": "boutique", "battle": 1},
	{"scene": "res://scenes/battle/battle.tscn", "name": "placement", "battle": 3},
	# Le COMBAT est l'ecran le plus expose au changement de format : il n'a plus
	# de bandeau du bas, donc le plateau prend toute la hauteur restante, et
	# c'est justement la hauteur qui varie d'un telephone a l'autre. Il se
	# capture sur le plus GRAND plateau du jeu (bataille 10, 8x9), ou les cases
	# sont les plus petites et ou un debordement se voit en premier.
	{"scene": "res://scenes/battle/battle.tscn", "name": "combat", "battle": 10,
		"combat": true},

	# --- LES ECRANS QUE LE BANC NE REGARDAIT PAS ---------------------------
	#
	# Le chateau, les trois resultats et les quatre popups n'avaient jamais ete
	# passes au crible des formats. Ils heritent ici des huit tailles ET de
	# _finish_animations(), sans quoi une entree animee les photographierait a
	# moitie apparus - le piege deja paye sur la preparation.
	{"scene": "res://scenes/village/castle_screen.tscn", "name": "chateau", "battle": 1},

	# Les deux popups prennent la meme cle "popup" parce qu'ils exposent la
	# meme methode : open(type). Sans elle, ils s'affichent vides.
	{"scene": "res://scenes/village/building_popup.tscn", "name": "popup-batiment",
		"battle": 1, "popup": Balance.PION},
	# Le DONJON DES TOURS est verrouille sur une sauvegarde neuve : c'est
	# l'etat qu'on veut photographier, et celui dont la maquette cercle le
	# cadre d'or.
	{"scene": "res://scenes/village/building_popup.tscn", "name": "popup-verrouille",
		"battle": 1, "popup": Balance.TOUR},
	{"scene": "res://scenes/village/confirm_upgrade.tscn", "name": "popup-amelioration",
		"battle": 1, "popup": Balance.CASTLE},
	# Le popup de missions se remplit tout seul dans son _ready().
	{"scene": "res://scenes/village/mission_popup.tscn", "name": "popup-missions",
		"battle": 1},

	# LES TROIS RESULTATS N'ONT PAS DE SCENE : BattleResult est un script qui
	# etend Control, monte a la main par battle.gd (BattleResult.new(), trois
	# appels). On le construit donc pareil ici - sans quoi ce banc
	# photographierait un montage qui n'existe nulle part dans le jeu.
	# LES QUATRE POPUPS D'ACCOMPAGNEMENT (chantier E). Comme BattleResult, ils
	# n'ont pas de scene : GuidePopup se monte a la main.
	{"guide": "stalemate", "name": "guide-pat", "battle": 1},
	{"guide": "lineup", "name": "guide-composition", "battle": 1},
	{"guide": "dame_aura", "name": "guide-aura", "battle": 1},
	{"guide": "realtime", "name": "guide-temps-reel", "battle": 1},

	{"result": "win", "name": "victoire", "battle": 3},
	{"result": "loss", "name": "defaite", "battle": 3},
	{"result": "draw", "name": "nulle", "battle": 3},
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

## Remplit un ecran de resultat comme le JEU le remplit.
##
## ⚠️ open() seul ne pose ni recompense, ni statistique, ni bouton : c'est
## battle.gd qui les ajoute apres, en trois endroits. Un ecran ouvert et laisse
## nu se photographie avec une plaque VIDE et sans boutons - il ressemble a un
## ecran casse alors qu'il n'a simplement jamais ete rempli. C'est le piege de
## "l'etat de partie egal", sous une forme neuve : le banc doit montrer ce que
## le joueur voit, pas ce que la classe sait faire toute seule.
##
## Les lignes ci-dessous reprennent la FORME des appels de battle.gd (une
## recompense, deux a trois statistiques, un bouton principal et deux
## secondaires) - c'est la hauteur de contenu qui compte pour un banc de
## format, pas le detail des chiffres.
func _fill_result(screen: Node, kind: String) -> void:
	# ⚠️ LE TITRE VIDE N'EST PAS UN OUBLI. BattleResult a DEUX visages : une
	# petite plaque ECRITE quand on lui donne un texte ("COMBAT 2 SUR 3"), et le
	# grand lettrage GRAVE quand on ne lui en donne pas. C'est le second que
	# montre la maquette (410:5121), et c'est celui de la fin d'une serie.
	#
	# Passer "VICTOIRE" ici sortait la petite plaque, et la capture donnait
	# l'impression que l'image gravee manquait au depot. Elle n'a jamais
	# manque : c'etait le banc qui demandait l'autre variante.
	match kind:
		"win":
			screen.open(true, "")
			screen.add_reward_row("Recompense totale", 450)
			screen.add_stat_row("Ennemis vaincus", "11")
			screen.add_stat_row("Pertes", "2 Pions", 1)
		"loss":
			screen.open(false, "")
			screen.add_reward_row("Consolation", 180)
			screen.add_stat_row("Serie rompue", "Combat 2 sur 3")
			screen.add_stat_row("Pertes du combat", "3 Pions, 1 Tour", 1)
		_:
			# Le nul n'a JAMAIS le grand lettrage (cf. open_draw) : sa plaque
			# d'acier gravee lui tient lieu de titre.
			screen.open_draw("")
			screen.add_reward_row("Butin promis", 900)
			screen.add_stat_row("Combat nul", "Position morte")
			screen.add_stat_row("Pertes du combat", "1 Cavalier", 1)

	# Quatre boutons, comme la maquette : principal, secondaire, et deux
	# d'action. C'est la hauteur de contenu qui compte pour un banc de format.
	screen.add_primary_button("BATAILLE SUIVANTE", func(): pass)
	screen.add_secondary_button("REESSAYER", func(): pass)
	screen.add_action_button("ROYAUME", "castle", func(): pass)
	screen.add_action_button("CAMPAGNE", "compass", func(): pass)


func _ready() -> void:
	# Un banc ne joue pas la mise en scene : sans ca, chaque changement
	# d'ecran ajoute un fondu complet et le banc ralentit sans rien
	# mesurer de plus. Meme doctrine que BattleAI.budget_ms = 0.
	ScreenVeil.instant = true
	# Idem : la regle d'abandon s'applique, mais sans modale a attendre.
	Router.ask_before_leaving = false
	# Un banc instancie ses ecrans comme enfants de lui-meme : un vrai
	# change_scene_to_file() remplacerait la scene du banc et le detruirait.
	Router.navigation_enabled = false
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

			var instance: Node
			if screen.has("guide"):
				# Le drapeau "deja vu" est remis a zero : le banc doit pouvoir
				# les photographier a chaque passage.
				Game.reset_progress()
				instance = GuidePopupScript.new()
				add_child(instance)
				instance._build(String(screen["guide"]))
			elif screen.has("result"):
				instance = BattleResultScript.new()
			else:
				instance = load(String(screen["scene"])).instantiate()
			if not screen.has("guide"):
				add_child(instance)

			# Un popup de batiment ne montre rien tant qu'on ne lui a pas dit
			# QUEL batiment : sans ca les huit captures sont vides.
			if screen.has("popup"):
				instance.open(String(screen["popup"]))

			# L'ecran de resultat prend sa peau a l'ouverture - c'est elle qui
			# fait la difference entre la victoire, la defaite et l'acier du
			# match nul, qui a ses propres assets (assets/results/draw_*).
			if screen.has("result"):
				_fill_result(instance, String(screen["result"]))

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
