extends Control
##
## CHATEAU ROYAL - la salle du trone, en plein ecran.
##
## Reprend les frames chateau-royal-avec-dame et chateau-royal-sans-dame de la
## maquette V2. Les deux sont le MEME ecran : seule change l'illustration,
## selon qu'une Dame a ete ramenee vivante ou non. C'est toute l'histoire du
## jeu, montree d'un coup d'oeil - le Roi seul devant un trone vide, ou le
## couple enfin reuni.
##
## L'ecran remplace l'ancienne modale du chateau : le batiment le plus
## important du village meritait mieux qu'un popup.
##
## Aucune regle ici : la charge de deploiement, le cout et la duree de
## l'amelioration viennent de Balance et de GameState.
##

const ConfirmUpgradeScene := preload("res://scenes/village/confirm_upgrade.tscn")

const BG_AVEC_DAME := "res://assets/castle/throne_room_avec_dame.png"
const BG_SANS_DAME := "res://assets/castle/throne_room_sans_dame.png"

## Geometrie de la maquette (frame 393 x 852).
const PANEL_MARGIN := 12.0
const PANEL_RADIUS := 24
const PANEL_PADDING := 20
const HEADER_PADDING := 16.0
const BACK_SIZE := 44.0

const GOLD := Color("ffd700")
const PANEL_BG := Color("0b1628", 0.85)
const BADGE_BG := Color("0b1c2e")
const CAPTION := Color("8b9bb4")

@onready var _background: TextureRect = $Background
@onready var _vignettes: Control = $Vignettes
@onready var _overlay: Control = $Safe/Overlay

var _panel_body: VBoxContainer = null
var _level_label: Label = null


## L'amelioration du Chateau passe par la meme confirmation que celle des
## casernes (cf. confirm_upgrade.gd) : c'est la plus chere du jeu, et la plus
## longue.
func _ask_upgrade() -> void:
	var confirm: Node = ConfirmUpgradeScene.instantiate()
	confirm.confirmed.connect(func(): Game.start_upgrade(Balance.CASTLE))
	get_tree().root.add_child(confirm)
	confirm.open(Balance.CASTLE)


func _ready() -> void:
	_paint_background()
	_build_vignettes()
	_build_header()
	_build_panel()

	Game.gold_changed.connect(func(_g): _refresh())
	Game.buildings_changed.connect(_refresh)
	Game.units_changed.connect(_refresh)

	# L'amelioration se termine toute seule au bout de son compte a rebours :
	# l'ecran doit le voir sans qu'on en sorte.
	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.timeout.connect(func():
		Game.check_upgrades()
		if Game.is_upgrading(Balance.CASTLE):
			_refresh()
	)
	add_child(ticker)
	ticker.start()

	_refresh()


# ------------------------------- DECOR ---------------------------------------

## Le trone vide ou le couple reuni. C'est la seule difference entre les deux
## frames de la maquette.
func _paint_background() -> void:
	var path := BG_AVEC_DAME if Game.dames_owned() > 0 else BG_SANS_DAME
	if ResourceLoader.exists(path):
		_background.texture = load(path)


