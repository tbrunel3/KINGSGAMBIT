extends Control
##
## VILLAGE - ecran principal : chateau, batiments, or, bouton bataille.
##
## Reproduit la maquette Figma (Figma village-avec-dame, node-id 162:4) en positions
## absolues, avec les coordonnees exactes donnees par CLAUDE.md : chaque
## batiment est un label pose directement sur le fond, pas une liste
## generique. Aucune regle de jeu ici : tout vient de GameState/Balance.
##

const BuildingPopupScene := preload("res://scenes/village/building_popup.tscn")
const MissionPopupScene := preload("res://scenes/village/mission_popup.tscn")
const DevPanelScene := preload("res://scenes/village/dev_panel.tscn")

## Coordonnees relevees sur la maquette V2 (frame village-avec-dame) : chaque
## label est colle au batiment qu'il designe sur le fond illustre.
##
## Les NOMS restent ceux du jeu : la maquette parle d'Atelier, d'Academie et
## de Chapelle, mais le joueur recrute des pions, des cavaliers et des fous.
## Regle de l'import (cf. CLAUDE.md) : le visuel vient de Figma, les regles du
## code.
const CASTLE_POS := Vector2(120, 425)
const BUILDING_POS := {
	"pion": Vector2(57, 240),        # batiment haut-gauche
	"cavalier": Vector2(235, 230),   # batiment haut-droit
	"fou": Vector2(45, 628),         # batiment bas-gauche
	"tour": Vector2(252, 619),       # batiment bas-droit
}
## Teinte de chaque label de batiment (bordure + pastille de niveau) - une
## palette propre a l'UI du Village, distincte des couleurs d'equipe utilisees
## sur la grille de bataille (cf. capture Figma 01 : chaque batiment a sa
## propre couleur d'accent, sans rapport avec Balance.unit_color()).
const BUILDING_ACCENT := {
	"pion": "66a6ff",
	"cavalier": "4dcc66",
	"fou": "b266e5",
	"tour": "e5594d",
}
## Halo du chateau et lumieres qui s'allument aux fenetres quand une Dame est
## rentree : c'est la difference entre les frames village-sans-dame et
## village-avec-dame de la maquette. Positions relevees sur celle-ci.
const CASTLE_GLOW_RECT := Rect2(106, 290, 180, 200)
const GLOW_LIGHTS := [
	{"asset": "glow_window_side.svg", "rect": Rect2(168, 375, 14, 18)},
	{"asset": "glow_window_center.svg", "rect": Rect2(186, 385, 20, 24)},
	{"asset": "glow_window_side.svg", "rect": Rect2(212, 375, 14, 18)},
	{"asset": "glow_tower.svg", "rect": Rect2(173, 345, 10, 14)},
	{"asset": "glow_tower.svg", "rect": Rect2(213, 345, 10, 14)},
	{"asset": "glow_crown.svg", "rect": Rect2(182, 305, 28, 20)},
]

const SCREEN_WIDTH := 393.0
const SCREEN_MARGIN := 8.0
const BATTLE_RECT := Rect2(102, 765, 189, 59)
const TOP_BAR_Y := 44.0
const TOP_BAR_HEIGHT := 30.0
## Fondus haut et bas de la maquette, qui detachent les pastilles et le bouton
## du decor sans assombrir toute l'ile.
const TOP_FADE_HEIGHT := 143.0
const BOTTOM_FADE_TOP := 720.0
const BOTTOM_FADE_HEIGHT := 132.0
const DEV_BUTTON_RECT := Rect2(362, 14, 24, 24)

@onready var _overlay: Control = $Overlay

var _popup: Control = null
var _gold_pill: Pill
var _level_pill: Pill
var _missions_button: PanelContainer
var _missions_label: Label
var _missions_badge: PanelContainer
var _castle_label: PanelContainer
var _castle_glow: TextureRect
var _castle_glow_tween: Tween
var _castle_sub_row: HBoxContainer
var _building_labels: Dictionary = {}   # type -> {"panel":.., "sub_row":..}
var _building_buttons: Dictionary = {}  # type -> panel cliquable (cf. tools/ui_test.gd)
var _battle_button: PanelContainer
var _battle_label: Label


