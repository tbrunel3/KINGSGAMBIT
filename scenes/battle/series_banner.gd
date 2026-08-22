class_name SeriesBanner
extends Control
##
## BANDEAU D'ENCHAINEMENT - ce qui remplace l'ecran de victoire entre deux
## combats d'une meme serie.
##
## Une serie est UN engagement, pas trois batailles cote a cote : la couronner
## trois fois vide la victoire de son sens, et impose trois clics pour un seul
## enjeu. Le bandeau dit le strict necessaire - ou on en est, ce qu'on a perdu,
## ce qui s'est releve - puis rend la main au combat suivant.
##
## Il part TOUT SEUL apres Balance.COMBAT.series_banner_seconds, et se coupe au
## doigt : on ne fait pas attendre quelqu'un qui a deja compris.
##
## Le grand lettrage, lui, reste pour la fin de la serie (cf. BattleResult).
##

signal continued

static var PLATE_FILL := PackedColorArray([
	Color("1e3278"), Color("0a1230"), Color("0e1a40")])

const GOLD_EDGE := Color("ffe680")
const TEXT_BRIGHT := Color("f0f3f8")
const TEXT_DIM := Color("a0aabf")
const RECOVERED := Color("5fb37a")

var _done := false


## `losses` et `recovered` sont indexes par type de piece, comme
## CampaignRun.losses.
func show_fight(fight: int, total: int, losses: Dictionary,
		recovered: Dictionary, pieces_left: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le bandeau avale les clics : le plateau reste visible dessous mais ne
	# doit plus repondre pendant qu'on lit.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("05070f", 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var plate := RoyalPlate.new()
	plate.fill_colors = PLATE_FILL
	plate.border_color = GOLD_EDGE
	plate.border_width = 4.0
	plate.corner_radius = 16.0
	plate.set_padding(18, 20, 18, 20)
	# 340 et non 300 : a 300, "Pertes du combat" et "2 Pions, 1 Cavalier" se
	# chevauchaient sur la meme ligne.
	plate.custom_minimum_size = Vector2(350, 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(plate)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)

	var title := UiTheme.gold_label("COMBAT %d SUR %d" % [fight, total], 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var caught := UiTheme.make_label("Combat remporté", 12, TEXT_DIM)
	caught.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caught)

	column.add_child(preload("res://scenes/ui/components/ornate_divider.tscn").instantiate())

	column.add_child(_line("Pertes du combat",
		"Aucune" if losses.is_empty() else _format(losses), TEXT_BRIGHT))
	if not recovered.is_empty():
		column.add_child(_line("Blessés relevés", _format(recovered), RECOVERED))
	column.add_child(_line("Armée restante", "%d pièces" % pieces_left, TEXT_BRIGHT))

	var hint := UiTheme.make_label("Touche pour continuer", 10, TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	_animate(plate)
	var timer := get_tree().create_timer(
		float(Balance.COMBAT["series_banner_seconds"]))
	timer.timeout.connect(_finish)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()


## Le bandeau ne peut partir qu'une fois : le doigt et le minuteur visent tous
## les deux la meme sortie.
func _finish() -> void:
	if _done:
		return
	_done = true
	continued.emit()


## Meme entree que l'ecran de resultat, en plus court (cf.
## BattleResult._animate_entry).
##
## On anime l'OPACITE et l'ECHELLE, jamais la position : la plaque est placee
## par un CenterContainer, et un tween de position se bat avec lui - la plaque
## se collait en haut de l'ecran.
func _animate(plate: Control) -> void:
	plate.modulate.a = 0.0
	plate.scale = Vector2(0.94, 0.94)
	await get_tree().process_frame
	if not is_instance_valid(plate):
		return
	plate.pivot_offset = plate.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(plate, "modulate:a", 1.0, 0.22)
	tween.tween_property(plate, "scale", Vector2.ONE, 0.3) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _line(label_text: String, value_text: String, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := UiTheme.make_label(label_text, 12, Color("c8a84b"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var value := UiTheme.make_label(value_text, 12, tint)
	value.add_theme_font_override("font", UiTheme.font_bold())
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	return row


## "1 Pion, 1 Cavalier" - une seule ligne, comme sur les ecrans de resultat.
func _format(counts: Dictionary) -> String:
	var details: Array = []
	for type in Balance.ARMY_TYPES:
		if counts.has(type):
			details.append(Balance.unit_count(type, int(counts[type])))
	return ", ".join(details)
