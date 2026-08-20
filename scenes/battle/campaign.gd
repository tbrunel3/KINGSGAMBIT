extends Control
##
## CAMPAGNE - carte de progression, chemin trace sur le parchemin.
##
## La carte Figma (02_Campagne) fait 1440px de haut pour un ecran de 852 -
## elle est pensee pour defiler, pas pour tout montrer d'un coup. Cette scene
## vit donc dans un ScrollContainer : tout ce qui compose la carte (planches,
## parchemin, pastilles, chemin en pointilles) est a l'interieur et defile ;
## la pastille de progression, la barre du bas et les fondus de bord restent
## fixes par dessus.
##
## Sert autant a progresser qu'a REJOUER : une bataille deja gagnee reste
## accessible pour refaire de l'or, a taux reduit (Balance.REPLAY_REWARD_RATIO).
##

## Hauteur totale de la carte defilante. Les dix pastilles y sont reparties
## le long de la meme courbe en S que la maquette Figma (5 points mesures,
## prolonges), mise a l'echelle sur cette hauteur plutot que compressee dans
## un seul ecran.
const CONTENT_HEIGHT := 2000.0
const CONTENT_WIDTH := 393.0

const NODE_POS := [
	Vector2(194.7, 1850.1),
	Vector2(174.2, 1634.9),
	Vector2(153.6, 1419.2),
	Vector2(170.0, 1221.2),
	Vector2(198.8, 1028.3),
	Vector2(206.9, 832.9),
	Vector2(194.7, 634.6),
	Vector2(177.4, 452.0),
	Vector2(145.2, 315.9),
	Vector2(112.9, 180.0),
]

const WON_COLOR := Color("339940")
const AVAILABLE_COLOR := Color("ffd11a")
const LOCKED_COLOR := Color("594d38")

## Position visible / masquee de la barre "VILLAGE", cf. _set_bottom_bar_visible().
const BOTTOM_BAR_VISIBLE_Y := 800.0
const BOTTOM_BAR_HIDDEN_Y := 920.0

@onready var _scroll: ScrollContainer = $Scroll
@onready var _content: Control = $Scroll/Content
@onready var _planks: Control = $Scroll/Content/Planks
@onready var _path_dots: Control = $Scroll/Content/PathDots
@onready var _map_overlay: Control = $Scroll/Content/MapOverlay
@onready var _fixed_overlay: Control = $FixedOverlay
@onready var _bottom_bar: Control = $BottomBar
@onready var _fade_overlay: ColorRect = $FadeOverlay

var _progress_pill: Pill
var _nodes: Dictionary = {}   # id -> {"circle":.., "label":..}
var _village_button: PanelContainer

var _last_scroll_y: float = 0.0
var _bottom_bar_visible: bool = true
var _bottom_bar_tween: Tween
var _transitioning: bool = false


func _ready() -> void:
	_content.custom_minimum_size = Vector2(CONTENT_WIDTH, CONTENT_HEIGHT)
	_size_scroll_children()
	_build_planks()
	_build_path_dots()
	_build_progress_pill()
	for data in Balance.CAMPAIGN:
		_build_node(int(data["id"]), String(data["name"]))
	_build_village_button()
	_refresh()

	# Ouvre la carte sur la bataille en cours plutot que sur le sommet
	# (batailles verrouillees). On attend que la barre de defilement ait
	# elle-meme fini de mesurer sa plage complete avant de fixer la position -
	# un compte de frames fixe n'est pas fiable partout (le Web en particulier
	# peut prendre plusieurs images pour stabiliser ce layout).
	var vbar := _scroll.get_v_scroll_bar()
	var guard := 0
	while vbar.max_value < CONTENT_HEIGHT - 1.0 and guard < 20:
		await get_tree().process_frame
		guard += 1
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	_scroll.scroll_vertical = int(maxf(0.0, CONTENT_HEIGHT - _scroll.size.y))
	_last_scroll_y = _scroll.scroll_vertical


