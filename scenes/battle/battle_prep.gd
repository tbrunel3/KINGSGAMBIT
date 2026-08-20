extends Control
##
## PREPARATION DE BATAILLE - le briefing affiche avant le placement.
##
## Numero, composition ennemie, recompense, unites disponibles : tout vient de
## Balance.CAMPAIGN et de GameState, rien n'est ecrit en dur ici.
##
## Trois cartes distinctes (Enemies-Card, Player-Card, Info-Summary), avec des
## mini-cartes par type d'unite plutot que des lignes de texte - cf. la
## capture Figma 03, tres differente du texte brut de la Phase 1.
##

@onready var _back: PanelContainer = $Safe/Root/Header/HeaderRow/BackButton
@onready var _title: Label = $Safe/Root/Header/HeaderRow/TitleLabel
@onready var _enemies_body: VBoxContainer = $Safe/Root/Scroll/BodyMargin/Body/EnemiesCard/Body
@onready var _player_body: VBoxContainer = $Safe/Root/Scroll/BodyMargin/Body/PlayerCard/Body
@onready var _info_body: VBoxContainer = $Safe/Root/Scroll/BodyMargin/Body/InfoCard/Body
@onready var _prepare: PanelContainer = $Safe/Root/BottomMargin/PrepareButton

var _battle: Dictionary = {}
var _prepare_label: Label
var _prepare_enabled: bool = true


func _ready() -> void:
	_battle = Router.current_battle()

	_style_header()
	_style_back_button()
	_style_prepare_button()

	_back.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Router.goto_campaign())
	_prepare.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _prepare_enabled:
			Router.goto_battle(int(_battle["id"])))

	_fill()


func _style_header() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color("2a2f45")
	box.border_width_bottom = 1
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	$Safe/Root/Header.add_theme_stylebox_override("panel", box)

	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_font_override("font", UiTheme.font_bold())
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.clip_text = true


func _style_back_button() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PANEL_LIGHT
	box.set_corner_radius_all(8)
	box.set_content_margin_all(8)
	_back.add_theme_stylebox_override("panel", box)
	_back.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon := Icon.new()
	icon.icon_name = "arrow_left"
	icon.color = UiTheme.TEXT
	icon.custom_minimum_size = Vector2(14, 14)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_child(icon)


func _style_prepare_button() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.GOLD_BUTTON
	box.set_corner_radius_all(12)
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(2)
	box.shadow_color = Color("ffd700", 0.3)
	box.shadow_size = 6
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	_prepare.add_theme_stylebox_override("panel", box)
	_prepare.mouse_filter = Control.MOUSE_FILTER_STOP

	_prepare_label = UiTheme.make_label("PREPARER L'ARMEE", 18, Color.BLACK)
	_prepare_label.add_theme_font_override("font", UiTheme.font_bold())
	_prepare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prepare_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prepare.add_child(_prepare_label)


