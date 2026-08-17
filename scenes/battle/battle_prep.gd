extends Control
##
## PREPARATION DE BATAILLE - le briefing affiche avant le placement.
##
## Numero, composition ennemie, recompense, unites disponibles : tout vient de
## Balance.CAMPAIGN et de GameState, rien n'est ecrit en dur ici.
##

@onready var _back: Button = $Safe/Root/BackButton
@onready var _title: Label = $Safe/Root/TitleLabel
@onready var _name: Label = $Safe/Root/NameLabel
@onready var _panel: PanelContainer = $Safe/Root/InfoPanel
@onready var _info: VBoxContainer = $Safe/Root/InfoPanel/InfoBox
@onready var _prepare: Button = $Safe/Root/PrepareButton

var _battle: Dictionary = {}


func _ready() -> void:
	_battle = Router.current_battle()

	UiTheme.style_button(_back, UiTheme.PANEL_LIGHT)
	UiTheme.style_button(_prepare, UiTheme.ACCENT)
	UiTheme.style_panel(_panel)
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override("font_size", 26)
	_name.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_prepare.add_theme_font_size_override("font_size", 20)

	_back.pressed.connect(Router.goto_village)
	_prepare.pressed.connect(func(): Router.goto_battle(int(_battle["id"])))

	_fill()


func _fill() -> void:
	if _battle.is_empty():
		_title.text = "Bataille introuvable"
		_prepare.disabled = true
		return

	_title.text = "BATAILLE %d / %d" % [int(_battle["id"]), Balance.battle_count()]
	_name.text = String(_battle["name"])

	_info.add_child(_section("Armee ennemie", UiTheme.ENEMY.lightened(0.2)))
	var enemies: Dictionary = _battle["enemies"]
	var enemy_level := int(_battle["level"])
	for type in Balance.UNIT_TYPES:
		if not enemies.has(type):
			continue
		var stats := Balance.unit_stats(type, enemy_level)
		_info.add_child(UiTheme.make_label(
			"%d x %s Nv.%d   (%d PV, %d degats)" % [
				int(enemies[type]), Balance.unit_name(type), enemy_level,
				int(stats["hp"]), int(stats["damage"])
			], 14))

	_info.add_child(HSeparator.new())
	_info.add_child(_section("Ton armee", UiTheme.ACCENT.lightened(0.2)))
	var total := 0
	for type in Balance.UNIT_TYPES:
		var owned := Game.units_owned(type)
		total += owned
		if owned > 0:
			_info.add_child(UiTheme.make_label(
				"%d x %s Nv.%d" % [owned, Balance.unit_name(type), Game.building_level(type)], 14))
	if total == 0:
		_info.add_child(UiTheme.make_label("Aucune unite - recrute au village.", 14, UiTheme.DANGER))

	_info.add_child(UiTheme.make_label(
		"Deployables : %d (niveau du chateau)" % Game.deploy_slots(), 13, UiTheme.TEXT_DIM))

	_info.add_child(HSeparator.new())
	_info.add_child(UiTheme.make_label(
		"Recompense : %d or" % int(_battle["reward"]), 16, UiTheme.GOLD))
	_info.add_child(UiTheme.make_label(
		"Terrain : %d x %d cases" % [int(_battle["cols"]), int(_battle["rows"])],
		13, UiTheme.TEXT_DIM))

	_prepare.disabled = total == 0


func _section(text: String, color: Color) -> Label:
	return UiTheme.make_label(text, 17, color)
