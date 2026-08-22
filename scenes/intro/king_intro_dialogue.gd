extends Control
##
## DIALOGUE D'INTRODUCTION - le Roi explique la disparition de la Dame.
##
## Ne se montre qu'une fois (cf. GameState.has_seen_intro, verifie par
## splash_screen.gd) : un joueur qui revient au village ne le revoit pas.
##
## Deux temps, comme la maquette V2 (frames king-intro-before-dialogue et
## king-intro-dialogue) :
##
##   1. APPROCHE  le Roi seul sur son trone, et une invite discrete en bas :
##                "S'APPROCHER DU TRONE >". L'ecran attend le doigt du joueur,
##                rien ne se declenche tout seul.
##   2. DIALOGUE  au premier contact, l'illustration part en zoom lent, la
##                bulle apparait, le texte s'ecrit lettre par lettre, puis le
##                bouton "COMMENCER" se debloque.
##
## Ne se montre qu'une fois (cf. GameState.has_seen_intro, verifie par
## splash_screen.gd) : un joueur qui revient au village ne le revoit pas.
##

signal _tapped

const BG_PATH := "res://assets/intro/king_throne_background.png"

const DIALOGUE_TEXT := "\"Ma Dame s'est fait enlever... Soulevez une armée et ramenez-la, et je vous couvrirai d'or.\""

const ZOOM_TARGET := 1.12
const ZOOM_DURATION := 14.0
const PANEL_DELAY := 0.5
const PANEL_DURATION := 0.5

# ------------------------------- TIMELINE FIGMA -------------------------------
#
#  La frame king-intro-dialogue (123:32) porte une VRAIE timeline Figma, relevee
#  avec get_motion_context : 3 secondes, six noeuds qui entrent en cascade. Ce
#  n'est pas une boucle malgre ce qu'en montre l'apercu - Figma rejoue l'entree
#  en rond faute de savoir qu'elle ne se joue qu'une fois.
#
#  Ce qui en est repris, c'est ce que le jeu n'avait pas : les deux ELEVATIONS.
#  Le panneau et le bouton n'apparaissaient qu'en fondu, a plat. Dans la
#  maquette ils MONTENT en apparaissant - 20 points pour la bulle, 15 pour le
#  bouton - et c'est ce mouvement qui leur donne le poids d'un objet qui se pose.
#
#  Ce qui n'en est PAS repris, et pourquoi :
#
#    - la frappe lettre par lettre du dialogue n'existe pas dans Figma. C'est un
#      ajout du jeu, et il vaut mieux que le fondu qu'il remplace.
#    - le fondu des DEUX calques d'illustration (0-1 s puis 1,2-1,8 s) sert a
#      Figma a empiler deux images ; le jeu n'en a qu'une.
#
#  Le zoom lent de 14 secondes reste : il est ambiant, la ou la maquette decrit
#  une ENTREE. Les deux ne s'excluent pas, ils s'enchainent (cf. _start_zoom).

## Elevation de la bulle et du bouton a leur apparition (Figma : translate y).
const PANEL_RISE := 20.0
const BUTTON_RISE := 15.0

## Echelle de depart de l'illustration, qui se pose ensuite sur 1,2 s
## (Figma : scale 1.08 -> 1, cubic-bezier(0.25, 0, 0.35, 1)).
const SETTLE_SCALE := 1.08
const SETTLE_DURATION := 1.2

## Delai avant que l'invite du premier ecran apparaisse (Figma
## king-intro-before-dialogue : opacite tenue a zero jusqu'a 40 % d'une boucle
## de 2,5 s). Le Roi doit se laisser regarder avant qu'on propose de s'approcher.
const HINT_DELAY := 1.0
const TYPE_CHAR_DELAY := 0.032
const FADE_DURATION := 0.4

const BUBBLE_COLOR := Color("f5efe2", 0.878)
const BUBBLE_STROKE := Color("ffd700", 0.451)

## Geometrie de la maquette V2 (frame king-intro-dialogue, revision du
## 21/08) : la bulle ne tient plus toute la largeur, elle fait 302 points et
## se centre ; le bouton, lui, est large et bas, ancre au bord inferieur.
const BUBBLE_WIDTH := 302.0
const BUTTON_MARGIN := 26.0
const BUTTON_HEIGHT := 90.0
## Distance entre le bas du bouton et le bas de l'ecran.
const BUTTON_BOTTOM_GAP := 102.0
## Ecart entre la bulle et le bouton.
const BUBBLE_BUTTON_GAP := 16.0

