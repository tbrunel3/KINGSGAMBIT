extends Control
##
## POPUP DE BATIMENT - recrutement et amelioration.
##
## Le contenu est reconstruit a chaque rafraichissement : c'est plus simple a
## suivre qu'une mise a jour partielle, et le popup est trop petit pour que le
## cout en performance compte.
##
## Couvre les ecrans 08 (Chateau), 09 (Batiment), 10 (Batiment verrouille) et
## 11 (Amelioration en cours) de CLAUDE.md avec une seule scene : ce sont les
## memes donnees (Balance/GameState) presentees sous des formes voisines, pas
## quatre ecrans independants.
##

const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")
const CardScene := preload("res://scenes/ui/components/card.tscn")
const PillScene := preload("res://scenes/ui/components/pill.tscn")

var _type: String = ""

@onready var _modal: Modal = $Modal


func _ready() -> void:
	_modal.closed.connect(queue_free)

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


# ------------------------------- CONTENU -------------------------------------

func _refresh() -> void:
	if _type.is_empty() or not is_instance_valid(_modal):
		return

	var body := _modal.body
	# free() immediat, pas queue_free() : ce popup se reconstruit chaque
	# seconde (ticker) et sur chaque signal Game.*_changed, un free() differe
	# laisserait l'ancien et le nouveau contenu coexister le temps d'une
	# image, ce qui fausse la taille (et donc le centrage) du Panel.
	for child in body.get_children():
		body.remove_child(child)
		child.free()

	if _type == Balance.CASTLE:
		_modal.open(Balance.building_name(_type).to_upper(), Modal.Context.GOLD, "crown")
		body.add_child(_centered_pill("NIVEAU %d" % Game.castle_level(), Pill.Variant.INFO))
		body.add_child(DividerScene.instantiate())
		_add_castle_card(body)
		_add_upgrade_section(body)
	elif not Game.is_building_unlocked(_type):
		_modal.open(Balance.building_name(_type).to_upper(), Modal.Context.NEUTRAL, "lock")
		body.add_child(_centered_pill("VERROUILLE", Pill.Variant.DEFAULT))
		body.add_child(DividerScene.instantiate())
		_add_piece_card(body)
		body.add_child(DividerScene.instantiate())
		_add_locked_card(body)
	else:
		_modal.open("", Modal.Context.GOLD)
		if Game.is_upgrading(_type):
			# En-tete centre + pastille "en cours" - cf. capture Figma 11,
			# differente de l'en-tete en ligne des batiments au repos (09).
			body.add_child(_centered_title())
			body.add_child(_status_badge())
		else:
			body.add_child(_inline_header())
		body.add_child(DividerScene.instantiate())
		_add_piece_card(body)
		_add_recruit_row(body)
		_add_upgrade_section(body)


func _centered_pill(text: String, variant: Pill.Variant) -> CenterContainer:
	var center := CenterContainer.new()
	var pill: Pill = PillScene.instantiate()
	center.add_child(pill)
	pill.set_data.call_deferred("", text, variant)
	return center


func _centered_title() -> Label:
	var title := UiTheme.make_label(Balance.building_name(_type).to_upper(), 18, Color("f0f3f8"))
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	return title


## Pastille "amelioration en cours" (icone sablier + texte) - cf. capture
## Figma 11 (Status-Badge), fond dore translucide plutot qu'un pill neutre.
func _status_badge() -> CenterContainer:
	var center := CenterContainer.new()
	var badge := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("d4af37", 0.25)
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", box)
	center.add_child(badge)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	badge.add_child(row)
	var icon := Icon.new()
	icon.icon_name = "coin"
	icon.color = UiTheme.GOLD
	icon.custom_minimum_size = Vector2(10, 10)
	row.add_child(icon)
	var label := UiTheme.make_label("AMELIORATION EN COURS", 10, UiTheme.GOLD)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	return center


