extends Control
class_name ConfirmLeave
##
## ABANDONNER LA SERIE - la seule question que le jeu pose avant de detruire
## quelque chose que le joueur a gagne.
##
## ⚠️ POURQUOI CET AVERTISSEMENT EXISTE. La regle vient du joueur : repartir au
## royaume en pleine serie l'abandonne. Sans un mot avant, il perdrait deux
## combats gagnes en touchant un bouton qui, jusque-la, ne coutait rien - et
## perdre une serie par megarde serait pire que ce que la regle cherche a
## empecher.
##
## Il dit ce qu'on perd, chiffre depuis la serie en cours : aucun nombre n'est
## ecrit dans le texte, meme doctrine que GuidePopup et le codex.
##
## ⚠️ ET IL NE S'AFFICHE PAS DANS LES BANCS. Router.ask_before_leaving passe a
## false : un banc qui navigue vers le village abandonne la serie sans qu'une
## modale l'attende indefiniment. La REGLE s'applique quand meme - c'est le
## comportement reel, et un banc doit mesurer le comportement reel.
##

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")

var _modal: Modal
var _on_confirm: Callable
var _confirmed: bool = false


## Pose la question par-dessus `parent`. `on_confirm` n'est appele que si le
## joueur accepte de perdre la serie.
static func ask(parent: Node, run: CampaignRun, on_confirm: Callable) -> void:
	if parent == null or not parent.is_inside_tree() or run == null:
		on_confirm.call()
		return
	var popup := ConfirmLeave.new()
	parent.add_child(popup)
	popup._build(run, on_confirm)


func _build(run: CampaignRun, on_confirm: Callable) -> void:
	_on_confirm = on_confirm
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_modal = ModalScene.instantiate()
	add_child(_modal)
	# Fermer la modale sans repondre, c'est REFUSER : on ne detruit rien sur un
	# geste ambigu.
	_modal.closed.connect(func():
		if not _confirmed:
			queue_free())

	_modal.open("ABANDONNER LA SÉRIE ?", Modal.Context.NEUTRAL, "crown_broken")
	var body := _modal.body

	body.add_child(_paragraph(
		"Repartir au royaume met fin à la série en cours. Tu ne pourras pas "
		+ "reprendre là où tu t'es arrêté."))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("Où tu en es",
		"Combat %d sur %d." % [run.fight, run.total]))

	if run.reward > 0:
		body.add_child(_rule("Ce que tu perds",
			"%d or promis par les combats déjà remportés." % run.reward))

	if not run.losses.is_empty():
		body.add_child(_rule("Ce qui est déjà tombé",
			"Tes pertes restent perdues : elles ont eu lieu."))

	if run.dames_made > 0:
		body.add_child(_rule("Ce que tu gardes",
			"Les Dames faites pendant la série rentrent au Château Royal."))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stay := UiTheme.make_button("RESTER", UiTheme.GOLD_BUTTON, 15)
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stay.pressed.connect(func(): _modal.close())
	row.add_child(stay)

	var leave := UiTheme.make_button("ABANDONNER", UiTheme.GOLD_BUTTON, 15)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.add_theme_color_override("font_color", Color("c65f5f"))
	leave.pressed.connect(func():
		_confirmed = true
		var go := _on_confirm
		queue_free()
		go.call())
	row.add_child(leave)

	body.add_child(row)


func _paragraph(text: String) -> Label:
	var label := UiTheme.make_label(text, 12, Color("ccd1e0"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _rule(title_text: String, body_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	var title := UiTheme.gold_label(title_text, 13)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var text := UiTheme.make_label(body_text, 11, Color("ccd1e0"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	return column
