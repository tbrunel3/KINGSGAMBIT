extends Node
##
## BANC DE FORMAT - la geometrie des ecrans, en chiffres.
##
## resolutions.tscn rend des IMAGES : il faut un humain pour les regarder, et
## une image ne casse pas un banc quand elle regresse. Celui-ci mesure des
## COORDONNEES, et il echoue tout seul.
##
## Il ne remplace pas l'oeil : il garde la FORMULE contre une regression. La
## preuve que les etiquettes tombent bien sur leurs batiments reste la
## comparaison visuelle de resolutions.tscn.
##
## Lancement :
##   godot --headless --path . tools/format_test.tscn
##

const CoverFit := preload("res://scripts/ui/cover_fit.gd")

## Les huit formats de resolutions.tscn, convertis en VIEWPORT (unites de jeu).
##
## ⚠️ CE NE SONT PAS LES TAILLES DE FENETRE. En "canvas_items / expand", Godot
## choisit l'echelle sur le plus contraint des deux axes puis AGRANDIT le
## viewport : une fenetre de 393x700 donne un viewport de 478x852, plus LARGE
## que la reference. C'est le piege n1 de CLAUDE.md, et c'est pourquoi la
## largeur ne descend jamais sous 393 - elle MONTE quand l'ecran raccourcit.
const VIEWPORTS := [
	{"name": "base-393x852",       "size": Vector2(393.00, 852.00)},
	{"name": "android-360x800",    "size": Vector2(393.00, 873.33)},
	{"name": "iphone-375x812",     "size": Vector2(393.47, 852.00)},
	{"name": "pixel-412x915",      "size": Vector2(393.00, 872.81)},
	{"name": "iphone-430x932",     "size": Vector2(393.09, 852.00)},
	# --- hors format : c'est ici que ca casse ---
	{"name": "web-393x700",        "size": Vector2(478.34, 852.00)},
	{"name": "court-360x620",      "size": Vector2(494.71, 852.00)},
	{"name": "tres-long-430x1080", "size": Vector2(393.00, 987.07)},
]

var _failures: int = 0


