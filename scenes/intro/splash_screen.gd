extends Control
##
## SPLASH SCREEN - premier ecran au lancement.
##
## Reproduit la frame "splash-screen" de la maquette V2 (Figma 123:7) : fond
## en degrade radial violet-noir, logo centre, indicateur de chargement, et
## le credit du studio en bas.
##
## La maquette est VISUELLE : la mise en page vient d'elle, l'enchainement
## reste celui du jeu. Le logo, l'indicateur puis le credit apparaissent l'un
## apres l'autre (pas tous d'un coup), puis l'ecran entier fond au noir avant
## de passer a la suite : le dialogue d'introduction du Roi la toute premiere
## fois (cf. GameState.has_seen_intro), le village ensuite.
##
## Mise en page en CONTENEURS, pas en coordonnees absolues : la maquette est
## dessinee en 402 x 874, le projet tourne en 393 x 852, et un telephone
## reel fait encore autre chose. Les trois blocs sont donc repartis par des
## espaceurs extensibles - le "justify-between" de la maquette - plutot que
## poses a des ordonnees fixes.
##

const REVEAL_STAGGER := 0.45
const REVEAL_DURATION := 0.45
const HOLD_DURATION := 1.1
const FADE_DURATION := 0.5

const LOGO_PATH := "res://assets/intro/kings_gambit_logo.png"
const STUDIO_LOGO_PATH := "res://assets/intro/studio_bnl_logo.svg"

## Hauteur reservee a la barre d'etat du systeme, comme sur la maquette : le
## telephone y dessine l'heure et la batterie, on ne les redessine pas.
const STATUS_BAR_HEIGHT := 54.0

## Cadre du logo dans la maquette. Le fichier fourni est un lockup large
## (2172 x 724) : il est CONTENU dans ce cadre, pas recadre dedans.
const LOGO_BOX := Vector2(340, 227)

## Ecart maquette entre le logo et l'indicateur de chargement.
const BRANDING_GAP := 125.0

const STUDIO_LOGO_BOX := Vector2(104, 73)

@onready var _background: TextureRect = $Background
@onready var _content: VBoxContainer = $Safe/Content
@onready var _fade_overlay: ColorRect = $FadeOverlay

var _dots: Array = []


func _ready() -> void:
	_paint_background()

	var logo := _build_logo()
	var loading_group := _build_loading_group()
	var credit_group := _build_credit_group()

	for group in [logo, loading_group, credit_group]:
		group.modulate.a = 0.0

	_start_dot_chase()

	await _reveal_sequence([logo, loading_group, credit_group])
	await get_tree().create_timer(HOLD_DURATION).timeout
	await _fade_to_black()

	if Game.has_seen_intro():
		Router.goto_village()
	else:
		Router.goto_intro()


# ------------------------------- CONSTRUCTION --------------------------------

## Degrade radial violet-noir, du centre vers les bords (#1e112a -> #0c0614
## dans la maquette). Un degrade genere plutot qu'une image : aucun asset a
## embarquer, et il reste net a n'importe quelle definition d'ecran.
func _paint_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("1e112a"))
	gradient.set_color(1, Color("0c0614"))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_background.texture = texture


## Les trois blocs de la maquette, separes par des espaceurs qui absorbent
## toute la hauteur disponible.
func _build_logo() -> Control:
	var status_spacer := Control.new()
	status_spacer.custom_minimum_size = Vector2(0, STATUS_BAR_HEIGHT)
	status_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(status_spacer)

	_content.add_child(_expanding_spacer())

	var logo := TextureRect.new()
	if ResourceLoader.exists(LOGO_PATH):
		logo.texture = load(LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# CONTENU dans son cadre, jamais recadre : le lockup est trois fois plus
	# large que haut, le rogner couperait la couronne ou le texte.
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = LOGO_BOX
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(logo)
	return logo


## "CHARGEMENT" + trois points qui s'illuminent tour a tour, cf. Loading
## Indicator de la maquette.
func _build_loading_group() -> VBoxContainer:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, BRANDING_GAP)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(gap)

	var group := VBoxContainer.new()
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 12)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(group)

	var label := UiTheme.make_label("CHARGEMENT", 13, Color("a39cb5"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	group.add_child(label)

	var dots_row := HBoxContainer.new()
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 8)
	dots_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.add_child(dots_row)

	# Trois pastilles dessinees plutot que l'image de la maquette : elles
	# doivent s'allumer l'une apres l'autre, ce qu'un SVG fige ne fait pas.
	_dots.clear()
	for i in range(3):
		var dot := Icon.new()
		dot.icon_name = "dot"
		dot.color = UiTheme.GOLD
		dot.custom_minimum_size = Vector2(8, 8)
		dot.modulate.a = 0.35
		dots_row.add_child(dot)
		_dots.append(dot)

	_content.add_child(_expanding_spacer())
	return group


func _build_credit_group() -> VBoxContainer:
	var group := VBoxContainer.new()
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 4)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(group)

	var label := UiTheme.make_label("EDITED BY", 11, Color("a39cb5"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	group.add_child(label)

	if ResourceLoader.exists(STUDIO_LOGO_PATH):
		var studio_logo := TextureRect.new()
		studio_logo.texture = load(STUDIO_LOGO_PATH)
		studio_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		studio_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		studio_logo.custom_minimum_size = STUDIO_LOGO_BOX
		studio_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		studio_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(studio_logo)

	# Marge basse de la maquette, sous le credit.
	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 24)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bottom)

	return group


func _expanding_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


# ------------------------------- ANIMATION -----------------------------------

func _reveal_sequence(groups: Array) -> void:
	for group in groups:
		var tween := create_tween()
		tween.tween_property(group, "modulate:a", 1.0, REVEAL_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(REVEAL_STAGGER).timeout


func _fade_to_black() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


## Chaque point s'illumine puis s'estompe a son tour, en boucle - un chapelet
## plutot qu'un pulse synchronise, cf. Loading Dots de la maquette.
func _start_dot_chase() -> void:
	if _dots.is_empty():
		return
	var tween := create_tween()
	tween.set_loops()
	tween.set_meta("boucle", true)
	for dot in _dots:
		tween.tween_property(dot, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		tween.tween_property(dot, "modulate:a", 0.35, 0.22).set_trans(Tween.TRANS_SINE)
