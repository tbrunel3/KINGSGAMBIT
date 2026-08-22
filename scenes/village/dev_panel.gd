extends Control
##
## PANNEAU DEV - raccourcis de test ouverts depuis le bouton DEV du village.
##
## Rien ici ne fait partie du jeu normal : c'est le remplacant du bouton RAZ,
## pour atteindre vite un etat a tester (or, batiments, batailles) sans
## rejouer toute la campagne a la main.
##

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Center/Panel
@onready var _content: VBoxContainer = $Center/Panel/Content


func _ready() -> void:
	UiTheme.style_panel(_panel)
	_dim.gui_input.connect(_on_dim_input)
	_build()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


func _build() -> void:
	_content.add_child(UiTheme.make_label("Outils de test", 20, UiTheme.GOLD))
	_content.add_child(HSeparator.new())

	_add_action("+1000 or", func(): Game.add_gold(1000))
	_add_action("Debloquer tous les batiments", func(): Game.dev_unlock_all_buildings())
	_add_action("Terminer toutes les ameliorations", func(): Game.dev_finish_all_upgrades())
	_add_action("Debloquer toutes les batailles", func(): Game.dev_unlock_all_battles())
	_add_action("+1 Dame au Château", func(): Game.dev_grant_dame())

	_content.add_child(HSeparator.new())
	var reset := UiTheme.make_button("RAZ - effacer la sauvegarde", UiTheme.DANGER.darkened(0.25), 15)
	reset.pressed.connect(_on_reset_pressed)
	_content.add_child(reset)

	var close := UiTheme.make_button("Fermer", UiTheme.PANEL_LIGHT, 15)
	close.pressed.connect(queue_free)
	_content.add_child(close)


func _add_action(label: String, action: Callable) -> void:
	var button := UiTheme.make_button(label, UiTheme.ACCENT.darkened(0.3), 15)
	button.pressed.connect(action)
	_content.add_child(button)


func _on_reset_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Effacer la sauvegarde et repartir de zero ?"
	dialog.title = "Réinitialiser"
	add_child(dialog)
	dialog.confirmed.connect(func():
		Game.reset_progress()
		queue_free()
	)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog.queue_free()
	)
	dialog.popup_centered()