## Hauteur de reference du village. Tous les labels sont poses aux
## coordonnees de la maquette Figma, qui suppose un ecran de 393 x 852.
const DESIGN_HEIGHT := 852.0


func _ready() -> void:
	_fit_overlay_to_design()

	# Avant tout le reste : premier enfant de l'Overlay, donc dessine DERRIERE
	# les labels de batiments.
	_build_castle_glow()
	_build_top_bar()
	_build_castle_label()
	for type in Balance.UNIT_TYPES:
		_build_building_label(type)
	_build_battle_button()
	_build_dev_button()

	Game.gold_changed.connect(func(_g): _refresh())
	Game.units_changed.connect(_refresh)
	Game.buildings_changed.connect(_refresh)
	Game.progress_changed.connect(_refresh)
	Game.missions_changed.connect(_refresh)

	Game.check_upgrades()
	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.timeout.connect(func():
		Game.check_upgrades()
		_refresh())
	add_child(ticker)
	ticker.start()

	_refresh()


# ------------------------------- CONSTRUCTION --------------------------------

## Le village est entierement pose en coordonnees absolues, calees sur la
## maquette 393 x 852 : chaque label est colle a son batiment sur le fond
## illustre. Sur un telephone d'un autre format, le mode d'etirement du
## projet REVELE de la hauteur en plus (873, 880...) et ces coordonnees ne
## veulent plus rien dire - le bouton BATAILLE flotte, les labels glissent.
##
## On garde donc au calque une bande de 852 points de haut, centree
## verticalement : les coordonnees Figma restent vraies partout, et l'espace
## supplementaire montre simplement un peu plus de decor en haut et en bas.
## Le fond illustre, lui, couvre tout l'ecran (il est en dehors de ce calque).
func _fit_overlay_to_design() -> void:
	_overlay.anchor_left = 0.0
	_overlay.anchor_right = 1.0
	_overlay.anchor_top = 0.5
	_overlay.anchor_bottom = 0.5
	_overlay.offset_left = 0.0
	_overlay.offset_right = 0.0
	_overlay.offset_top = -DESIGN_HEIGHT * 0.5
	_overlay.offset_bottom = DESIGN_HEIGHT * 0.5


## Bandeau plein (rgba(10,13,20,0.75), h46, y38) derriere les pastilles -
## cf. capture Figma 01 "Top-Bar" : sans lui les pastilles flottent seules
## sur le fond illustre plutot que de reposer sur une barre continue.
## La maquette V2 ne pose plus de bandeau plein en haut : les pastilles
## reposent sur un simple fondu sombre, qui laisse voir l'ile.
func _build_top_bar() -> void:
	_overlay.add_child(_fade_rect(
		Vector2(0, 0), Vector2(SCREEN_WIDTH, TOP_FADE_HEIGHT),
		Color("0a0d14", 0.65), Color("0a0d14", 0.0)))
	_overlay.add_child(_fade_rect(
		Vector2(0, BOTTOM_FADE_TOP), Vector2(SCREEN_WIDTH, BOTTOM_FADE_HEIGHT),
		Color("0a0d14", 0.0), Color("0a0d14", 0.95)))

	var pill_y := TOP_BAR_Y

	_gold_pill = _place_pill(12, pill_y, "", Pill.Variant.TOPBAR)
	_gold_pill.set_data("dot", "", Pill.Variant.TOPBAR, UiTheme.GOLD)
	_gold_pill.set_bold(true)

	_level_pill = _place_pill(132, pill_y, "", Pill.Variant.TOPBAR)
	_level_pill.set_data("crown", "", Pill.Variant.TOPBAR, Color("ffe580"))
	_level_pill.set_text_color(Color("ffe580"))

	_build_missions_button(pill_y)

	var settings := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("174971")
	box.set_corner_radius_all(14)
	box.set_content_margin_all(7)
	settings.add_theme_stylebox_override("panel", box)
	var gear := Icon.new()
	gear.icon_name = "wrench"
	gear.color = Color("ccccd9")
	gear.custom_minimum_size = Vector2(14, 14)
	settings.add_child(gear)
	_overlay.add_child(settings)
	settings.position = Vector2(353, TOP_BAR_Y)
	settings.size = Vector2(28, 28)