const HINT_TEXT := "S'APPROCHER DU TRÔNE"

@onready var _background_wrap: Control = $BackgroundWrap
@onready var _background: TextureRect = $BackgroundWrap/Background
@onready var _overlay: Control = $Overlay
@onready var _fade_overlay: ColorRect = $FadeOverlay

var _dialogue_label: Label
var _commencer_button: PanelContainer
var _commencer_ready: bool = false
var _tap_catcher: Control = null
var _hint_pulse: Tween = null


func _ready() -> void:
	_build_background()
	_build_gradients()

	# Premier temps : le Roi attend qu'on vienne a lui.
	var hint := _build_approach_hint()
	_tap_catcher = _build_tap_catcher()
	await _tapped
	await _dismiss_approach(hint)

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


## Invite du premier temps : un libelle discret et un chevron, en bas de
## l'ecran, qui respirent doucement pour montrer que l'ecran attend un geste
## (cf. "Action Hint Container" de la maquette, opacite 70 %).
func _build_approach_hint() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -70.0
	row.offset_bottom = -34.0
	row.modulate.a = 0.7
	_overlay.add_child(row)

	var label := UiTheme.make_label(HINT_TEXT, 13, Color(1, 1, 1, 0.8))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# make_label() renvoie un libelle en EXPAND_FILL : dans une rangee large
	# comme l'ecran, il pousserait le chevron a l'autre bout au lieu de rester
	# groupe avec lui au centre.
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	var chevron := Icon.new()
	chevron.icon_name = "chevron_right"
	chevron.color = Color(1, 1, 1, 0.8)
	chevron.custom_minimum_size = Vector2(12, 12)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)

	# L'invite ARRIVE, elle n'est pas la d'emblee : la maquette la tient a zero
	# pendant les quatre premiers dixiemes de sa boucle. Le Roi doit se laisser
	# regarder avant qu'on propose de s'en approcher.
	#
	# Elle respire ensuite, la ou Figma la fait revenir a zero d'un coup a chaque
	# tour de boucle : un apercu qui reboucle n'est pas une intention d'animation,
	# et un clignotement franc jurerait sur un ecran contemplatif.
	row.modulate.a = 0.0
	var entree := create_tween()
	entree.tween_interval(HINT_DELAY)
	var apparition := entree.tween_property(row, "modulate:a", 0.7, 0.8)
	apparition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_hint_pulse = create_tween()
	_hint_pulse.stop()
	_hint_pulse.set_loops()
	_hint_pulse.tween_property(row, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	_hint_pulse.tween_property(row, "modulate:a", 0.7, 1.1).set_trans(Tween.TRANS_SINE)
	entree.finished.connect(func():
		if _hint_pulse != null and _hint_pulse.is_valid():
			_hint_pulse.play()
	)

	return row


## Capte le premier contact n'importe ou sur l'ecran - la maquette rend la
## frame entiere cliquable. Il disparait ensuite, sinon il avalerait les
## clics destines au bouton COMMENCER.
func _build_tap_catcher() -> Control:
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_tapped.emit()
	)
	add_child(catcher)
	return catcher