func _fill() -> void:
	if _battle.is_empty():
		_title.text = "Bataille introuvable"
		_prepare_enabled = false
		_prepare.modulate.a = 0.5
		return

	_title.text = "BATAILLE %d — %s" % [int(_battle["id"]), String(_battle["name"]).to_upper()]

	_style_card($Safe/Root/Scroll/BodyMargin/Body/EnemiesCard, UiTheme.DANGER, true)
	_enemies_body.add_child(UiTheme.make_label("ARMEE ENNEMIE", 14, UiTheme.DANGER))
	_enemies_body.get_child(0).add_theme_font_override("font", UiTheme.font_bold())

	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 12)
	_enemies_body.add_child(enemy_row)

	var enemies: Dictionary = _battle["enemies"]
	var enemy_level := int(_battle["level"])
	for type in Balance.UNIT_TYPES:
		if not enemies.has(type):
			continue
		enemy_row.add_child(_unit_card(type, "rouge", int(enemies[type]), enemy_level,
			UiTheme.DANGER, 40, 12, 10, "", true))

	_style_card($Safe/Root/Scroll/BodyMargin/Body/PlayerCard, UiTheme.GOLD, false)
	var header := HBoxContainer.new()
	_player_body.add_child(header)
	var header_title := UiTheme.make_label("TON ARMEE", 14, UiTheme.GOLD)
	header_title.add_theme_font_override("font", UiTheme.font_bold())
	header_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(header_title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var deploy_label := UiTheme.make_label(
		"Deploiement: %d/%d" % [_player_weight(), Game.deploy_capacity()], 12, Color("a0aabf"))
	deploy_label.add_theme_font_override("font", UiTheme.font_bold())
	deploy_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	deploy_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(deploy_label)

	var player_grid := HFlowContainer.new()
	player_grid.add_theme_constant_override("h_separation", 8)
	player_grid.add_theme_constant_override("v_separation", 8)
	_player_body.add_child(player_grid)

	var total := 0
	for type in Balance.ARMY_TYPES:
		var owned := Game.units_owned(type)
		total += owned
		if owned > 0:
			# La Dame n'a pas de caserne qui monte en niveau : elle affiche
			# celui de la Caserne des Pions, dont elle tient sa mobilite.
			var level := Game.building_level(type)
			if type == Balance.DAME:
				level = Game.building_level(Balance.PION)
			player_grid.add_child(_unit_card(type, "bleu", owned, level,
				UiTheme.ACCENT, 32, 11, 9, "PRET", false))
	if total == 0:
		_player_body.add_child(UiTheme.make_label(
			"Aucune unite - recrute au village.", 14, UiTheme.DANGER))
	_prepare_enabled = total > 0
	_prepare.modulate.a = 1.0 if _prepare_enabled else 0.5

	_style_card($Safe/Root/Scroll/BodyMargin/Body/InfoCard, Color(0, 0, 0, 0), false)
	var reward := Game.reward_for(int(_battle["id"]))
	_info_body.add_child(_info_row("Recompense totale", "%d Or" % reward, UiTheme.GOLD, true))

	# Ce que rapporteraient les Dames si elles restaient toutes au village :
	# c'est ici, avant le placement, que le choix se prepare.
	var dame_bonus := Game.dame_gold_bonus(reward)
	if dame_bonus > 0:
		var dames := Game.dames_owned()
		_info_body.add_child(_info_row(
			"Aura de %d Dame%s au repos" % [dames, "" if dames <= 1 else "s"],
			"+%d Or" % dame_bonus, Color("d8a0d0"), false))
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size = Vector2(0, 1)
	_info_body.add_child(sep)
	var terrain := "Plateau %d×%d cases" % [int(_battle["cols"]), int(_battle["rows"])]
	_info_body.add_child(_info_row("Terrain de bataille", terrain, Color("f0f3f8"), false))
	if Game.is_battle_won(int(_battle["id"])):
		_info_body.add_child(UiTheme.make_label("(bataille deja gagnee)", 12, UiTheme.TEXT_DIM))


## Poids total de l'armee possedee - cf. CASTLE_DATA.deploy_capacity dans
## balance.gd : la barre "Deploiement: X/Y" du briefing compare deja des
## poids, pas des effectifs.
func _player_weight() -> int:
	var weight := 0
	for type in Balance.ARMY_TYPES:
		weight += Game.units_owned(type) * Balance.deploy_weight(type)
	return weight


## Contour teinte (rouge ennemi / or joueur / aucun pour Info-Summary) - cf.
## captures Figma 03, ou seule la couleur de bordure distingue les 3 cartes.
func _style_card(card: PanelContainer, border: Color, glow: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("161926", 0.9)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(16)
	if border.a > 0:
		box.border_color = border
		box.set_border_width_all(1)
	if glow:
		box.shadow_color = Color(border, 0.3)
		box.shadow_size = 8
	card.add_theme_stylebox_override("panel", box)
	var body: VBoxContainer = card.get_node("%Body")
	body.add_theme_constant_override("separation", 12)


## Mini-carte d'unite (icone + nom + niveau [+ statut]) - reprend telles
## quelles les couleurs/tailles des Enemy/Player-Unit-Card de la capture
## Figma 03, plutot que la ligne de texte brut de la Phase 1.
func _unit_card(type: String, team_folder: String, count: int, level: int, accent: Color,
		icon_box_size: int, name_size: int, level_size: int, status: String, flex: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PANEL_LIGHT
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12)
	if not status.is_empty():
		box.border_color = accent
		box.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", box)
	if flex:
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		card.custom_minimum_size = Vector2(76, 0)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var icon_box := PanelContainer.new()
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(accent, 0.12)
	icon_style.set_corner_radius_all(8)
	icon_style.set_content_margin_all(icon_box_size * 0.12)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	icon_box.custom_minimum_size = Vector2(icon_box_size, icon_box_size)
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_box)

	var sprite := TextureRect.new()
	var path := "res://assets/pieces/%s/%s.png" % [team_folder, type]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(icon_box_size, icon_box_size) * 0.7
	icon_box.add_child(sprite)

	var name_text := Balance.unit_name(type)
	if flex:
		name_text += " ×%d" % count
	var name_label := UiTheme.make_label(name_text, name_size, Color("f0f3f8"))
	name_label.add_theme_font_override("font", UiTheme.font_bold())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(name_label)

	var level_label := UiTheme.make_label("Nv.%d" % level, level_size, Color("a0aabf"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(level_label)

	if not status.is_empty():
		var pill := PanelContainer.new()
		var pill_box := StyleBoxFlat.new()
		pill_box.bg_color = accent
		pill_box.set_corner_radius_all(4)
		pill_box.content_margin_left = 6
		pill_box.content_margin_right = 6
		pill_box.content_margin_top = 2
		pill_box.content_margin_bottom = 2
		pill.add_theme_stylebox_override("panel", pill_box)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var status_label := UiTheme.make_label(status, 8, Color("f0f3f8"))
		status_label.add_theme_font_override("font", UiTheme.font_bold())
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill.add_child(status_label)
		vbox.add_child(pill)

	UiTheme.ignore_mouse_recursive(vbox)
	return card


func _info_row(label_text: String, value_text: String, value_color: Color, bold_value: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := UiTheme.make_label(label_text, 13, Color("a0aabf"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var value := UiTheme.make_label(value_text, 13 if not bold_value else 14, value_color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	if bold_value:
		value.add_theme_font_override("font", UiTheme.font_bold())
	row.add_child(value)
	return row