func _build_vignettes() -> void:
	var top := _gradient_rect(Color(0, 0, 0, 0.9), Color(0, 0, 0, 0.0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 160.0
	_vignettes.add_child(top)

	var bottom := _gradient_rect(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.95))
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -302.0
	_vignettes.add_child(bottom)


func _gradient_rect(from_color: Color, to_color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([from_color, to_color])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 256

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


# ------------------------------- EN-TETE -------------------------------------

func _build_header() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = HEADER_PADDING
	row.offset_right = -HEADER_PADDING
	row.offset_top = HEADER_PADDING
	row.add_theme_constant_override("separation", 8)
	_overlay.add_child(row)

	row.add_child(_back_button())

	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 6)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)

	var banner := PanelContainer.new()
	var banner_box := StyleBoxFlat.new()
	banner_box.bg_color = BADGE_BG
	banner_box.border_color = GOLD
	banner_box.set_border_width_all(2)
	banner_box.set_corner_radius_all(10)
	banner_box.content_margin_left = 24
	banner_box.content_margin_right = 24
	banner_box.content_margin_top = 8
	banner_box.content_margin_bottom = 8
	banner_box.shadow_color = Color(0, 0, 0, 0.7)
	banner_box.shadow_size = 6
	banner_box.shadow_offset = Vector2(0, 4)
	banner.add_theme_stylebox_override("panel", banner_box)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	titles.add_child(banner)

	var title := UiTheme.make_label("CHÂTEAU ROYAL", 18, GOLD)
	title.add_theme_font_override("font", UiTheme.font_title())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner.add_child(title)

	var pill := PanelContainer.new()
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = Color("3b66ff")
	pill_box.set_corner_radius_all(100)
	pill_box.content_margin_left = 16
	pill_box.content_margin_right = 16
	pill_box.content_margin_top = 4
	pill_box.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", pill_box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	titles.add_child(pill)

	_level_label = UiTheme.make_label("", 11, Color.WHITE)
	_level_label.add_theme_font_override("font", UiTheme.font_bold())
	_level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(_level_label)

	# Contrepoids du bouton retour, pour que le titre reste vraiment centre.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(BACK_SIZE, BACK_SIZE)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)


func _back_button() -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = BADGE_BG
	box.border_color = GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("panel", box)
	button.custom_minimum_size = Vector2(BACK_SIZE, BACK_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	button.add_child(center)
	var arrow := Icon.new()
	arrow.icon_name = "arrow_left"
	arrow.color = GOLD
	arrow.custom_minimum_size = Vector2(20, 20)
	center.add_child(arrow)

	UiTheme.ignore_mouse_recursive(center)
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Router.goto_village()
	)
	return button


# ------------------------------- PANNEAU DU BAS ------------------------------

func _build_panel() -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = GOLD
	box.set_border_width_all(2)
	box.set_corner_radius_all(PANEL_RADIUS)
	box.set_content_margin_all(PANEL_PADDING)
	box.shadow_color = Color(0, 0, 0, 0.8)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", box)

	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = PANEL_MARGIN
	panel.offset_right = -PANEL_MARGIN
	panel.offset_bottom = -28.0
	panel.offset_top = -28.0
	_overlay.add_child(panel)

	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", 16)
	panel.add_child(_panel_body)


# ------------------------------- CONTENU -------------------------------------

func _refresh() -> void:
	if not is_instance_valid(_panel_body):
		return

	var level := Game.castle_level()
	_level_label.text = "NIVEAU %d" % level

	# free() immediat : le panneau se reconstruit chaque seconde pendant une
	# amelioration, un free() differe fausserait sa hauteur (cf. le meme
	# correctif dans building_popup.gd).
	for child in _panel_body.get_children():
		_panel_body.remove_child(child)
		child.free()

	_panel_body.add_child(_stat_pair(
		"Déploiement actuel", "%d de charge" % Game.deploy_capacity(), Color.WHITE,
		"Prochain niveau", "", Color.WHITE))

	var dames := Game.dames_owned()
	if dames > 0:
		_panel_body.add_child(_divider())
		_panel_body.add_child(_stat_pair(
			"Dames au château", "%d" % dames, Color("e5b8e0"),
			"Aura, par victoire", "+%d %% d'or" % int(Balance.DAME_GOLD_BONUS * 100.0 * dames),
			Color("e5b8e0")))

	if Game.is_max_level(Balance.CASTLE):
		_panel_body.add_child(_divider())
		var maxed := UiTheme.make_label("Niveau maximum atteint.", 14, CAPTION)
		maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel_body.add_child(maxed)
		return

	_panel_body.add_child(_divider())

	if Game.is_upgrading(Balance.CASTLE):
		_panel_body.add_child(_stat_column("Amélioration en cours",
			"%s restantes" % UiTheme.format_duration(Game.upgrade_remaining(Balance.CASTLE)),
			GOLD, "clock"))
		return

	var cost := Balance.upgrade_cost(Balance.CASTLE, level)
	var seconds := Balance.upgrade_seconds(Balance.CASTLE, level)

	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 16)
	costs.add_child(_stat_column("Coût d'amélioration", "%d Or" % cost, GOLD, "coin"))
	costs.add_child(_stat_column("Temps requis", UiTheme.format_duration(seconds),
		Color.WHITE, "clock"))
	_panel_body.add_child(costs)

	_panel_body.add_child(_upgrade_button(cost))