## Bandeau degrade vertical, pose sur le decor.
func _fade_rect(pos: Vector2, size: Vector2, from_color: Color, to_color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([from_color, to_color])

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


## Bouton MISSIONS de la barre du haut. C'est le seul endroit du village qui
## dise au joueur quoi faire ensuite : il porte une pastille doree des qu'une
## recompense attend d'etre prise, sinon personne ne l'ouvrirait jamais.
func _build_missions_button(y: float) -> void:
	_missions_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.25)
	box.set_corner_radius_all(10)
	box.border_color = Color(UiTheme.GOLD, 0.3)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	_missions_button.add_theme_stylebox_override("panel", box)
	_overlay.add_child(_missions_button)
	_missions_button.position.y = y

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_missions_button.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "star"
	icon.color = UiTheme.GOLD
	icon.custom_minimum_size = Vector2(13, 13)
	row.add_child(icon)

	_missions_label = UiTheme.make_label("Missions", 14, Color.WHITE)
	_missions_label.add_theme_font_override("font", UiTheme.font_display())
	_missions_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_missions_label)

	# Pastille de notification. VOISINE du bouton, jamais son enfant : un
	# PanelContainer etire tous ses enfants a sa taille, la pastille
	# recouvrirait le libelle.
	_missions_badge = PanelContainer.new()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = UiTheme.GOLD
	badge_box.set_corner_radius_all(7)
	badge_box.content_margin_left = 5
	badge_box.content_margin_right = 5
	badge_box.content_margin_top = 1
	badge_box.content_margin_bottom = 1
	_missions_badge.add_theme_stylebox_override("panel", badge_box)
	_missions_badge.visible = false
	_overlay.add_child(_missions_badge)

	var badge_label := UiTheme.make_label("", 9, Color("331f00"))
	badge_label.name = "Count"
	badge_label.add_theme_font_override("font", UiTheme.font_bold())
	badge_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_missions_badge.add_child(badge_label)

	UiTheme.ignore_mouse_recursive(row)
	UiTheme.ignore_mouse_recursive(_missions_badge)
	_missions_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_missions_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_missions_pressed()
	)


func _refresh_missions_button() -> void:
	if not is_instance_valid(_missions_button):
		return
	var claimable := Game.claimable_missions()
	_missions_badge.visible = claimable > 0
	if claimable > 0:
		var count: Label = _missions_badge.get_node("Count")
		count.text = str(claimable)
		_missions_badge.reset_size()
		# Coin haut-droit du bouton, legerement debordant.
		_missions_badge.position = _missions_button.position + Vector2(
			_missions_button.size.x - _missions_badge.size.x * 0.6,
			-_missions_badge.size.y * 0.35)


func _on_missions_pressed() -> void:
	if is_instance_valid(_popup):
		return
	_popup = MissionPopupScene.instantiate()
	add_child(_popup)


func _place_pill(x: float, y: float, text: String, variant: Pill.Variant) -> Pill:
	var pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_overlay.add_child(pill)
	pill.set_data("", text, variant)
	pill.size = pill.get_combined_minimum_size()
	pill.position = Vector2(x, y)
	return pill


