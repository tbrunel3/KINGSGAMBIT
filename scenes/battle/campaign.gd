extends Control
##
## CAMPAGNE - carte de progression, chemin trace sur le parchemin.
##
## Reproduit assets/screens/02_Campagne.png : le chemin en pointilles est deja
## dessine dans assets/backgrounds/parchment_map.png (voir son en-tete), donc
## seules les pastilles de bataille sont posees ici, aux positions mesurees
## sur la capture Figma puis interpolees pour les 10 batailles du jeu (la
## maquette n'en montre que 5 a la fois, pensee pour un parchemin qui defile).
##
## Sert autant a progresser qu'a REJOUER : une bataille deja gagnee reste
## accessible pour refaire de l'or, a taux reduit (Balance.REPLAY_REWARD_RATIO).
##

## Centres des pastilles (coordonnees ecran, 393x852), mesures sur la capture
## Figma pour les batailles 1-5 puis prolonges le long de la meme courbe pour
## atteindre les 10 batailles de Balance.CAMPAIGN.
const NODE_POS := [
	Vector2(194.7, 737.5),
	Vector2(174.2, 660.2),
	Vector2(153.6, 582.7),
	Vector2(170.0, 511.6),
	Vector2(198.8, 442.3),
	Vector2(206.9, 372.1),
	Vector2(194.7, 300.9),
	Vector2(177.4, 235.3),
	Vector2(145.2, 186.4),
	Vector2(112.9, 137.6),
]

const WON_COLOR := Color("339940")
const AVAILABLE_COLOR := Color("ffd11a")
const LOCKED_COLOR := Color("594d38")

@onready var _overlay: Control = $Overlay


func _ready() -> void:
	_build_planks()
	_build_progress_pill()
	for data in Balance.CAMPAIGN:
		_build_node(int(data["id"]), String(data["name"]))
	_build_village_button()
	_refresh()


## Lattes de bois horizontales derriere le parchemin, cf. CLAUDE.md > 02_Campagne.
func _build_planks() -> void:
	var planks: Control = $Planks
	var tones := [Color("3b2b1c"), Color("423324"), Color("4a3b2b")]
	var plank_h := 72.0
	var count := ceili(852.0 / plank_h)
	for i in range(count):
		var rect := ColorRect.new()
		rect.color = tones[i % tones.size()]
		rect.position = Vector2(0, i * plank_h)
		rect.size = Vector2(393, plank_h)
		planks.add_child(rect)


func _build_progress_pill() -> void:
	_progress_pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_overlay.add_child(_progress_pill)


var _progress_pill: Pill
var _nodes: Dictionary = {}   # id -> {"circle":.., "label":..}


func _build_node(id: int, battle_name: String) -> void:
	var center: Vector2 = NODE_POS[id - 1]

	var circle := PanelContainer.new()
	_overlay.add_child(circle)
	circle.mouse_filter = Control.MOUSE_FILTER_STOP
	circle.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_node_pressed(id))

	var glyph := Control.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(glyph)

	var label := PanelContainer.new()
	_overlay.add_child(label)
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
	_overlay.add_child(_village_button)

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
	_village_button.position = Vector2((393 - _village_button.size.x) / 2.0, 800)


var _village_button: PanelContainer


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
	_progress_pill.size = _progress_pill.get_combined_minimum_size()
	_progress_pill.position = Vector2(393 - 16 - _progress_pill.size.x, 20)

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
		if state == "available":
			box.shadow_color = AVAILABLE_COLOR.darkened(0.1)
			box.shadow_color.a = 0.6
			box.shadow_size = 8
		circle.add_theme_stylebox_override("panel", box)
		circle.custom_minimum_size = Vector2(diameter, diameter)
		circle.size = Vector2(diameter, diameter)
		circle.position = center - circle.size / 2.0

		match state:
			"won":
				var check := Icon.new()
				check.icon_name = "check"
				check.color = Color.WHITE
				check.custom_minimum_size = Vector2(diameter, diameter)
				glyph.add_child(check)
			"available":
				var number := UiTheme.make_label(str(id), 17, Color("1a1206"))
				number.add_theme_font_override("font", UiTheme.font_bold())
				number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				number.size = Vector2(diameter, diameter)
				number.autowrap_mode = TextServer.AUTOWRAP_OFF
				glyph.add_child(number)
			"locked":
				var lock := Icon.new()
				lock.icon_name = "lock"
				lock.color = Color("807361")
				lock.custom_minimum_size = Vector2(diameter, diameter)
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
	if id <= Game.unlocked_battle():
		Router.goto_prep(id)