## Ligne icone-piece + titre + sous-titre, alignee a gauche - cf. capture
## Figma 09 (batiments deja debloques, par opposition au blason centre des
## modales Chateau/Victoire/Defaite).
func _inline_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_piece_badge(48))

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := UiTheme.make_label(Balance.building_name(_type).to_upper(), 15, UiTheme.TEXT)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(title)
	var subtitle := UiTheme.make_label(
		"Niveau %d  -  Troupes: %d/%d" % [
			Game.building_level(_type), Game.units_owned(_type),
			Balance.capacity(_type, Game.building_level(_type))],
		12, UiTheme.TEXT_DIM)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(subtitle)
	row.add_child(texts)
	return row


func _piece_badge(size: int) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(size, size)
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PANEL_LIGHT
	box.set_corner_radius_all(10)
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", box)

	var path := "res://assets/pieces/bleu/%s.png" % _type
	if ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.texture = load(path)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.add_child(tex)
	return badge


func _add_castle_card(body: VBoxContainer) -> void:
	var card: PanelContainer = CardScene.instantiate()
	var card_body: VBoxContainer = card.get_node("%Body")
	card_body.add_child(UiTheme.stat_row("Deploiement actuel",
		UiTheme.make_label("%d unites" % Game.deploy_slots(), 14, Color("f0f3f8"))))
	if not Game.is_max_level(Balance.CASTLE):
		card_body.add_child(HSeparator.new())
		var next_slots := Balance.deploy_slots(Game.castle_level() + 1)
		# "15 -> 22 unites" plutot que la seule valeur suivante, pour montrer
		# le gain d'un coup d'oeil - cf. Stat-Line-Next (capture Figma 08).
		var compare := HBoxContainer.new()
		compare.add_theme_constant_override("separation", 6)
		var current_label := UiTheme.make_label(str(Game.deploy_slots()), 13, Color("a0aabf"))
		current_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		compare.add_child(current_label)
		var arrow := UiTheme.make_label("->", 13, UiTheme.GOLD)
		arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
		compare.add_child(arrow)
		var next_label := UiTheme.make_label("%d unites" % next_slots, 14, UiTheme.GOLD)
		next_label.add_theme_font_override("font", UiTheme.font_bold())
		next_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		compare.add_child(next_label)
		card_body.add_child(UiTheme.stat_row("Prochain niveau", compare))
	body.add_child(card)


## Batiment pas encore construit (Ecuries, Cloitre, Donjon au tout debut) :
## un aperçu et le seuil de chateau qui le fera apparaitre, gratuitement.
func _add_locked_card(body: VBoxContainer) -> void:
	var required := Balance.unlock_castle_level(_type)
	var card: PanelContainer = CardScene.instantiate()
	var card_body: VBoxContainer = card.get_node("%Body")
	card_body.add_child(UiTheme.make_label(
		"Disponible au Chateau niveau %d" % required, 15, UiTheme.GOLD))
	card_body.add_child(UiTheme.make_label(
		"Chateau actuel : niveau %d" % Game.castle_level(), 13, UiTheme.TEXT_DIM))

	var track := Control.new()
	track.custom_minimum_size = Vector2(0, 8)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(bg)
	var fraction := clampf(float(Game.castle_level()) / float(required), 0.0, 1.0)
	var fill := ColorRect.new()
	fill.color = UiTheme.GOLD
	fill.anchor_bottom = 1.0
	fill.anchor_right = fraction
	track.add_child(fill)
	card_body.add_child(track)

	body.add_child(card)


