extends Control
##
## VILLAGE - ecran principal : chateau, batiments, or, bouton bataille.
##
## Cet ecran ne contient aucune regle de jeu : il lit GameState et appelle ses
## methodes. Les boutons de batiment sont generes a partir de Balance.UNIT_TYPES,
## donc ajouter un type d'unite suffit a le faire apparaitre ici.
##

const BuildingPopupScene := preload("res://scenes/village/building_popup.tscn")
const DevPanelScene := preload("res://scenes/village/dev_panel.tscn")

@onready var _gold_label: Label = $Safe/Root/TopBar/TopRow/GoldLabel
@onready var _dev_button: Button = $Safe/Root/TopBar/TopRow/DevButton
@onready var _title: Label = $Safe/Root/Header/TitleLabel
@onready var _story: Label = $Safe/Root/Header/StoryLabel
@onready var _castle_button: Button = $Safe/Root/CastleButton
@onready var _grid: GridContainer = $Safe/Root/BuildingsGrid
@onready var _next_battle_label: Label = $Safe/Root/NextBattleLabel
@onready var _battle_button: Button = $Safe/Root/BattleButton

var _building_buttons: Dictionary = {}  # type -> Button
var _popup: Control = null


func _ready() -> void:
	_style()
	_build_building_buttons()

	_castle_button.pressed.connect(_on_building_pressed.bind(Balance.CASTLE))
	_battle_button.pressed.connect(_on_battle_pressed)
	_dev_button.pressed.connect(_on_dev_pressed)

	Game.gold_changed.connect(func(_g): _refresh())
	Game.units_changed.connect(_refresh)
	Game.buildings_changed.connect(_refresh)
	Game.progress_changed.connect(_refresh)

	# Les ameliorations avancent meme jeu ferme : on verifie a l'ouverture,
	# puis chaque seconde pour animer le compte a rebours.
	Game.check_upgrades()

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.timeout.connect(_on_tick)
	add_child(ticker)
	ticker.start()

	_refresh()


func _style() -> void:
	UiTheme.style_panel($Safe/Root/TopBar)
	UiTheme.style_button(_dev_button, UiTheme.PANEL_LIGHT)
	UiTheme.style_button(_castle_button, UiTheme.GOLD.darkened(0.55))
	UiTheme.style_button(_battle_button, UiTheme.ACCENT)

	_gold_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_gold_label.add_theme_font_size_override("font_size", 20)
	_dev_button.add_theme_font_size_override("font_size", 12)

	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override("font_size", 30)
	_story.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_story.add_theme_font_size_override("font_size", 13)

	_castle_button.add_theme_font_size_override("font_size", 17)
	_battle_button.add_theme_font_size_override("font_size", 22)
	_next_battle_label.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_next_battle_label.add_theme_font_size_override("font_size", 13)

	var version := UiTheme.make_label(
		"v%s" % ProjectSettings.get_setting("application/config/version", "1.0.0"),
		11, UiTheme.TEXT_DIM.darkened(0.25))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Safe/Root/Header.add_child(version)


func _build_building_buttons() -> void:
	for type in Balance.UNIT_TYPES:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 86)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		UiTheme.style_button(button, Balance.unit_color(type).darkened(0.55))
		button.pressed.connect(_on_building_pressed.bind(type))
		_grid.add_child(button)
		_building_buttons[type] = button


# ------------------------------- RAFRAICHISSEMENT ----------------------------

func _refresh() -> void:
	_gold_label.text = "Or  %d" % Game.gold

	_castle_button.text = "%s\nNiveau %d  -  %d unites deployables" % [
		Balance.CASTLE_DATA["name"],
		Game.castle_level(),
		Game.deploy_slots(),
	]
	if Game.is_upgrading(Balance.CASTLE):
		_castle_button.text += "\nAmelioration : %s" % UiTheme.format_duration(
			Game.upgrade_remaining(Balance.CASTLE))

	for type in _building_buttons.keys():
		var button: Button = _building_buttons[type]
		button.text = _building_label(type)
		var base_color := Balance.unit_color(type).darkened(0.55)
		UiTheme.style_button(button, base_color.darkened(0.4) if not Game.is_building_unlocked(type) else base_color)

	if Game.is_campaign_complete():
		_next_battle_label.text = "Campagne terminee - la Dame est retrouvee"
		_battle_button.text = "REJOUER LA DERNIERE"
	else:
		var data := Balance.battle(Game.unlocked_battle())
		_next_battle_label.text = "Prochaine bataille : %d / %d  -  %s" % [
			int(data["id"]), Balance.battle_count(), String(data["name"])
		]
		_battle_button.text = "BATAILLE"


func _building_label(type: String) -> String:
	if not Game.is_building_unlocked(type):
		return "%s\nChateau Nv.%d requis" % [
			Balance.building_name(type),
			Balance.unlock_castle_level(type),
		]

	var level := Game.building_level(type)
	var text := "%s\nNv.%d  -  %d/%d unites" % [
		Balance.building_name(type),
		level,
		Game.units_owned(type),
		Balance.capacity(type, level),
	]
	if Game.is_upgrading(type):
		text += "\n%s" % UiTheme.format_duration(Game.upgrade_remaining(type))
	return text


func _on_tick() -> void:
	Game.check_upgrades()
	# Rafraichit les comptes a rebours affiches.
	if Game.is_upgrading(Balance.CASTLE):
		_refresh()
		return
	for type in Balance.UNIT_TYPES:
		if Game.is_upgrading(type):
			_refresh()
			return


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