func _process(_delta: float) -> void:
	var current_y := float(_scroll.scroll_vertical)
	var delta_y := current_y - _last_scroll_y
	# Un seuil evite que le moindre tremblement (rebond en butee haute/basse,
	# molette a cran) ne fasse clignoter la barre.
	if absf(delta_y) > 1.5:
		_set_bottom_bar_visible(delta_y > 0.0)
	_last_scroll_y = current_y


func _size_scroll_children() -> void:
	for child in [_planks, _path_dots, _map_overlay]:
		child.set_anchors_preset(Control.PRESET_FULL_RECT)
		child.mouse_filter = Control.MOUSE_FILTER_PASS if child == _map_overlay else Control.MOUSE_FILTER_IGNORE

	var shadow: ColorRect = $Scroll/Content/ParchmentShadow
	shadow.position = Vector2(19, 40)
	shadow.size = Vector2(363, CONTENT_HEIGHT - 60)

	var parchment: TextureRect = $Scroll/Content/Parchment
	parchment.position = Vector2(15, 36)
	parchment.size = Vector2(363, CONTENT_HEIGHT - 60)


## Lattes de bois horizontales derriere le parchemin, cf. CLAUDE.md > 02_Campagne -
## etirees sur toute la hauteur defilante plutot que sur le seul ecran visible.
func _build_planks() -> void:
	var tones := [Color("3b2b1c"), Color("423324"), Color("4a3b2b")]
	var plank_h := 72.0
	var count := ceili(CONTENT_HEIGHT / plank_h)
	for i in range(count):
		var rect := ColorRect.new()
		rect.color = tones[i % tones.size()]
		rect.position = Vector2(0, i * plank_h)
		rect.size = Vector2(CONTENT_WIDTH, plank_h)
		_planks.add_child(rect)


## Chemin en pointilles reliant les pastilles - trace au dessin (cf.
## path_dots.gd) plutot que baque dans l'image, pour suivre NODE_POS quelle
## que soit la hauteur de la carte.
func _build_path_dots() -> void:
	_path_dots.set_path(NODE_POS)


## Pastille de progression calee sur le bord droit REEL du calque, une image
## apres le rafraichissement : sa largeur depend du texte, et juste apres
## set_custom() elle vaut encore zero.
func _place_progress_pill() -> void:
	if not is_instance_valid(_progress_pill):
		return
	# Ancree au bord droit plutot que posee a une abscisse calculee : sa
	# largeur depend du texte et n'est connue qu'apres la mise en page. Avec
	# les deux bords ancres a droite et grow_horizontal = BEGIN, c'est le
	# moteur qui lui donne sa largeur minimale et la fait grandir vers la
	# gauche - plus rien a calculer, a aucun moment.
	_progress_pill.anchor_left = 1.0
	_progress_pill.anchor_right = 1.0
	_progress_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_progress_pill.offset_left = -16.0
	_progress_pill.offset_right = -16.0
	_progress_pill.offset_top = 20.0
	_progress_pill.offset_bottom = 20.0 + _progress_pill.get_combined_minimum_size().y


func _build_progress_pill() -> void:
	_progress_pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_fixed_overlay.add_child(_progress_pill)


func _build_node(id: int, battle_name: String) -> void:
	var center: Vector2 = NODE_POS[id - 1]

	var circle := PanelContainer.new()
	_map_overlay.add_child(circle)
	circle.mouse_filter = Control.MOUSE_FILTER_STOP
	circle.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_node_pressed(id))

	var glyph := Control.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(glyph)

	var label := PanelContainer.new()
	_map_overlay.add_child(label)
	var label_text := UiTheme.make_label(battle_name, 12, UiTheme.TEXT)
	label_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	var label_margin := MarginContainer.new()
	label_margin.add_theme_constant_override("margin_left", 10)
	label_margin.add_theme_constant_override("margin_right", 10)
	label_margin.add_theme_constant_override("margin_top", 5)
	label_margin.add_theme_constant_override("margin_bottom", 5)
	label_margin.add_child(label_text)
	label.add_child(label_margin)

	_nodes[id] = {"circle": circle, "glyph": glyph, "label": label, "label_text": label_text, "center": center}


