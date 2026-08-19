extends Control
##
## FICHE DES COMPOSANTS - reproduit 12_Composants pour verification visuelle.
##
## Instancie chaque composant reutilisable (boutons via variations de theme,
## Modal/Card/Pill/OrnateDivider/SelectionChip) afin de comparer le rendu a
## assets/screens/12-composants.png. Outil de developpement, pas un ecran du
## jeu.
##
## Lancement :
##   godot --headless --path . scenes/ui/ui_kit_showcase.tscn
##

const MODAL_SCENE := preload("res://scenes/ui/components/modal.tscn")
const CARD_SCENE := preload("res://scenes/ui/components/card.tscn")
const PILL_SCENE := preload("res://scenes/ui/components/pill.tscn")
const DIVIDER_SCENE := preload("res://scenes/ui/components/ornate_divider.tscn")
const CHIP_SCENE := preload("res://scenes/ui/components/selection_chip.tscn")

const CHIP_PIECES := [
	{"type": "pion", "name": "Pion", "count": 8},
	{"type": "cavalier", "name": "Cavalier", "count": 2},
	{"type": "fou", "name": "Fou", "count": 2},
	{"type": "tour", "name": "Tour", "count": 2},
	{"type": "dame", "name": "Dame", "count": 0},
	{"type": "roi", "name": "Roi", "count": 1},
]

@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	_add_title()
	_add_section("BOUTONS & COMMANDES")
	_add_buttons()
	_add_section("BADGES & STATUTS")
	_add_badges()
	_add_section("CHIPS DE SELECTION")
	_add_chips()
	_add_section("EXEMPLE DE CARTE")
	_add_card()
	_add_section("MODALE")
	_add_modal_trigger()


func _add_title() -> void:
	var title := UiTheme.make_label("KING'S GAMBIT — COMPOSANTS UI", 24, UiTheme.GOLD)
	title.add_theme_font_override("font", UiTheme.font_bold())
	_content.add_child(title)
	_content.add_child(UiTheme.make_label(
		"Fiche technique des composants reutilisables (theme + scenes ui/components).",
		12, UiTheme.TEXT_DIM))


func _add_section(text: String) -> void:
	_content.add_child(UiTheme.make_label(text, 16, UiTheme.GOLD))


func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_content.add_child(flow)
	return flow


# ------------------------------- BOUTONS --------------------------------------

func _add_buttons() -> void:
	var flow := _flow()
	flow.add_child(_button("BATAILLE", "PrimaryButton"))
	flow.add_child(_button("AMÉLIORER", "GoldButton"))
	flow.add_child(_button("AUTO", "AccentButton"))
	flow.add_child(_button("RÉESSAYER", "SecondaryButton"))
	flow.add_child(_button("ABANDONNER", "DangerButton"))
	flow.add_child(_button("VILLAGE", "DiscreetButton"))
	var disabled := _button("DÉSACTIVÉ", "SecondaryButton")
	disabled.disabled = true
	flow.add_child(disabled)


func _button(text: String, variation: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	return button


# ------------------------------- BADGES ----------------------------------------

func _add_badges() -> void:
	var flow := _flow()
	flow.add_child(_pill("lock", "BLOQUÉ", Pill.Variant.DEFAULT))
	flow.add_child(_pill("wrench", "AMÉLIORATION", Pill.Variant.OUTLINE))
	flow.add_child(_pill("", "NV.4", Pill.Variant.INFO))
	flow.add_child(_pill("star", "PROMOTION", Pill.Variant.GOLD))


func _pill(icon: String, text: String, variant: Pill.Variant) -> Pill:
	var pill: Pill = PILL_SCENE.instantiate()
	pill.set_data.call_deferred(icon, text, variant)
	return pill


# ------------------------------- CHIPS -----------------------------------------

func _add_chips() -> void:
	var flow := _flow()
	for data in CHIP_PIECES:
		var chip: SelectionChip = CHIP_SCENE.instantiate()
		flow.add_child(chip)
		var path := "res://assets/pieces/bleu/%s.png" % String(data["type"])
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		chip.set_piece.call_deferred(texture, String(data["name"]), int(data["count"]))
		if data["type"] == "pion":
			chip.selected = true


# ------------------------------- CARTE ------------------------------------------

func _add_card() -> void:
	var card: PanelContainer = CARD_SCENE.instantiate()
	var body: VBoxContainer = card.get_node("%Body")
	body.add_child(UiTheme.make_label("TOUR ÉCLAIREUR", 15, UiTheme.GOLD))
	body.add_child(UiTheme.make_label("Amélioration possible au niveau 4.", 12, UiTheme.TEXT_DIM))
	body.add_child(DIVIDER_SCENE.instantiate())
	body.add_child(UiTheme.make_label("Coût : 450 or", 13, UiTheme.TEXT))
	_content.add_child(card)


# ------------------------------- MODALE -----------------------------------------

func _add_modal_trigger() -> void:
	var open_button := _button("Ouvrir la modale (demo)", "PrimaryButton")
	open_button.pressed.connect(_open_demo_modal)
	_content.add_child(open_button)


func _open_demo_modal() -> void:
	var modal: Modal = MODAL_SCENE.instantiate()
	add_child(modal)
	modal.open("VICTOIRE", Modal.Context.GOLD)
	modal.body.add_child(UiTheme.make_label("Bataille remportée en 4 tours.", 13, UiTheme.TEXT_DIM))
	modal.body.add_child(DIVIDER_SCENE.instantiate())
	var card: PanelContainer = CARD_SCENE.instantiate()
	card.get_node("%Body").add_child(UiTheme.make_label("Or gagné : 260", 14, UiTheme.GOLD))
	modal.body.add_child(card)
