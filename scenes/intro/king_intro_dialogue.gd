extends Control
##
## DIALOGUE D'INTRODUCTION - le Roi explique la disparition de la Dame.
##
## Ne se montre qu'une fois (cf. GameState.has_seen_intro, verifie par
## splash_screen.gd) : un joueur qui revient au village ne le revoit pas.
##
## Sequence : l'illustration du Roi commence a zoomer lentement des l'ouverture,
## la bulle de dialogue apparait par dessus, le texte s'ecrit lettre par
## lettre, puis le bouton "COMMENCER" se debloque une fois le texte fini.
##

const BG_PATH := "res://assets/intro/king_throne_background.png"

const DIALOGUE_TEXT := "\"Ma Dame s'est fait enlever... Soulevez une armée et ramenez-la, et je vous couvrirai d'or.\""

const ZOOM_TARGET := 1.12
const ZOOM_DURATION := 14.0
const PANEL_DELAY := 0.5
const PANEL_DURATION := 0.5
const TYPE_CHAR_DELAY := 0.032
const FADE_DURATION := 0.4

const BUBBLE_COLOR := Color("f5efe2", 0.878)
const BUBBLE_STROKE := Color("ffd700", 0.451)

@onready var _background_wrap: Control = $BackgroundWrap
@onready var _background: TextureRect = $BackgroundWrap/Background
@onready var _overlay: Control = $Overlay
@onready var _fade_overlay: ColorRect = $FadeOverlay

var _dialogue_label: Label
var _commencer_button: PanelContainer
var _commencer_ready: bool = false


func _ready() -> void:
	_build_background()
	_build_gradients()

	var area := _build_dialogue_area()
	var panel: PanelContainer = area["panel"]
	var tail: Control = area["tail"]
	_commencer_button = area["button"]

	panel.modulate.a = 0.0
	tail.modulate.a = 0.0
	_commencer_button.modulate.a = 0.5

	_start_zoom()
	await get_tree().create_timer(PANEL_DELAY).timeout
	await _reveal_panel(panel, tail)
	await _type_dialogue()
	_unlock_button()


# ------------------------------- CONSTRUCTION --------------------------------

func _build_background() -> void:
	if ResourceLoader.exists(BG_PATH):
		_background.texture = load(BG_PATH)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_wrap.pivot_offset = Vector2(196.5, 426)


## Vignette sombre en haut (lisibilite de la barre de statut) + degrade vers
## le noir en bas (lisibilite du bouton), cf. maquette Figma.
func _build_gradients() -> void:
	var top := _gradient_rect(Vector2(0, 0), Vector2(393, 120), Color("0c0614", 0.4), Color("0c0614", 0.0))
	_overlay.add_child(top)

	var bottom := _gradient_rect(Vector2(0, 380), Vector2(393, 472), Color("0c0614", 0.0), Color("0c0614", 0.97))
	_overlay.add_child(bottom)


func _gradient_rect(pos: Vector2, size: Vector2, top_color: Color, bottom_color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([top_color, bottom_color])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = int(size.y)

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = pos
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Bulle de dialogue (fond clair, pas de cadre dore, petite pointe vers le
## Roi) + bouton "COMMENCER", empiles comme le "Dialogue and Controls Area"
## de la maquette Figma - un VBoxContainer plutot que des positions fixes,
## pour que le bouton suive si la bulle change de hauteur (texte plus long).
func _build_dialogue_area() -> Dictionary:
	var area := VBoxContainer.new()
	area.add_theme_constant_override("separation", 16)
	area.position = Vector2(20, 546)
	area.size = Vector2(353, 0)
	_overlay.add_child(area)

	# La pointe deborde au-dessus de la bulle : elle vit hors du VBoxContainer,
	# positionnee a la main juste avant que celui-ci ne soit ajoute au parent.
	var tail := _build_speech_tail()
	_overlay.add_child(tail)

	var panel := _build_dialogue_panel()
	area.add_child(panel)
	panel.custom_minimum_size = Vector2(0, 0)

	var button := _build_commencer_button()
	area.add_child(button)

	# La pointe se cale sur le centre de la bulle une fois sa largeur connue.
	tail.position = Vector2(area.position.x + area.size.x / 2.0 - 12.0, area.position.y - 12.0)

	return {"panel": panel, "tail": tail, "button": button}


func _build_speech_tail() -> Control:
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.size = Vector2(24, 14)

	var points := PackedVector2Array([Vector2(0, 14), Vector2(12, 0), Vector2(24, 14)])
	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = BUBBLE_COLOR
	tail.add_child(fill)

	var outline := Line2D.new()
	outline.points = points
	outline.default_color = BUBBLE_STROKE
	outline.width = 1.0
	tail.add_child(outline)

	return tail


func _build_dialogue_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = BUBBLE_COLOR
	box.set_corner_radius_all(16)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 20
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 20
	panel.add_theme_stylebox_override("panel", box)

	_dialogue_label = Label.new()
	_dialogue_label.text = DIALOGUE_TEXT
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_font_size_override("font_size", 22)
	_dialogue_label.add_theme_color_override("font_color", Color("0c0614"))
	_dialogue_label.add_theme_constant_override("line_spacing", 10)
	_dialogue_label.visible_characters = 0
	panel.add_child(_dialogue_label)

	return panel


func _build_commencer_button() -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.GOLD
	box.border_color = Color("b8860b")
	box.set_border_width_all(2)
	box.set_corner_radius_all(18)
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	box.shadow_color = Color("ffbf00", 0.45)
	box.shadow_size = 12
	button.add_theme_stylebox_override("panel", box)
	button.custom_minimum_size = Vector2(0, 63)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var label := UiTheme.make_label("COMMENCER", 19, Color("0c0614"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	var swords := Icon.new()
	swords.icon_name = "sword"
	swords.color = Color("0c0614")
	swords.custom_minimum_size = Vector2(20, 20)
	row.add_child(swords)

	UiTheme.ignore_mouse_recursive(row)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.gui_input.connect(func(event: InputEvent):
		if _commencer_ready and event is InputEventMouseButton \
				and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_commencer_pressed())

	return button


# ------------------------------- ANIMATION -----------------------------------

## Zoom lent et continu sur l'illustration, amorce des l'ouverture de l'ecran -
## cf. consigne : "petit zoom in sur l'illustration du roi triste".
func _start_zoom() -> void:
	var tween := create_tween()
	tween.tween_property(_background_wrap, "scale", Vector2(ZOOM_TARGET, ZOOM_TARGET), ZOOM_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _reveal_panel(panel: PanelContainer, tail: Control) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_DURATION).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tail, "modulate:a", 1.0, PANEL_DURATION).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Ecrit le texte lettre par lettre via visible_characters (Godot le gere
## nativement, y compris les mots coupes en fin de ligne).
func _type_dialogue() -> void:
	var total_chars := DIALOGUE_TEXT.length()
	var tween := create_tween()
	tween.tween_property(_dialogue_label, "visible_characters", total_chars,
		total_chars * TYPE_CHAR_DELAY).set_trans(Tween.TRANS_LINEAR)
	await tween.finished


## Le bouton reste visuellement present mais attenue et inerte tant que le
## texte n'est pas fini - cf. consigne : "le bouton combat se debloque".
func _unlock_button() -> void:
	_commencer_ready = true
	var tween := create_tween()
	tween.tween_property(_commencer_button, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)


func _on_commencer_pressed() -> void:
	_commencer_ready = false
	Game.mark_intro_seen()
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await tween.finished
	Router.goto_village()
