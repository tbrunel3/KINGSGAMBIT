extends Control
##
## AVERTISSEMENT DE SERIE - le popup qui explique, UNE FOIS, ce qu'est une
## serie de combats.
##
## Le joueur decouvre a la deuxieme bataille qu'elle ne se gagne plus en un
## combat. Sans un mot d'explication, ce qu'il constate c'est : "j'ai gagne et
## on me renvoie au placement", puis "mes pieces mortes ne sont pas revenues".
## Les deux ressemblent a des bugs alors que ce sont LES regles qui font la
## difficulte du jeu.
##
## Aucune valeur ecrite ici : le nombre de combats vient de la bataille, le
## poids releve vient de Balance. A `fights: 1` partout, ce popup ne s'ouvre
## jamais.
##

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")

signal closed

var _modal: Modal


## `fights` est le nombre de combats de la serie (cf. Balance.battle_fights).
func setup(fights: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_modal = ModalScene.instantiate()
	add_child(_modal)
	_modal.closed.connect(func():
		closed.emit()
		queue_free())
	_modal.open("UNE SÉRIE DE %d COMBATS" % fights, Modal.Context.GOLD, "sword")

	var body: VBoxContainer = _modal.body
	body.add_child(_paragraph(
		"Cette bataille ne se gagne pas en un combat mais en %d, enchaînés sans retour au village."
			% fights))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("Tes pertes restent perdues",
		"Une pièce capturée ne revient pas au combat suivant. L'ennemi, lui, se relève au complet à chaque fois — c'est l'usure qui fait la difficulté, pas le nombre."))

	var weight := int(Balance.RUN_REINFORCE_WEIGHT)
	if weight > 0:
		body.add_child(_rule("Quelques blessés se relèvent",
			"Entre deux combats, %d de poids se relève parmi tes pertes, les moins chères d'abord : des pions se relèvent, jamais une tour."
				% weight))

	body.add_child(_rule("L'or ne tombe qu'à la fin",
		"Chaque combat gagné promet sa part, mais rien n'est versé avant le dernier. Un seul combat perdu fait tomber la série entière."))

	var got_it := UiTheme.make_button("J'AI COMPRIS", UiTheme.GOLD_BUTTON, 15)
	got_it.pressed.connect(func(): _modal.close())
	body.add_child(got_it)


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

	var body := UiTheme.make_label(body_text, 11, Color("ccd1e0"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	return column
