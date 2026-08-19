extends Control
##
## VILLAGE - ecran principal : chateau, batiments, or, bouton bataille.
##
## Reproduit la maquette Figma (assets/screens/01_Village.png) en positions
## absolues, avec les coordonnees exactes donnees par CLAUDE.md : chaque
## batiment est un label pose directement sur le fond, pas une liste
## generique. Aucune regle de jeu ici : tout vient de GameState/Balance.
##

const BuildingPopupScene := preload("res://scenes/village/building_popup.tscn")
const DevPanelScene := preload("res://scenes/village/dev_panel.tscn")

## Coordonnees CLAUDE.md > 01_Village (x, y du coin haut-gauche du label).
const CASTLE_POS := Vector2(120, 445)
const BUILDING_POS := {
	"pion": Vector2(20, 272),
	"cavalier": Vector2(258, 272),
	"fou": Vector2(30, 542),
	"tour": Vector2(248, 542),
}
const BUILDING_TITLES := {
	"pion": "Caserne des Pions",
	"cavalier": "Ecuries",
	"fou": "Cloitre des Fous",
	"tour": "Donjon des Tours",
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
const SCREEN_WIDTH := 393.0
const SCREEN_MARGIN := 8.0
const FORGE_POS := Vector2(50, 685)
const BATTLE_RECT := Rect2(87, 748, 219, 59)
const TOP_BAR_Y := 38.0
const TOP_BAR_HEIGHT := 46.0
const DEV_BUTTON_RECT := Rect2(362, 14, 24, 24)

@onready var _overlay: Control = $Overlay

var _popup: Control = null
var _gold_pill: Pill
var _level_pill: Pill
var _gems_pill: Pill
var _castle_label: PanelContainer
var _castle_sub_row: HBoxContainer
var _building_labels: Dictionary = {}   # type -> {"panel":.., "sub_row":..}
var _building_buttons: Dictionary = {}  # type -> panel cliquable (cf. tools/ui_test.gd)
var _battle_button: PanelContainer
var _battle_label: Label


func _ready() -> void:
	_build_top_bar()
	_build_castle_label()
	for type in Balance.UNIT_TYPES:
		_build_building_label(type)
	_build_forge_label()
	_build_battle_button()
	_build_dev_button()

	Game.gold_changed.connect(func(_g): _refresh())
	Game.units_changed.connect(_refresh)
	Game.buildings_changed.connect(_refresh)
	Game.progress_changed.connect(_refresh)

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

## Bandeau plein (rgba(10,13,20,0.75), h46, y38) derriere les pastilles -
## cf. capture Figma 01 "Top-Bar" : sans lui les pastilles flottent seules
## sur le fond illustre plutot que de reposer sur une barre continue.
func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = Color("0a0d14", 0.75)
	bar_box.shadow_color = Color(0, 0, 0, 0.3)
	bar_box.shadow_size = 4
	bar_box.shadow_offset = Vector2(0, 1)
	bar.add_theme_stylebox_override("panel", bar_box)
	_overlay.add_child(bar)
	bar.position = Vector2(0, TOP_BAR_Y)
	bar.size = Vector2(393, TOP_BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pill_y := TOP_BAR_Y + 11.5

	_gold_pill = _place_pill(12, pill_y, "", Pill.Variant.TOPBAR)
	_gold_pill.set_data("dot", "", Pill.Variant.TOPBAR, UiTheme.GOLD)
	_gold_pill.set_bold(true)

	_level_pill = _place_pill(132, pill_y, "", Pill.Variant.TOPBAR)
	_level_pill.set_data("crown", "", Pill.Variant.TOPBAR, Color("ffe580"))
	_level_pill.set_text_color(Color("ffe580"))

	_gems_pill = _place_pill(246, pill_y, "0", Pill.Variant.TOPBAR)
	_gems_pill.set_data("dot", "0", Pill.Variant.TOPBAR, UiTheme.ACCENT.lightened(0.2))
	_gems_pill.set_bold(true)

	var settings := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.12)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(7)
	settings.add_theme_stylebox_override("panel", box)
	var gear := Icon.new()
	gear.icon_name = "wrench"
	gear.color = Color("ccccd9")
	gear.custom_minimum_size = Vector2(14, 14)
	settings.add_child(gear)
	_overlay.add_child(settings)
	settings.position = Vector2(353, TOP_BAR_Y + 9)
	settings.size = Vector2(28, 28)


func _place_pill(x: float, y: float, text: String, variant: Pill.Variant) -> Pill:
	var pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_overlay.add_child(pill)
	pill.set_data("", text, variant)
	pill.size = pill.get_combined_minimum_size()
	pill.position = Vector2(x, y)
	return pill


func _build_castle_label() -> void:
	_castle_label = PanelContainer.new()
	_style_building_panel(_castle_label, Color("ffd933"), 14)
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

	var title := UiTheme.make_label("CHATEAU ROYAL", 12, Color("ffd933"))
	title.add_theme_font_override("font", UiTheme.font_bold())
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

	var title := UiTheme.make_label(String(BUILDING_TITLES[type]), 11, Color.WHITE)
	title.add_theme_font_override("font", UiTheme.font_bold())
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


## Batiment fictif, jamais debloquable en Phase 1 - simple clin d'oeil au
## contenu a venir, cf. CLAUDE.md ("Label verrouille : Forge").
func _build_forge_label() -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a0d14", 0.8)
	box.set_corner_radius_all(10)
	box.border_color = Color("595966", 0.35)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)
	_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var lock := Icon.new()
	lock.icon_name = "lock"
	lock.color = Color("80808c")
	lock.custom_minimum_size = Vector2(10, 10)
	row.add_child(lock)
	var title := UiTheme.make_label("Forge", 10, Color("80808c"))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(title)
	vbox.add_child(row)

	var hint := UiTheme.make_label("Chateau Nv.6 requis", 8, Color("666673"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	panel.size = panel.get_combined_minimum_size()
	panel.position = FORGE_POS


## Panneau clic-able (pas un Button) : seul moyen d'inserer une Icon
## vectorielle (epee) a cote du texte, cf. _icon_button() dans battle.gd pour
## le meme besoin sur l'ecran de combat.
func _build_battle_button() -> void:
	_battle_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.GOLD
	box.set_corner_radius_all(18)
	box.border_color = Color("d9a600", 0.5)
	box.set_border_width_all(2)
	box.shadow_color = Color("ffbf00", 0.45)
	box.shadow_size = 18
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
## rouge) different par cette seule couleur d'accent.
func _style_building_panel(panel: PanelContainer, accent: Color, radius: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a0d14", 0.88)
	box.set_corner_radius_all(radius)
	box.border_color = Color(accent, 0.5)
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 8
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

	_gems_pill.size = _gems_pill.get_combined_minimum_size()
	_gems_pill.position = Vector2(_level_pill.position.x + _level_pill.size.x + 16, pill_y)

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

	var deploy := UiTheme.make_label("Deploiement: %d" % Game.deploy_slots(), 10, Color("ccd1e0"))
	deploy.autowrap_mode = TextServer.AUTOWRAP_OFF
	_castle_sub_row.add_child(deploy)

	if Game.is_upgrading(Balance.CASTLE):
		var eta := UiTheme.make_label(UiTheme.format_duration(Game.upgrade_remaining(Balance.CASTLE)),
			11, UiTheme.GOLD)
		eta.autowrap_mode = TextServer.AUTOWRAP_OFF
		_castle_sub_row.add_child(eta)

	UiTheme.ignore_mouse_recursive(_castle_sub_row)
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
		var hint := UiTheme.make_label(
			"Chateau Nv.%d requis" % Balance.unlock_castle_level(type), 11, UiTheme.TEXT_DIM)
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