func _ready() -> void:
	print("=== KING'S GAMBIT - banc de format ===")
	_test_cover_fit()
	_test_village_anchoring()
	await _test_intro_overlays()
	await _test_letter_folds()

	print("")
	if _failures == 0:
		print("RESULTAT : la geometrie tient sur les huit formats.")
	else:
		print("RESULTAT : %d probleme(s) de format." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		_failures += 1
		print("  ECHEC %s" % label)


func _near(a: float, b: float, tolerance: float = 0.5) -> bool:
	return absf(a - b) <= tolerance


# ---------------------------- LA GEOMETRIE DU FOND ---------------------------

func _test_cover_fit() -> void:
	print("\n[1] CoverFit : le rectangle reellement affiche par un fond")

	var texture := Vector2(864, 1821)

	# A la reference, le fond est plus ETROIT en rapport que l'ecran (0,4745
	# contre 0,4613) : c'est donc la HAUTEUR qui commande, et l'image deborde
	# de 11 points en largeur.
	var base := CoverFit.rect(Vector2(393, 852), texture)
	_check(_near(base.size.x, 404.24), "base : largeur affichee 404,24 (%.2f)" % base.size.x)
	_check(_near(base.size.y, 852.0), "base : hauteur affichee 852 (%.2f)" % base.size.y)
	_check(_near(base.position.x, -5.62), "base : deborde de 5,62 a gauche (%.2f)" % base.position.x)
	_check(_near(base.position.y, 0.0), "base : cale en haut (%.2f)" % base.position.y)

	# Sur un ecran COURT, le viewport s'elargit : c'est la LARGEUR qui commande,
	# et l'image deborde en hauteur.
	var court := CoverFit.rect(Vector2(478, 852), texture)
	_check(_near(court.size.x, 478.0), "court : largeur affichee 478 (%.2f)" % court.size.x)
	_check(_near(court.size.y, 1007.45), "court : hauteur affichee 1007,45 (%.2f)" % court.size.y)
	_check(_near(court.position.y, -77.72), "court : deborde de 77,72 en haut (%.2f)" % court.position.y)

	# Sur un ecran TRES LONG, la hauteur commande a nouveau, plus fort.
	var long_screen := CoverFit.rect(Vector2(393, 987), texture)
	_check(_near(long_screen.size.x, 468.30),
		"tres long : largeur affichee 468,30 (%.2f)" % long_screen.size.x)
	_check(_near(long_screen.position.x, -37.65),
		"tres long : deborde de 37,65 a gauche (%.2f)" % long_screen.position.x)

	# L'aller-retour doit etre exact sur les huit formats : c'est la propriete
	# dont depend tout l'ancrage du village.
	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		var point := Vector2(133.84, 512.96)   # un point DANS l'image
		var screen := CoverFit.from_texture(point, size, texture)
		var back := CoverFit.to_texture(screen, size, texture)
		_check(back.distance_to(point) < 0.05,
			"%s : l'aller-retour image <-> ecran est exact (%.3f)"
				% [String(entry["name"]), back.distance_to(point)])

	# Le fond COUVRE toujours l'ecran : jamais de bande vide.
	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		var r := CoverFit.rect(size, texture)
		_check(r.size.x >= size.x - 0.01 and r.size.y >= size.y - 0.01,
			"%s : le fond couvre l'ecran entier" % String(entry["name"]))


# ------------------------------- LE VILLAGE ----------------------------------

const Village := preload("res://scenes/village/village.gd")

## Le village colle ses etiquettes a des batiments PEINTS DANS le fond. La
## seule chose qui doive rester vraie sur tous les formats, c'est donc : une
## etiquette tombe toujours sur le MEME POINT DE L'IMAGE.
##
## ⚠️ Ce test garde la FORMULE contre une regression, il ne remplace pas
## l'oeil : la preuve que les etiquettes tombent bien sur leurs batiments
## reste la comparaison visuelle de resolutions.tscn.
func _test_village_anchoring() -> void:
	print("\n[2] Village : les etiquettes suivent le decor, pas l'ecran")

	var texture: Vector2 = Village.BACKGROUND_SIZE
	var design: Vector2 = Village.DESIGN_SIZE

	# Les quatre casernes, le chateau, et une lumiere de fenetre - relevees sur
	# la maquette, donc exprimees dans le repere de la REFERENCE.
	var points := {
		"caserne des pions": Vector2(57, 240),
		"ecuries": Vector2(235, 230),
		"cloitre des fous": Vector2(45, 628),
		"donjon des tours": Vector2(252, 619),
		"chateau": Vector2(120, 425),
		"fenetre centrale": Vector2(186, 385),
	}

	for label in points:
		var design_point: Vector2 = points[label]
		var expected := CoverFit.to_texture(design_point, design, texture)

		# A la reference, la conversion doit etre l'identite : sinon le village
		# a bouge par rapport a sa propre maquette.
		var at_base: Vector2 = Village.design_to_decor(design_point, design)
		_check(at_base.distance_to(design_point) < 0.5,
			"%s : inchange a la reference (%.2f)" % [label, at_base.distance_to(design_point)])

		# Sur les huit formats, le point d'image vise doit rester le meme.
		var worst := 0.0
		for entry in VIEWPORTS:
			var size: Vector2 = entry["size"]
			var placed: Vector2 = Village.design_to_decor(design_point, size)
			var landed := CoverFit.to_texture(placed, size, texture)
			worst = maxf(worst, landed.distance_to(expected))
		_check(worst < 1.0, "%s : derive maximale %.2f pt sur les huit formats" % [label, worst])

	# Le bouton BATAILLE suit l'ECRAN, pas le decor : il doit rester centre.
	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		var center: float = Village.battle_center_x(size)
		_check(_near(center, size.x * 0.5, 1.0),
			"%s : BATAILLE centre (%.1f pour un centre a %.1f)"
				% [String(entry["name"]), center, size.x * 0.5])


# ------------------------------- L'INTRO -------------------------------------

const KingIntro := preload("res://scenes/intro/king_intro_dialogue.tscn")

## Les vignettes de l'intro doivent couvrir TOUTE la largeur du viewport.
##
## ⚠️ CE TEST EXISTE PARCE QU'IL MANQUAIT. Le banc ne couvrait que le village :
## les deux ecrans d'intro n'ont jamais ete passes au crible des formats, et
## c'est la que le defaut a survecu. Les deux degrades etaient poses en absolu,
## larges de 393 EN DUR. Sur web-393x700, le viewport fait 478 de large : la
## bande de droite restait nue sur 85 points, avec un bord net. Le joueur l'a
## vu sur la version web, et aucun banc ne pouvait le voir.
##
## Le test instancie le VRAI ecran plutot que de reproduire sa formule : ce
## qu'on garde ici, c'est que personne ne recable une largeur en dur.
func _test_intro_overlays() -> void:
	print("\n[3] Intro : les vignettes couvrent toute la largeur")

	var host := Control.new()
	add_child(host)
	var screen: Control = KingIntro.instantiate()
	host.add_child(screen)
	await get_tree().process_frame

	var overlay: Control = screen.get_node_or_null("Overlay")
	if overlay == null:
		_check(false, "l'ecran d'intro expose bien un noeud Overlay")
		host.queue_free()
		return

	var vignettes: Array[Control] = []
	for child in overlay.get_children():
		if child is TextureRect:
			vignettes.append(child)
	# Trois depuis le 24/08 : le vignetage radial autour du Roi s'est ajoute aux
	# deux fondus de bord. Il est plein ecran comme eux, donc il doit passer le
	# meme test - un vignetage qui s'arreterait a 393 laisserait le meme bord net.
	_check(vignettes.size() >= 2,
		"les calques pleine largeur sont la (%d)" % vignettes.size())

	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		host.size = size
		screen.size = size
		await get_tree().process_frame

		var worst := 0.0
		for rect in vignettes:
			# Le bord droit de chaque vignette doit tomber sur le bord droit de
			# l'ecran. Un ecart, c'est la bande nue.
			worst = maxf(worst, absf(rect.position.x + rect.size.x - size.x))
			worst = maxf(worst, absf(rect.position.x))
		_check(worst < 1.0,
			"%s : bande nue maximale %.2f pt (viewport %.0f de large)"
				% [String(entry["name"]), worst, size.x])

	host.queue_free()


# ------------------------------- LA MISSIVE ----------------------------------

const RoyalLetter := preload("res://scenes/story/royal_letter.tscn")

## Le parchemin doit se DECOUPER au meme endroit sur les huit formats.
##
## ⚠️ CE N'EST PAS UN TEST DE PLUS : c'est le seul qui protege le pli. Les deux
## plissures sont PEINTES dans l'illustration, a 39,5 % et 65,4 % de sa hauteur.
## Si la decoupe derive d'un format a l'autre - parce qu'une hauteur est calee
## en dur, ou que le parchemin est etire au lieu d'etre borne -, les ombres de
## pli tombent en plein milieu des lignes de texte, et ca ne se voit sur aucune
## capture prise au format de reference.
##
## On mesure aussi que la lettre RESTE DANS L'ECRAN : c'est un parchemin de
## rapport 0,733, et sur un ecran court (court-360x620 rend 852 de haut pour
## 495 de large) c'est la hauteur qui commande.
func _test_letter_folds() -> void:
	print("\n[4] La missive : le pli tombe au meme endroit partout")

	Game.reset_progress()
	Game.mark_intro_seen()
	Router.current_letter = Letters.HERITAGE

	var host := Control.new()
	add_child(host)
	var screen: Control = RoyalLetter.instantiate()
	host.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(screen._panels.size() == 3,
		"le parchemin est en trois tranches (%d)" % screen._panels.size())

	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		host.size = size
		screen.size = size
		await get_tree().process_frame
		screen._place()

		var total := 0.0
		for panel in screen._panels:
			total += panel.size.y
		if total <= 0.0:
			_check(false, "%s : le parchemin a une hauteur" % String(entry["name"]))
			continue

		var first: float = screen._panels[0].size.y / total
		var second: float = (screen._panels[0].size.y + screen._panels[1].size.y) / total
		var derive := maxf(absf(first - 0.395), absf(second - 0.654)) * 100.0

		# Il doit aussi tenir dans l'ecran, en haut comme en bas.
		var haut: float = screen._panels[0].position.y
		var bas: float = screen._panels[2].position.y + screen._panels[2].size.y
		var deborde: float = maxf(-haut, bas - screen.get_node("Safe/Root/Stage").size.y)

		_check(derive < 0.5 and deborde < 1.0,
			"%s : plis a %.1f %% / %.1f %% (derive %.2f pt), debordement %.2f pt"
				% [String(entry["name"]), first * 100.0, second * 100.0, derive,
				   maxf(0.0, deborde)])

	host.queue_free()
	await get_tree().process_frame
	Game.reset_progress()