## Halo dore pose sur le Chateau Royal, allume tant qu'une Dame au moins est
## rentree. C'est la recompense visible de la campagne : le Roi a retrouve sa
## Dame, son chateau rayonne a nouveau.
##
## Un degrade radial plutot qu'une image : ca ne coute aucun asset, ca se
## teinte librement, et ca reste net a n'importe quelle definition d'ecran.
func _build_castle_glow() -> void:
	# Le grand halo reste discret : c'est la lueur qui deborde du chateau.
	_castle_glow = _glow_rect(0.34, CASTLE_GLOW_RECT)
	_overlay.add_child(_castle_glow)

	# Les lumieres des fenetres et de la couronne s'allument avec le halo :
	# c'est ce qui separe village-avec-dame de village-sans-dame dans la
	# maquette. Elles suivent l'opacite du halo, dont elles sont enfants.
	# Les lumieres des fenetres sont petites : il leur faut un coeur plus
	# franc pour se voir, et un cadre elargi pour que leur halo deborde.
	for light in GLOW_LIGHTS:
		var rect: Rect2 = light["rect"]
		var spread: Vector2 = rect.size * 1.6
		var lamp := _glow_rect(0.7, Rect2(
			rect.position - CASTLE_GLOW_RECT.position - (spread - rect.size) * 0.5, spread))
		_castle_glow.add_child(lamp)


## Un halo de la maquette, reproduit en degrade radial plutot qu'importe tel
## quel : les SVG fournis sont des ellipses #FFD94D floutees par un
## feGaussianBlur, et l'import vectoriel de Godot n'applique pas les filtres
## SVG - la lumiere ne s'allumait pas du tout. Un degrade rend exactement le
## meme resultat, sans asset a embarquer et net a toute definition.
##
## Melange additif, comme le "mix-blend-mode: screen" de la maquette : le halo
## AJOUTE de la lumiere au decor au lieu de peindre un voile jaune par-dessus.
## C'est la difference entre un chateau qui brille et un chateau sali.
func _glow_rect(core_alpha: float, rect: Rect2) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("ffd94d", core_alpha))
	gradient.set_color(1, Color("ffd94d", 0.0))
	gradient.add_point(0.45, Color("ffd94d", core_alpha * 0.45))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128

	var glow := TextureRect.new()
	glow.texture = texture

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material

	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = rect.position
	glow.size = rect.size
	return glow


## Le halo respire lentement tant qu'il y a une Dame au village, et s'eteint
## sinon. La boucle n'est relancee que si elle ne tourne pas deja : _refresh()
## repasse ici chaque seconde (cf. le ticker de _ready).
func _refresh_castle_glow() -> void:
	var dames := Game.dames_owned()
	_castle_glow.visible = dames > 0

	if dames <= 0:
		if _castle_glow_tween != null and _castle_glow_tween.is_valid():
			_castle_glow_tween.kill()
		_castle_glow_tween = null
		return

	# Chaque Dame supplementaire fait rayonner le chateau un peu plus loin,
	# sans jamais noyer la carte.
	var spread := 1.0 + minf(float(dames - 1) * 0.12, 0.36)
	_castle_glow.size = CASTLE_GLOW_RECT.size * spread
	_castle_glow.position = CASTLE_GLOW_RECT.position \
		- (CASTLE_GLOW_RECT.size * (spread - 1.0)) * 0.5

	if _castle_glow_tween != null and _castle_glow_tween.is_valid():
		return
	_castle_glow.modulate.a = 0.55
	_castle_glow_tween = create_tween().set_loops()
	_castle_glow_tween.tween_property(_castle_glow, "modulate:a", 1.0, 1.7) \
		.set_trans(Tween.TRANS_SINE)
	_castle_glow_tween.tween_property(_castle_glow, "modulate:a", 0.55, 1.7) \
		.set_trans(Tween.TRANS_SINE)


