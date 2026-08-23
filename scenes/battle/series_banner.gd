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

## Palette relevee sur Figma popup-combat-phase (410:7190). Ce bandeau ne
## porte PAS la plaque royale bleu nuit du reste du jeu : le designer l'a posee
## en brun de tente et or, la couleur du campement entre deux assauts. C'est
## une decision d'apparence, donc la sienne (regle 2 du projet).
static var PLATE_FILL := PackedColorArray([
	Color("1c1409"), Color("140f07")])

const GOLD_EDGE := Color("e6b940")
const TEXT_BRIGHT := Color("f5efea")
const TEXT_DIM := Color("a89b91")
const BOX_FILL := Color("291e12")
const RECOVERED := Color("5fb37a")
const CONTINUE_FILL := Color("9b2c2c")

## Au-dela, la rangee de silhouettes deborde de la plaque.
const MAX_GLYPHS := 6

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

	var eyebrow := UiTheme.make_label("PHASE DE COMBAT", 12, GOLD_EDGE)
	eyebrow.add_theme_font_override("font", UiTheme.font_bold())
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(eyebrow)

	# "COMBAT 2/3" et non "COMBAT 2 SUR 3" : c'est ce que dit la maquette, et
	# c'est plus court sur un ecran de 361 points utiles.
	var title := UiTheme.make_label("COMBAT %d/%d" % [fight, total], 28, TEXT_BRIGHT)
	title.add_theme_font_override("font", UiTheme.font_black())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	column.add_child(preload("res://scenes/ui/components/ornate_divider.tscn").instantiate())

	# L'encadre des renforts, la piece maitresse de la maquette : les pieces
	# relevees sont DESSINEES, pas enumerees. Absent s'il n'y a rien a montrer -
	# un cadre vide annoncerait des renforts qui n'existent pas.
	if not recovered.is_empty():
		column.add_child(_reinforcements_box(recovered))

	column.add_child(_line("Pertes du combat",
		"Aucune" if losses.is_empty() else _format(losses), TEXT_BRIGHT))
	column.add_child(_line("Armée restante", "%d pièces" % pieces_left, TEXT_BRIGHT))

	column.add_child(_continue_button())

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


## L'ENTREE DU BANDEAU, portee depuis popup-combat-phase (410:7190).
##
## ⚠️ ELLE NE VENAIT PAS DE LA MAQUETTE avant le 23/08/2026. Elle avait ete
## calquee a la main sur l'ecran de resultat, "en plus court" - et elle etait
## deux fois trop rapide. Le releve donne une timeline de 2 s : la carte
## d'annonce apparait de 0 a 0,50 s et finit de se poser a 0,60 s, en montant
## de 40 points et en passant de 0,85 a 1.
##
## C'est l'ecran que le joueur voit le PLUS souvent apres le combat lui-meme :
## huit batailles sur dix sont des series, donc il passe par ici une a deux
## fois par bataille.
##
## On anime l'OPACITE et l'ECHELLE, jamais la position : la plaque est placee
## par un CenterContainer, et un tween de position se bat avec lui - la plaque
## se collait en haut de l'ecran. La montee de 40 points de la maquette n'est
## donc pas portable ; l'echelle 0,85 la remplace, et c'est elle qui porte
## l'idee de la carte qui surgit.
const ENTRY_FADE := 0.50
const ENTRY_POP := 0.60
const ENTRY_SCALE := 0.85
## Le blason du bas arrive apres la carte, comme dans la maquette (de 0,30 s a
## 0,70 s) : c'est ce qui evite que tout le bandeau apparaisse d'un bloc.
const ENTRY_CREST_DELAY := 0.30
const ENTRY_CREST_FADE := 0.40


func _animate(plate: Control) -> void:
	plate.modulate.a = 0.0
	plate.scale = Vector2.ONE * ENTRY_SCALE
	await get_tree().process_frame
	if not is_instance_valid(plate):
		return
	plate.pivot_offset = plate.size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(plate, "modulate:a", 1.0, ENTRY_FADE)
	tween.tween_property(plate, "scale", Vector2.ONE, ENTRY_POP) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Le bouton CONTINUER tient lieu de blason : c'est le dernier element du
	# bandeau, et le seul qui appelle un geste.
	var crest: Control = plate.find_child("ContinueButton", true, false)
	if crest != null:
		crest.modulate.a = 0.0
		tween.tween_property(crest, "modulate:a", 1.0, ENTRY_CREST_FADE) \
			.set_delay(ENTRY_CREST_DELAY)


## L'encadre des renforts (Figma reinforcements-box). Une silhouette par piece
## relevee, jusqu'a un maximum lisible, puis le compte et la phrase.
func _reinforcements_box(recovered: Dictionary) -> Control:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BOX_FILL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(column)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	# Une silhouette par piece, plafonnee : au-dela, la rangee deborde des 350
	# points de la plaque et le compte chiffre dit deja tout.
	var drawn := 0
	for type in Balance.ARMY_TYPES:
		if not recovered.has(type):
			continue
		for i in range(int(recovered[type])):
			if drawn >= MAX_GLYPHS:
				break
			var glyph := _piece_glyph(type)
			if glyph != null:
				row.add_child(glyph)
				drawn += 1

	var count := UiTheme.make_label("+%s" % _format(recovered), 14, GOLD_EDGE)
	count.add_theme_font_override("font", UiTheme.font_bold())
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(count)

	var prose := UiTheme.make_label(
		"Des troupes fraîches rejoignent vos rangs pour la prochaine confrontation.",
		12, TEXT_DIM)
	prose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(prose)
	return box


func _piece_glyph(type: String) -> TextureRect:
	var path := "res://assets/pieces/bleu/%s.png" % type
	if not ResourceLoader.exists(path):
		return null
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.custom_minimum_size = Vector2(24, 24)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Le bouton CONTINUER de la maquette. Il ne remplace pas le depart
## automatique : le bandeau part toujours seul apres series_banner_seconds, et
## le bouton ne fait que rendre visible ce qu'un "touche pour continuer" ne
## disait qu'a moitie.
func _continue_button() -> Button:
	var button := UiTheme.make_button("CONTINUER", CONTINUE_FILL, 14)
	# Nomme pour que l entree puisse le retarder (cf. _animate).
	button.name = "ContinueButton"
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_color_override("font_color", TEXT_BRIGHT)
	button.pressed.connect(_finish)
	return button


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