## Barre "VILLAGE" fixe par dessus la carte (pas posee sur le parchemin comme
## en Figma) : c'est elle qui glisse hors ecran au scroll, cf.
## _set_bottom_bar_visible().
func _build_village_button() -> void:
	_village_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("261a0d", 0.9)
	box.set_corner_radius_all(14)
	box.border_color = Color("99804d", 0.4)
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	_village_button.add_theme_stylebox_override("panel", box)
	_village_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_village_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Router.goto_village())
	_bottom_bar.add_child(_village_button)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_village_button.add_child(row)
	var icon := Icon.new()
	icon.icon_name = "house"
	icon.color = Color("d9c78c")
	icon.custom_minimum_size = Vector2(14, 14)
	row.add_child(icon)
	var text := UiTheme.make_label("VILLAGE", 13, Color("d9c78c"))
	text.add_theme_font_override("font", UiTheme.font_bold())
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(text)
	UiTheme.ignore_mouse_recursive(row)

	# Sans ceci le bouton reste a (0,0) - PanelContainer ne se centre jamais
	# tout seul en layout_mode manuel. Cf. capture Figma 02 : centre en bas.
	_village_button.size = _village_button.get_combined_minimum_size()
	_village_button.position = Vector2((CONTENT_WIDTH - _village_button.size.x) / 2.0, BOTTOM_BAR_VISIBLE_Y)


## Glisse la barre du bas hors ecran quand on scroll vers le haut (on lit la
## carte, la barre gene) et la ramene quand on scroll vers le bas.
func _set_bottom_bar_visible(should_show: bool) -> void:
	if should_show == _bottom_bar_visible:
		return
	_bottom_bar_visible = should_show

	if _bottom_bar_tween != null and _bottom_bar_tween.is_valid():
		_bottom_bar_tween.kill()

	var target_y := BOTTOM_BAR_VISIBLE_Y if should_show else BOTTOM_BAR_HIDDEN_Y
	_bottom_bar_tween = create_tween()
	_bottom_bar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bottom_bar_tween.tween_property(_village_button, "position:y", target_y, 0.25)


# ------------------------------- RAFRAICHISSEMENT ----------------------------