func _add_piece_card(body: VBoxContainer) -> void:
	var card: PanelContainer = CardScene.instantiate()
	var card_body: VBoxContainer = card.get_node("%Body")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_piece_badge(56))

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UiTheme.make_label(
		"LE %s" % Balance.unit_name(_type).to_upper(), 12, UiTheme.GOLD)
	name_label.add_theme_font_override("font", UiTheme.font_bold())
	texts.add_child(name_label)

	var level := maxi(1, Game.building_level(_type))
	var current_move := Balance.move_description(_type, level)
	var current_desc := UiTheme.make_label(current_move, 11, Color("f0f3f8"))
	current_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(current_desc)

	if Game.is_building_unlocked(_type) and level < Balance.max_level(_type):
		var next_move := Balance.move_description(_type, level + 1)
		if next_move != current_move:
			var upgrade_desc := UiTheme.make_label("Portee : %s -> %s" % [current_move, next_move], 11, UiTheme.SUCCESS)
			texts.add_child(upgrade_desc)

	if _type == Balance.PION:
		texts.add_child(UiTheme.make_label(
			"Un pion qui atteint le fond adverse devient Dame, avec sa propre " +
			"mobilite, le temps du combat.", 11, UiTheme.GOLD.darkened(0.2)))

	row.add_child(texts)
	card_body.add_child(row)
	body.add_child(card)


func _add_recruit_row(body: VBoxContainer) -> void:
	var level := Game.building_level(_type)
	var owned := Game.units_owned(_type)
	var cap := Balance.capacity(_type, level)
	var cost := Game.recruit_cost(_type)
	var complete := owned >= cap

	body.add_child(_action_row(
		"RECRUTER %s" % Balance.unit_name(_type).to_upper(), Color("f0f3f8"),
		"%d Or" % cost, "",
		"Complet" if complete else "RECRUTER",
		Color("2e5bff"), Color(0, 0, 0, 0),
		complete or not Game.can_afford(cost),
		func(): Game.recruit(_type),
		Color("2a2f45")))


## Ligne compacte titre/cout(+duree) a gauche, bouton d'action a droite - le
## meme gabarit sert au recrutement et a l'amelioration (Option-Recruit et
## Option-Upgrade des captures Figma 09/10), seule la couleur d'accent change.
func _action_row(title_text: String, title_color: Color, cost_text: String, extra_text: String,
		button_text: String, button_bg: Color, button_border: Color, disabled: bool,
		on_press: Callable, border: Color) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1f2e")
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	row_panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row_panel.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	var title := UiTheme.make_label(title_text, 12, title_color)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	texts.add_child(title)

	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	var cost_label := UiTheme.make_label(cost_text, 12, UiTheme.GOLD)
	cost_label.add_theme_font_override("font", UiTheme.font_bold())
	cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost_row.add_child(cost_label)
	if not extra_text.is_empty():
		var extra_label := UiTheme.make_label(extra_text, 11, Color("a0aabf"))
		extra_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		cost_row.add_child(extra_label)
	texts.add_child(cost_row)
	row.add_child(texts)

	var button := PanelContainer.new()
	var button_box := StyleBoxFlat.new()
	button_box.bg_color = button_bg
	button_box.set_corner_radius_all(6)
	if button_border.a > 0:
		button_box.border_color = button_border
		button_box.set_border_width_all(1)
	button_box.content_margin_left = 16
	button_box.content_margin_right = 16
	button_box.content_margin_top = 8
	button_box.content_margin_bottom = 8
	button.add_theme_stylebox_override("panel", button_box)
	button.modulate.a = 0.5 if disabled else 1.0
	var button_label := UiTheme.make_label(button_text, 11, Color("f0f3f8"))
	button_label.add_theme_font_override("font", UiTheme.font_bold())
	button_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(button_label)
	if not disabled:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				on_press.call())
	row.add_child(button)

	return row_panel