func _dismiss_approach(hint: Control) -> void:
	# Arreter la respiration AVANT de liberer l'invite : une boucle de tween
	# dont la cible a disparu boucle en temps nul, et Godot la signale comme
	# une boucle infinie.
	if _hint_pulse != null and _hint_pulse.is_valid():
		_hint_pulse.kill()
	_hint_pulse = null

	if is_instance_valid(_tap_catcher):
		_tap_catcher.queue_free()
		_tap_catcher = null
	var tween := create_tween()
	tween.tween_property(hint, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	await tween.finished
	hint.queue_free()


## Raccourci pour les outils de developpement (captures, tests) : declenche
## l'approche sans passer par un vrai clic.
func skip_approach() -> void:
	_tapped.emit()


## Bulle de dialogue et bouton "COMMENCER", places comme dans la maquette V2 :
## une bulle etroite centree, un large bouton dessous.
##
## Les deux sont ANCRES au bord inferieur plutot que poses a une ordonnee
## fixe : la maquette est dessinee en 402 x 874, le jeu tourne en 393 x 852,
## et un telephone reel fait encore autre chose. La bulle grandit vers le
## haut si le texte s'allonge, le bouton ne bouge pas.
func _build_dialogue_area() -> Dictionary:
	var button := _build_commencer_button()
	_overlay.add_child(button)
	button.anchor_left = 0.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.offset_left = BUTTON_MARGIN
	button.offset_right = -BUTTON_MARGIN
	button.offset_top = -(BUTTON_BOTTOM_GAP + BUTTON_HEIGHT)
	button.offset_bottom = -BUTTON_BOTTOM_GAP

	var panel := _build_dialogue_panel()
	_overlay.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -BUBBLE_WIDTH * 0.5
	panel.offset_right = BUBBLE_WIDTH * 0.5
	panel.offset_bottom = -(BUTTON_BOTTOM_GAP + BUTTON_HEIGHT + BUBBLE_BUTTON_GAP)
	panel.offset_top = panel.offset_bottom

	# La pointe deborde au-dessus de la bulle : elle vit hors du panneau et se
	# recale sur lui une fois sa hauteur connue.
	var tail := _build_speech_tail()
	_overlay.add_child(tail)
	# La bulle grandit VERS LE HAUT au fur et a mesure que sa hauteur se
	# calcule : poser la pointe une seule fois, en differe, la laissait au
	# milieu du texte. Elle se recale a chaque changement de taille.
	panel.resized.connect(_place_tail.bind(panel, tail))
	_place_tail.call_deferred(panel, tail)

	return {"panel": panel, "tail": tail, "button": button}


## La pointe se cale sur le bord superieur de la bulle, un peu a gauche du
## centre comme dans la maquette (elle vise le Roi, pas le milieu).
func _place_tail(panel: PanelContainer, tail: Control) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(tail):
		return
	tail.position = Vector2(
		panel.position.x + panel.size.x * 0.5 - 36.0,
		panel.position.y - tail.size.y + 1.0)


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
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_override("font", UiTheme.font_dialogue())
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
	box.set_corner_radius_all(12)
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	button.add_theme_stylebox_override("panel", box)
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)

	var label := UiTheme.make_label("COMMENCER", 19, Color("0c0614"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)

	UiTheme.ignore_mouse_recursive(row)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.gui_input.connect(func(event: InputEvent):
		if _commencer_ready and event is InputEventMouseButton \
				and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_commencer_pressed())

	return button


# ------------------------------- ANIMATION -----------------------------------

## L'illustration se POSE, puis derive.
##
## Deux mouvements a la suite, et ils viennent de deux endroits : la maquette
## decrit une ENTREE - l'image arrive a 1,08 et se pose sur 1,2 s - la ou l'on
## voulait un zoom ambiant qui dure tout l'ecran. Les enchainer donne les deux :
## l'image se pose comme un objet qu'on repose, puis elle respire.
func _start_zoom() -> void:
	var tween := create_tween()
	_background_wrap.scale = Vector2(SETTLE_SCALE, SETTLE_SCALE)
	var pose := tween.tween_property(_background_wrap, "scale", Vector2.ONE, SETTLE_DURATION)
	pose.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var derive := tween.tween_property(_background_wrap, "scale",
		Vector2(ZOOM_TARGET, ZOOM_TARGET), ZOOM_DURATION)
	derive.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## La bulle MONTE en apparaissant, elle ne fait pas que se fondre.
##
## Figma anime opacite ET translation ensemble, sur une cubic-bezier
## (0.16, 1, 0.3, 1) : une deceleration franche, sans rebond. TRANS_EXPO en
## EASE_OUT la rend de tres pres, et c'est ce mouvement qui donne a la bulle le
## poids d'un objet qu'on pose plutot que d'une image qu'on allume.
func _reveal_panel(panel: PanelContainer, tail: Control) -> void:
	var arrivee := panel.position.y
	panel.position.y = arrivee + PANEL_RISE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, PANEL_DURATION).set_trans(Tween.TRANS_SINE)
	tween.tween_property(tail, "modulate:a", 1.0, PANEL_DURATION).set_trans(Tween.TRANS_SINE)
	var montee := tween.tween_property(panel, "position:y", arrivee, PANEL_DURATION)
	montee.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
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
	var arrivee := _commencer_button.position.y
	_commencer_button.position.y = arrivee + BUTTON_RISE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_commencer_button, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	var montee := tween.tween_property(_commencer_button, "position:y", arrivee, 0.5)
	montee.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _on_commencer_pressed() -> void:
	_commencer_ready = false
	Game.mark_intro_seen()
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await tween.finished
	Router.goto_village()
