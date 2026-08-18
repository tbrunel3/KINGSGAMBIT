extends Control
##
## CAMPAGNE - liste des batailles debloquees.
##
## Sert autant a progresser qu'a REJOUER : une bataille deja gagnee reste
## accessible pour refaire de l'or, a taux reduit (Balance.REPLAY_REWARD_RATIO).
## Sans cet ecran, un joueur qui perd son armee n'aurait aucun moyen de la
## reconstituer, les pertes etant definitives.
##

@onready var _back: Button = $Safe/Root/BackButton
@onready var _title: Label = $Safe/Root/TitleLabel
@onready var _hint: Label = $Safe/Root/HintLabel
@onready var _list: VBoxContainer = $Safe/Root/Scroll/List


func _ready() -> void:
	UiTheme.style_button(_back, UiTheme.PANEL_LIGHT)
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_title.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	_hint.add_theme_font_size_override("font_size", 12)

	_back.pressed.connect(Router.goto_village)
	_fill()


func _fill() -> void:
	var unlocked := Game.unlocked_battle()
	_hint.text = "Une bataille deja gagnee peut etre rejouee pour refaire de l'or, a %d%% de la recompense." % int(
		Balance.REPLAY_REWARD_RATIO * 100.0)

	for data in Balance.CAMPAIGN:
		var id := int(data["id"])
		var available := id <= unlocked
		var won := Game.is_battle_won(id)

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 74)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var enemy_count := 0
		for type in data["enemies"].keys():
			enemy_count += int(data["enemies"][type])

		if available:
			var state := "rejouable" if won else "nouvelle"
			button.text = "  %d.  %s   (%s)\n  %d ennemis Nv.%d   -   %d or" % [
				id, String(data["name"]), state,
				enemy_count, int(data["level"]), Game.reward_for(id),
			]
			var color: Color = UiTheme.PANEL_LIGHT if won else UiTheme.ACCENT.darkened(0.15)
			UiTheme.style_button(button, color)
			button.pressed.connect(func(): Router.goto_prep(id))
		else:
			button.text = "  %d.  ?   -   verrouille" % id
			button.disabled = true
			UiTheme.style_button(button, UiTheme.PANEL)

		_list.add_child(button)