func _build_castle_label() -> void:
	_castle_label = PanelContainer.new()
	_style_building_panel(_castle_label, Color("ffd933", 1.22), 14)
	_overlay.add_child(_castle_label)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_castle_label.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := UiTheme.make_label("CHÂTEAU ROYAL", 16, Color("ffd933"))
	title.add_theme_font_override("font", UiTheme.font_display())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_castle_sub_row = HBoxContainer.new()
	_castle_sub_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_castle_sub_row)

	_castle_label.position = CASTLE_POS
	_make_clickable(_castle_label, func(): _on_building_pressed(Balance.CASTLE))
	_building_buttons[Balance.CASTLE] = _castle_label
	UiTheme.ignore_mouse_recursive(margin)


func _build_building_label(type: String) -> void:
	var panel := PanelContainer.new()
	_style_building_panel(panel, Color(String(BUILDING_ACCENT[type])), 12)
	_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Le nom vient de Balance, comme celui qu'affiche le popup du batiment : il
	# y avait deux tables pour la meme chose, et elles ne disaient deja plus
	# tout a fait la meme chose.
	var title := UiTheme.make_label(Balance.building_name(type), 15, Color.WHITE)
	title.add_theme_font_override("font", UiTheme.font_display())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sub_row)

	panel.position = BUILDING_POS[type]
	_building_labels[type] = {"panel": panel, "sub_row": sub_row}
	_make_clickable(panel, func(): _on_building_pressed(type))
	_building_buttons[type] = panel
	UiTheme.ignore_mouse_recursive(margin)


## Les labels de batiments sont des PanelContainer (pas des Button) pour
## coller au visuel Figma - fond sombre pose sur la carte, pas un bouton
## classique. On reproduit juste l'interaction click.
func _make_clickable(panel: PanelContainer, action: Callable) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			action.call())


## Panneau clic-able (pas un Button) : seul moyen d'inserer une Icon
## vectorielle (epee) a cote du texte.
func _build_battle_button() -> void:
	_battle_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("ffd700")
	box.set_corner_radius_all(12)
	box.border_color = Color("b8860b")
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	_battle_button.add_theme_stylebox_override("panel", box)
	_overlay.add_child(_battle_button)
	_battle_button.position = BATTLE_RECT.position
	_battle_button.size = BATTLE_RECT.size

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_battle_button.add_child(row)

	var sword := Icon.new()
	sword.icon_name = "sword"
	sword.color = Color("331f00")
	sword.custom_minimum_size = Vector2(20, 20)
	row.add_child(sword)

	_battle_label = UiTheme.make_label("BATAILLE", 19, Color("331f00"))
	_battle_label.add_theme_font_override("font", UiTheme.font_bold())
	_battle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_battle_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(_battle_label)

	_make_clickable(_battle_button, _on_battle_pressed)
	UiTheme.ignore_mouse_recursive(row)


## Discret, 24x24 - cf. CLAUDE.md ("Bouton DEV : discret, 24x24, radius 4,
## emoji outil"). Une icone plutot que du texte : illisible a cette taille.
func _build_dev_button() -> void:
	var dev := Button.new()
	dev.theme_type_variation = "SecondaryButton"
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PANEL_LIGHT
	box.set_corner_radius_all(4)
	box.set_content_margin_all(0)
	dev.add_theme_stylebox_override("normal", box)
	dev.add_theme_stylebox_override("hover", box)
	dev.add_theme_stylebox_override("pressed", box)
	_overlay.add_child(dev)
	dev.position = DEV_BUTTON_RECT.position
	dev.size = DEV_BUTTON_RECT.size
	dev.pressed.connect(_on_dev_pressed)

	var icon := Icon.new()
	icon.icon_name = "wrench"
	icon.color = UiTheme.TEXT_DIM
	icon.custom_minimum_size = Vector2(14, 14)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dev.add_child(icon)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = DEV_BUTTON_RECT.size / 2.0 - icon.custom_minimum_size / 2.0


