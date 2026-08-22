extends Control
##
## CONFIRMER UNE AMELIORATION - la modale que la maquette dessinait et que le
## jeu n'avait pas (Figma confirm-upgrade-modal, node 103:15).
##
## Le jeu lancait l'amelioration au premier contact : l'or partait et un compte
## a rebours de trente secondes a quatre heures demarrait, sans que rien ne soit
## demande. C'est la seule action du village qui engage a la fois une somme ET
## du temps reel, et c'etait la seule sans confirmation.
##
## Elle montre ce qu'on echange : le batiment, le niveau qu'il quitte et celui
## qu'il prend, le prix, et l'attente.
##
## Usage :
##   var modal := ConfirmUpgradeScene.instantiate()
##   add_child(modal)
##   modal.open(Balance.PION)
##

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")
const CardScene := preload("res://scenes/ui/components/card.tscn")

## Emis quand le joueur confirme. Le parent lance l'amelioration : cette scene
## ne touche pas a l'etat du jeu, elle pose la question.
signal confirmed

var _type: String = ""
var _modal: Modal = null


func open(type: String) -> void:
	_type = type
	_modal = ModalScene.instantiate()
	add_child(_modal)
	_modal.closed.connect(queue_free)
	# Titre laisse vide : l'en-tete est construit ici, sur deux lignes.
	_modal.open("", Modal.Context.GOLD)
	_build(_modal.body)


func _build(body: VBoxContainer) -> void:
	body.add_child(_header())
	body.add_child(DividerScene.instantiate())
	body.add_child(_levels_card())
	body.add_child(_info_row("Coût requis", "coin",
		"%d Or" % _cost(), UiTheme.GOLD))
	body.add_child(_info_row("Temps estimé", "clock",
		UiTheme.format_duration(_seconds()), Color("f0f3f8")))
	body.add_child(_buttons())


func _level() -> int:
	return Game.castle_level() if _type == Balance.CASTLE else Game.building_level(_type)


func _cost() -> int:
	return Balance.upgrade_cost(_type, _level())


func _seconds() -> int:
	return Balance.upgrade_seconds(_type, _level())


## Le titre, seul.
##
## La maquette lui adjoint un sous-titre, "CONSTRUCTION DE SECURITE", qui ne
## veut rien dire ici - c'est du texte de remplissage. La regle du projet
## tranche : quand un libelle de maquette annonce autre chose que le jeu, c'est
## le libelle qu'on corrige. Le nom du batiment, lui, est deja dans la carte
## juste en dessous, exactement comme dans la maquette.
##
## 15 points et non 17 : a 17, "CONFIRMER L'AMELIORATION" passait sous la croix
## de fermeture.
func _header() -> Label:
	var title := UiTheme.make_label("CONFIRMER L'AMÉLIORATION", 15, Color("f0f3f8"))
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	return title


## Le niveau qu'on quitte, la fleche, le niveau qu'on prend. C'est le coeur de
## la modale : l'ancien en gris, le nouveau en or.
func _levels_card() -> PanelContainer:
	var card: PanelContainer = CardScene.instantiate()
	var card_body: VBoxContainer = card.get_node("%Body")

	# Le nom du batiment coiffe la carte, comme dans la maquette : c'est la
	# derniere chose que le joueur relit avant de payer.
	var name_label := UiTheme.make_label(
		Balance.building_name(_type).to_upper(), 14, UiTheme.GOLD)
	name_label.add_theme_font_override("font", UiTheme.font_bold())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	card_body.add_child(name_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)

	row.add_child(_level_pill("Niveau %d" % _level(), Color("2a2f45"), Color("a0aabf")))

	var arrow := UiTheme.make_label("→", 18, UiTheme.GOLD)
	arrow.add_theme_font_override("font", UiTheme.font_bold())
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(arrow)

	row.add_child(_level_pill("Niveau %d" % (_level() + 1), UiTheme.GOLD, Color("331f00")))

	card_body.add_child(row)
	return card


func _level_pill(text: String, bg: Color, fg: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var label := UiTheme.make_label(text, 13, fg)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(label)
	return pill


## "Coût requis  ...  800 Or" : libelle a gauche, valeur et son glyphe a droite.
func _info_row(label_text: String, icon_name: String, value_text: String,
		value_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1f2e")
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	panel.add_child(row)

	var label := UiTheme.make_label(label_text, 13, Color("a0aabf"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)

	var value := HBoxContainer.new()
	value.add_theme_constant_override("separation", 6)
	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = value_color
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_child(icon)
	var amount := UiTheme.make_label(value_text, 14, value_color)
	amount.add_theme_font_override("font", UiTheme.font_bold())
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.add_child(amount)
	row.add_child(value)
	return panel


func _buttons() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_button("ANNULER", Color("2a2f45"), Color("ccd1e0"),
		func(): _modal.close()))
	row.add_child(_button("CONFIRMER", UiTheme.GOLD, Color("331f00"),
		func():
			confirmed.emit()
			_modal.close()))
	return row


## Panneau clic-able plutot qu'un Button, comme les autres actions du village
## (cf. building_popup._action_row) : meme habillage, meme comportement.
func _button(text: String, bg: Color, fg: Color, on_press: Callable) -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(10)
	box.content_margin_top = 13
	box.content_margin_bottom = 13
	button.add_theme_stylebox_override("panel", box)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UiTheme.make_label(text, 13, fg)
	label.add_theme_font_override("font", UiTheme.font_black())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())
	return button
