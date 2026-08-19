extends Control
##
## SPLASH SCREEN - premier ecran au lancement.
##
## Le logo, l'indicateur de chargement puis le credit apparaissent l'un apres
## l'autre (pas tous d'un coup), puis l'ecran entier fond au noir avant de
## passer a la suite : le dialogue d'introduction du Roi la toute premiere
## fois (cf. GameState.has_seen_intro), le village ensuite.
##

const REVEAL_STAGGER := 0.45
const REVEAL_DURATION := 0.45
const HOLD_DURATION := 1.1
const FADE_DURATION := 0.5

const LOGO_PATH := "res://assets/intro/kings_gambit_logo.png"
const STUDIO_LOGO_PATH := "res://assets/intro/studio_bnl_logo.svg"

@onready var _content: Control = $Content
@onready var _fade_overlay: ColorRect = $FadeOverlay

var _dots: Array = []


func _ready() -> void:
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

func _build_logo() -> TextureRect:
	var logo := TextureRect.new()
	if ResourceLoader.exists(LOGO_PATH):
		logo.texture = load(LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var size := 240.0
	logo.custom_minimum_size = Vector2(size, size)
	logo.size = Vector2(size, size)
	logo.position = Vector2((393.0 - size) / 2.0, 190)
	logo.clip_contents = true
	_content.add_child(logo)
	return logo


## "CHARGEMENT" + trois points qui s'illuminent tour a tour, cf. Loading
## Indicator de la maquette Figma.
func _build_loading_group() -> VBoxContainer:
	var group := VBoxContainer.new()
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 12)
	group.position = Vector2(0, 470)
	group.size = Vector2(393, 40)
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

	_dots.clear()
	for i in range(3):
		var dot := Icon.new()
		dot.icon_name = "dot"
		dot.color = UiTheme.GOLD
		dot.custom_minimum_size = Vector2(8, 8)
		dot.modulate.a = 0.35
		dots_row.add_child(dot)
		_dots.append(dot)

	return group


func _build_credit_group() -> VBoxContainer:
	var group := VBoxContainer.new()
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 6)
	group.position = Vector2(0, 770)
	group.size = Vector2(393, 60)
	_content.add_child(group)

	var label := UiTheme.make_label("EDITED BY", 10, Color("a39cb5"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	group.add_child(label)

	if ResourceLoader.exists(STUDIO_LOGO_PATH):
		var studio_logo := TextureRect.new()
		studio_logo.texture = load(STUDIO_LOGO_PATH)
		studio_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		studio_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		studio_logo.custom_minimum_size = Vector2(40, 28)
		studio_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		group.add_child(studio_logo)

	return group


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
## plutot qu'un pulse synchronise, cf. Loading Dots de la maquette Figma.
func _start_dot_chase() -> void:
	if _dots.is_empty():
		return
	var tween := create_tween()
	tween.set_loops()
	for dot in _dots:
		tween.tween_property(dot, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		tween.tween_property(dot, "modulate:a", 0.35, 0.22).set_trans(Tween.TRANS_SINE)