func _refresh() -> void:
	var unlocked := Game.unlocked_battle()
	var total := Balance.battle_count()
	var won := 0
	for data in Balance.CAMPAIGN:
		if Game.is_battle_won(int(data["id"])):
			won += 1
	_progress_pill.set_custom("", "%d/%d" % [won, total], Color(0, 0, 0, 0.4), Color("ccbf99"), 10, 8, 4)
	_progress_pill.get_node("%Text").add_theme_font_size_override("font_size", 11)
	# Positionnement DIFFERE, et sur la largeur reelle du calque : juste apres
	# set_custom(), la pastille n'a pas encore de taille minimale calculee -
	# on la posait donc a 16 points du bord droit avec une largeur nulle,
	# c'est-a-dire hors de l'ecran.
	_place_progress_pill.call_deferred()

	for data in Balance.CAMPAIGN:
		var id := int(data["id"])
		var refs: Dictionary = _nodes[id]
		var circle: PanelContainer = refs["circle"]
		var glyph: Control = refs["glyph"]
		var label: PanelContainer = refs["label"]
		var center: Vector2 = refs["center"]

		for child in glyph.get_children():
			child.queue_free()

		var state := "locked"
		if Game.is_battle_won(id):
			state = "won"
		elif id <= unlocked:
			state = "available"

		var diameter := 28.0
		var border_width := 1.5
		var bg := LOCKED_COLOR
		var bg_alpha := 0.7
		match state:
			"won":
				diameter = 30.0
				border_width = 2.0
				bg = WON_COLOR
				bg_alpha = 1.0
			"available":
				diameter = 38.0
				border_width = 3.0
				bg = AVAILABLE_COLOR
				bg_alpha = 1.0

		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.bg_color.a = bg_alpha
		box.set_corner_radius_all(int(diameter))
		box.border_color = Color.WHITE if state != "locked" else Color("807361")
		box.set_border_width_all(int(border_width))
		# Marge de contenu a zero, explicitement : sans ca, PanelContainer se
		# rabat sur une marge "auto" qui decale legerement glyph (donc le
		# chiffre/coche/cadenas) par rapport au centre reel du rond.
		box.set_content_margin_all(0)
		if state == "available":
			box.shadow_color = AVAILABLE_COLOR.darkened(0.1)
			box.shadow_color.a = 0.6
			box.shadow_size = 8
		circle.add_theme_stylebox_override("panel", box)
		circle.custom_minimum_size = Vector2(diameter, diameter)
		circle.size = Vector2(diameter, diameter)
		circle.position = center - circle.size / 2.0

		# "glyph" est un Control nu (pas un Container) : il ne repositionne
		# jamais tout seul son propre contenu. On fixe donc position ET size a
		# la main plutot que de ne compter que sur custom_minimum_size, qui
		# n'a aucun effet hors d'un Container.
		match state:
			"won":
				var check := Icon.new()
				check.icon_name = "check"
				check.color = Color.WHITE
				check.position = Vector2.ZERO
				check.size = Vector2(diameter, diameter)
				glyph.add_child(check)
			"available":
				var number := UiTheme.make_label(str(id), 17, Color("1a1206"))
				number.add_theme_font_override("font", UiTheme.font_bold())
				number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				number.position = Vector2.ZERO
				number.size = Vector2(diameter, diameter)
				number.autowrap_mode = TextServer.AUTOWRAP_OFF
				glyph.add_child(number)
			"locked":
				var lock := Icon.new()
				lock.icon_name = "lock"
				lock.color = Color("807361")
				lock.position = Vector2.ZERO
				lock.size = Vector2(diameter, diameter)
				glyph.add_child(lock)
		UiTheme.ignore_mouse_recursive(glyph)

		var box_label := StyleBoxFlat.new()
		box_label.bg_color = Color("1f140a", 0.75)
		box_label.set_corner_radius_all(8)
		label.add_theme_stylebox_override("panel", box_label)
		var label_text: Label = refs["label_text"]
		label_text.add_theme_color_override("font_color",
			Color("d9cca6") if state == "won" else (Color("ffe580") if state == "available" else Color("807361")))
		label.size = label.get_combined_minimum_size()
		# Le label part a droite de la pastille ; s'il deborderait du parchemin,
		# on le bascule a gauche.
		var label_x := center.x + diameter / 2.0 + 8.0
		if label_x + label.size.x > 378.0:
			label_x = center.x - diameter / 2.0 - 8.0 - label.size.x
		label.position = Vector2(label_x, center.y - label.size.y / 2.0)


# ------------------------------- ACTIONS -------------------------------------

func _on_node_pressed(id: int) -> void:
	if _transitioning or id > Game.unlocked_battle():
		return
	_play_transition(id)


## Petit zoom sur la pastille tapee, fondu au noir, puis changement d'ecran -
## un aller-retour plat vers la preparation manquait de poids.
func _play_transition(id: int) -> void:
	_transitioning = true
	var node_center: Vector2 = NODE_POS[id - 1]
	var viewport_pos := node_center - Vector2(0, _scroll.scroll_vertical)
	_scroll.pivot_offset = viewport_pos

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_scroll, "scale", Vector2(1.22, 1.22), 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.38) \
		.set_delay(0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

	Router.goto_prep(id)
