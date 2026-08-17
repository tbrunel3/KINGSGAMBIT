extends Control
##
## POPUP DE BATIMENT - recrutement et amelioration.
##
## Le contenu est reconstruit a chaque rafraichissement : c'est plus simple a
## suivre qu'une mise a jour partielle, et le popup est trop petit pour que le
## cout en performance compte.
##

var _type: String = ""

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Center/Panel
@onready var _content: VBoxContainer = $Center/Panel/Content


func _ready() -> void:
	UiTheme.style_panel(_panel)
	_dim.gui_input.connect(_on_dim_input)

	Game.gold_changed.connect(func(_g): _refresh())
	Game.units_changed.connect(_refresh)
	Game.buildings_changed.connect(_refresh)

	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.timeout.connect(func():
		Game.check_upgrades()
		if Game.is_upgrading(_type):
			_refresh()
	)
	add_child(ticker)
	ticker.start()


## Appele par le village juste apres l'instanciation.
func open(type: String) -> void:
	_type = type
	_refresh()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		queue_free()


# ------------------------------- CONTENU -------------------------------------

func _refresh() -> void:
	if _type.is_empty() or _content == null:
		return

	for child in _content.get_children():
		child.queue_free()

	_add_header()
	if _type == Balance.CASTLE:
		_add_castle_body()
	else:
		_add_unit_body()
	_add_upgrade_section()

	var close := UiTheme.make_button("Fermer", UiTheme.PANEL_LIGHT, 15)
	close.pressed.connect(queue_free)
	_content.add_child(close)


func _add_header() -> void:
	var title := UiTheme.make_label(Balance.building_name(_type), 21, Balance.unit_color(_type))
	_content.add_child(title)

	var level := UiTheme.make_label(
		"Niveau %d / %d" % [Game.building_level(_type), Balance.max_level(_type)],
		13, UiTheme.TEXT_DIM)
	_content.add_child(level)
	_content.add_child(HSeparator.new())


func _add_castle_body() -> void:
	_content.add_child(UiTheme.make_label(
		"Le Roi tient le chateau. Ameliorer la forteresse augmente le nombre "
		+ "d'unites que tu peux deployer en bataille.", 13, UiTheme.TEXT_DIM))
	_content.add_child(UiTheme.make_label(
		"Unites deployables : %d" % Game.deploy_slots(), 16))


func _add_unit_body() -> void:
	var level := Game.building_level(_type)
	var stats := Balance.unit_stats(_type, level)
	var owned := Game.units_owned(_type)
	var cap := Balance.capacity(_type, level)

	_content.add_child(UiTheme.make_label("Unites : %d / %d" % [owned, cap], 16))

	var move_text := "portee %d" % int(stats.get("move_range", 0))
	if _type == Balance.CAVALIER:
		move_text = "saut (ignore les unites)"
	_content.add_child(UiTheme.make_label(
		"PV %d   Degats %d   Deplacement %s   Attaque %d" % [
			int(stats["hp"]), int(stats["damage"]), move_text, int(stats["attack_range"])
		], 13, UiTheme.TEXT_DIM))

	_content.add_child(HSeparator.new())

	var cost := Game.recruit_cost(_type)
	var recruit := UiTheme.make_button("Recruter  -  %d or" % cost, UiTheme.SUCCESS.darkened(0.35), 16)
	if owned >= cap:
		recruit.text = "Caserne pleine (Nv.%d max %d)" % [level, cap]
		recruit.disabled = true
	elif not Game.can_afford(cost):
		recruit.disabled = true
	recruit.pressed.connect(func(): Game.recruit(_type))
	_content.add_child(recruit)


func _add_upgrade_section() -> void:
	_content.add_child(HSeparator.new())

	if Game.is_upgrading(_type):
		_content.add_child(UiTheme.make_label(
			"Amelioration en cours : %s" % UiTheme.format_duration(Game.upgrade_remaining(_type)),
			15, UiTheme.GOLD))
		_content.add_child(UiTheme.make_label(
			"Le chantier avance meme jeu ferme.", 12, UiTheme.TEXT_DIM))
		var skip := UiTheme.make_button("Terminer maintenant (test)", UiTheme.PANEL_LIGHT, 13)
		skip.pressed.connect(func(): Game.force_finish_upgrade(_type))
		_content.add_child(skip)
		return

	if Game.is_max_level(_type):
		_content.add_child(UiTheme.make_label("Niveau maximum atteint.", 14, UiTheme.TEXT_DIM))
		return

	var level := Game.building_level(_type)
	var cost := Balance.upgrade_cost(_type, level)
	var seconds := Balance.upgrade_seconds(_type, level)

	var gain := "capacite et statistiques du niveau %d" % (level + 1)
	if _type == Balance.CASTLE:
		gain = "%d unites deployables" % Balance.deploy_slots(level + 1)
	_content.add_child(UiTheme.make_label("Niveau %d : %s" % [level + 1, gain], 13, UiTheme.TEXT_DIM))

	var upgrade := UiTheme.make_button(
		"Ameliorer  -  %d or  -  %s" % [cost, UiTheme.format_duration(seconds)],
		UiTheme.ACCENT.darkened(0.25), 15)
	upgrade.disabled = not Game.can_afford(cost)
	upgrade.pressed.connect(func(): Game.start_upgrade(_type))
	_content.add_child(upgrade)