func _add_upgrade_section(body: VBoxContainer) -> void:
	if Game.is_upgrading(_type):
		var level := Game.building_level(_type)
		var card: PanelContainer = CardScene.instantiate()
		var card_body: VBoxContainer = card.get_node("%Body")
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.add_child(_piece_badge(48))
		var step := VBoxContainer.new()
		step.alignment = BoxContainer.ALIGNMENT_CENTER
		step.add_theme_constant_override("separation", 2)
		var step_label := UiTheme.make_label("NIVEAU", 11, Color("a0aabf"))
		step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step.add_child(step_label)
		var step_row := HBoxContainer.new()
		step_row.alignment = BoxContainer.ALIGNMENT_CENTER
		step_row.add_theme_constant_override("separation", 8)
		var from_label := UiTheme.make_label(str(level), 16, Color("f0f3f8"))
		from_label.add_theme_font_override("font", UiTheme.font_bold())
		step_row.add_child(from_label)
		var arrow := UiTheme.make_label("->", 14, UiTheme.GOLD)
		step_row.add_child(arrow)
		var to_label := UiTheme.make_label(str(level + 1), 18, UiTheme.GOLD)
		to_label.add_theme_font_override("font", UiTheme.font_bold())
		step_row.add_child(to_label)
		step.add_child(step_row)
		row.add_child(step)
		card_body.add_child(row)
		body.add_child(card)

		body.add_child(UiTheme.stat_row("Temps restant",
			UiTheme.make_label("%s restantes" % UiTheme.format_duration(Game.upgrade_remaining(_type)), 12, UiTheme.GOLD)))

		var seconds_total := maxf(1.0, float(Balance.upgrade_seconds(_type, level)))
		var fraction := 1.0 - clampf(float(Game.upgrade_remaining(_type)) / seconds_total, 0.0, 1.0)
		var track := PanelContainer.new()
		var track_box := StyleBoxFlat.new()
		track_box.bg_color = Color("1c1f2e")
		track_box.set_corner_radius_all(5)
		track.add_theme_stylebox_override("panel", track_box)
		track.custom_minimum_size = Vector2(0, 10)
		var fill := ColorRect.new()
		fill.color = UiTheme.GOLD
		fill.anchor_bottom = 1.0
		fill.anchor_right = fraction
		track.add_child(fill)
		body.add_child(track)

		body.add_child(DividerScene.instantiate())
		body.add_child(_bonus_preview(level + 1))

		var skip := Button.new()
		skip.text = "Terminer maintenant (test)"
		skip.theme_type_variation = "SecondaryButton"
		skip.add_theme_font_size_override("font_size", 11)
		skip.pressed.connect(func(): Game.force_finish_upgrade(_type))
		body.add_child(skip)
		return

	if Game.is_max_level(_type):
		body.add_child(UiTheme.make_label("Niveau maximum atteint.", 14, UiTheme.TEXT_DIM))
		return

	var level := Game.building_level(_type)
	var cost := Balance.upgrade_cost(_type, level)
	var seconds := Balance.upgrade_seconds(_type, level)

	body.add_child(_action_row(
		"AMELIORER BATIMENT", UiTheme.GOLD,
		"%d Or" % cost, UiTheme.format_duration(seconds),
		"AMELIORER", UiTheme.GOLD_BUTTON, Color("ffd700"),
		not Game.can_afford(cost),
		func(): Game.start_upgrade(_type),
		Color("d4af37")))


## Bulles d'apercu des gains du prochain niveau - cf. Bonus-Preview (capture
## Figma 11). Derive de Balance plutot qu'ecrit en dur : capacite (toujours
## disponible) et portee (seulement si le mouvement change a ce niveau).
func _bonus_preview(next_level: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1f2e")
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var heading := UiTheme.make_label("AU NIVEAU %d :" % next_level, 11, Color("a0aabf"))
	heading.add_theme_font_override("font", UiTheme.font_bold())
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(heading)

	var cap_now := Balance.capacity(_type, next_level - 1)
	var cap_next := Balance.capacity(_type, next_level)
	vbox.add_child(UiTheme.make_label(
		"- Capacite augmentee : %d -> %d" % [cap_now, cap_next], 12, Color("f0f3f8")))

	var move_now := Balance.move_description(_type, next_level - 1)
	var move_next := Balance.move_description(_type, next_level)
	if move_now != move_next:
		vbox.add_child(UiTheme.make_label("- Portee : %s -> %s" % [move_now, move_next], 12, Color("f0f3f8")))

	return panel