## Chaque label a la teinte de son batiment en bordure + halo - cf. captures
## Figma 01, ou seul le Chateau (or) et les quatre casernes (bleu/vert/mauve/
## rouge) different par cette seule couleur d'accent. Le halo reprend cette
## meme teinte plutot qu'une ombre noire generique - il s'estompe de lui-meme
## sur un batiment verrouille via le modulate applique dans _refresh_building().
## Enseigne de batiment de la maquette V2 : fond presque noir, fine bordure
## a la teinte du batiment, ombre portee franche. Plus de halo colore - la
## V2 est plus sobre que la V1.
func _style_building_panel(panel: PanelContainer, accent: Color, radius: int,
		shadow: float = 10.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a0d14", 0.85)
	box.set_corner_radius_all(radius)
	box.border_color = Color(accent, 0.45)
	box.set_border_width_all(1.5)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = int(shadow)
	box.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", box)


## "2 450" plutot que "2450" - separateur de milliers a la francaise, comme
## la pastille Or de la capture Figma 01.
func _format_thousands(n: int) -> String:
	var digits := str(n)
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return out


# ------------------------------- RAFRAICHISSEMENT ----------------------------

func _refresh() -> void:
	var pill_y := TOP_BAR_Y + 11.5

	_gold_pill.set_data("dot", _format_thousands(Game.gold), Pill.Variant.TOPBAR, UiTheme.GOLD)
	_gold_pill.set_bold(true)
	_gold_pill.size = _gold_pill.get_combined_minimum_size()
	_gold_pill.position = Vector2(12, pill_y)

	_level_pill.set_data("crown", "Nv. %d" % Game.castle_level(), Pill.Variant.TOPBAR, Color("ffe580"))
	_level_pill.set_text_color(Color("ffe580"))
	_level_pill.size = _level_pill.get_combined_minimum_size()
	_level_pill.position = Vector2(_gold_pill.position.x + _gold_pill.size.x + 16, pill_y)

	_missions_button.reset_size()
	_missions_button.position = Vector2(
		_level_pill.position.x + _level_pill.size.x + 16, pill_y - 2)
	_refresh_missions_button.call_deferred()

	_refresh_castle_glow()
	_refresh_castle()
	for type in Balance.UNIT_TYPES:
		_refresh_building(type)

	if Game.is_campaign_complete():
		_battle_label.text = "REJOUER LA DERNIERE"
	else:
		_battle_label.text = "BATAILLE"


func _refresh_castle() -> void:
	# free() immediat : ce panneau se reconstruit chaque seconde, un
	# queue_free() laisserait l'ancien contenu compter dans la largeur
	# calculee juste apres (cf. le meme correctif sur building_popup.gd).
	for child in _castle_sub_row.get_children():
		_castle_sub_row.remove_child(child)
		child.free()

	var level_pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_castle_sub_row.add_child(level_pill)
	level_pill.set_custom("", "Nv.%d" % Game.castle_level(), Color("ffd933", 0.2), Color("ffd933"))
	level_pill.get_node("%Text").add_theme_font_size_override("font_size", 11)

	var deploy := UiTheme.make_label("Charge : %d" % Game.deploy_capacity(), 10, Color("ccd1e0"))
	deploy.autowrap_mode = TextServer.AUTOWRAP_OFF
	_castle_sub_row.add_child(deploy)

	# Les Dames retrouvees vivent ici, avec le Roi : c'est le chateau qui
	# annonce combien il en abrite et ce qu'elles rapportent.
	var dames := Game.dames_owned()
	if dames > 0:
		var crown := Icon.new()
		crown.icon_name = "crown"
		crown.color = Color("d8a0d0")
		crown.custom_minimum_size = Vector2(11, 11)
		_castle_sub_row.add_child(crown)

		var dame_label := UiTheme.make_label(
			"%d  +%d%% or" % [dames, int(Balance.DAME_GOLD_BONUS * 100.0 * dames)],
			10, Color("e5b8e0"))
		dame_label.add_theme_font_override("font", UiTheme.font_bold())
		dame_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_castle_sub_row.add_child(dame_label)


	if Game.is_upgrading(Balance.CASTLE):
		var eta := UiTheme.make_label(UiTheme.format_duration(Game.upgrade_remaining(Balance.CASTLE)),
			11, UiTheme.GOLD)
		eta.autowrap_mode = TextServer.AUTOWRAP_OFF
		_castle_sub_row.add_child(eta)

	UiTheme.ignore_mouse_recursive(_castle_sub_row)
	# Le label lui-meme se pare d'un halo plus large quand une Dame est rentree.
	_style_building_panel(_castle_label, Color("ffd933"), 14,
		26.0 if Game.dames_owned() > 0 else 14.0)

	_castle_label.size = _castle_label.get_combined_minimum_size()
	_castle_label.position.x = _clamp_x(CASTLE_POS.x, _castle_label.size.x)


func _refresh_building(type: String) -> void:
	var refs: Dictionary = _building_labels[type]
	var panel: PanelContainer = refs["panel"]
	var sub_row: HBoxContainer = refs["sub_row"]
	for child in sub_row.get_children():
		sub_row.remove_child(child)
		child.free()

	var color := Color(String(BUILDING_ACCENT[type]))

	if not Game.is_building_unlocked(type):
		panel.modulate.a = 0.6
		# La Dame n'a pas de batiment a elle : elle vit au Chateau Royal, et
		# n'y apparait que le jour ou l'une d'elles y entre.
		var hint := UiTheme.make_label(
			"Château Nv.%d requis" % Balance.unlock_castle_level(type), 11, UiTheme.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_row.add_child(hint)
	else:
		panel.modulate.a = 1.0
		var level_pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
		sub_row.add_child(level_pill)
		level_pill.set_custom("", "Nv.%d" % Game.building_level(type), Color(color, 0.2), color)
		level_pill.get_node("%Text").add_theme_font_size_override("font_size", 10)

		var owned := Game.units_owned(type)
		var cap := Balance.capacity(type, Game.building_level(type))
		var bar := _progress_bar(float(owned) / float(maxi(cap, 1)), color)
		sub_row.add_child(bar)

		var count := UiTheme.make_label("%d/%d" % [owned, cap], 10, Color("bfc7d9"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_row.add_child(count)

	UiTheme.ignore_mouse_recursive(sub_row)
	panel.size = panel.get_combined_minimum_size()
	panel.position.x = _clamp_x(BUILDING_POS[type].x, panel.size.x)


## Les positions de BUILDING_POS/CASTLE_POS sont des coins haut-gauche fixes,
## mais la largeur reelle du label depend de son contenu (progression,
## compte a rebours...) : sans ce garde-fou, les labels de la colonne de
## droite (Ecuries, Donjon des Tours) peuvent deborder de l'ecran 393px.
func _clamp_x(x: float, width: float) -> float:
	return clampf(x, SCREEN_MARGIN, SCREEN_WIDTH - width - SCREEN_MARGIN)


func _progress_bar(fraction: float, color: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(50, 6)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.position = Vector2.ZERO
	track.size = Vector2(50, 6)
	wrap.add_child(track)

	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2.ZERO
	fill.size = Vector2(50 * clampf(fraction, 0.0, 1.0), 6)
	wrap.add_child(fill)

	return wrap


# ------------------------------- ACTIONS -------------------------------------

func _on_building_pressed(type: String) -> void:
	if is_instance_valid(_popup):
		return
	# Le Chateau Royal a son propre ecran : la salle du trone, ou l'on voit
	# d'un coup d'oeil si la Dame est rentree.
	if type == Balance.CASTLE:
		Router.goto_castle()
		return
	_popup = BuildingPopupScene.instantiate()
	add_child(_popup)
	_popup.open(type)


func _on_battle_pressed() -> void:
	Router.goto_campaign()


func _on_dev_pressed() -> void:
	if is_instance_valid(_popup):
		return
	_popup = DevPanelScene.instantiate()
	add_child(_popup)