## Deux colonnes de statistique cote a cote, comme la grille de la maquette.
## La seconde valeur peut etre vide : c'est alors la progression "16 -> 19"
## du prochain niveau qui s'affiche.
func _stat_pair(left_caption: String, left_value: String, left_color: Color,
		right_caption: String, right_value: String, right_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_stat_column(left_caption, left_value, left_color))

	if right_value.is_empty():
		row.add_child(_next_level_column(right_caption))
	else:
		row.add_child(_stat_column(right_caption, right_value, right_color))
	return row


func _stat_column(caption: String, value: String, color: Color, icon_name: String = "") -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := UiTheme.make_label(caption, 12, CAPTION)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	column.add_child(label)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 8)
	if not icon_name.is_empty():
		var icon := Icon.new()
		icon.icon_name = icon_name
		icon.color = color
		icon.custom_minimum_size = Vector2(16, 16)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		value_row.add_child(icon)

	var value_label := UiTheme.make_label(value, 16, color)
	value_label.add_theme_font_override("font", UiTheme.font_bold())
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_row.add_child(value_label)
	column.add_child(value_row)

	return column


## "16 -> 19 de charge" : ce que rapporte la prochaine amelioration, montre
## d'un coup d'oeil plutot qu'en deux chiffres separes.
func _next_level_column(caption: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := UiTheme.make_label(caption, 12, CAPTION)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	column.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	if Game.is_max_level(Balance.CASTLE):
		var maxed := UiTheme.make_label("maximum", 16, Color.WHITE)
		maxed.add_theme_font_override("font", UiTheme.font_bold())
		maxed.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(maxed)
		column.add_child(row)
		return column

	var current := UiTheme.make_label(str(Game.deploy_capacity()), 16, Color.WHITE)
	current.add_theme_font_override("font", UiTheme.font_bold())
	current.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(current)

	var arrow := Icon.new()
	arrow.icon_name = "chevron_right"
	arrow.color = GOLD
	arrow.custom_minimum_size = Vector2(12, 12)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)

	var next := UiTheme.make_label(
		"%d de charge" % Balance.deploy_capacity(Game.castle_level() + 1), 16, GOLD)
	next.add_theme_font_override("font", UiTheme.font_bold())
	next.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(next)

	column.add_child(row)
	return column


## Filet horizontal avec un losange au milieu - le "Divider-System" de la
## maquette, qu'on retrouve sur toutes ses cartes.
func _divider() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 10)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line := ColorRect.new()
	line.color = Color(GOLD, 0.25)
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.offset_top = 5.0
	line.offset_bottom = 6.0
	wrap.add_child(line)

	var diamond := Icon.new()
	diamond.icon_name = "diamond"
	diamond.color = GOLD
	diamond.custom_minimum_size = Vector2(10, 10)
	diamond.set_anchors_preset(Control.PRESET_CENTER)
	diamond.offset_left = -5.0
	diamond.offset_right = 5.0
	diamond.offset_top = -5.0
	diamond.offset_bottom = 5.0
	wrap.add_child(diamond)

	return wrap


func _upgrade_button(cost: int) -> PanelContainer:
	var affordable := Game.can_afford(cost)

	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("ffc800")
	box.border_color = Color("b8860b")
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	box.shadow_color = Color(0, 0, 0, 0.25)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 4)
	button.add_theme_stylebox_override("panel", box)
	button.modulate.a = 1.0 if affordable else 0.5

	var label := UiTheme.make_label("AMÉLIORER", 18, Color("1c1405"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	if not affordable:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return button

	button.mouse_filter = Control.MOUSE_FILTER_STOP
	# call_deferred : lancer l'amelioration reconstruit ce panneau, donc libere
	# le bouton qui est en train d'emettre le signal.
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_ask_upgrade())
	return button
