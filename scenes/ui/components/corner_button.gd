extends Control
##
## LE BOUTON DE COIN, en un seul exemplaire.
##
## Avant lui, la meme chose - un bouton rond ou carre qui sort d'un ecran ou
## ouvre un panneau - existait en SIX tailles et QUATRE habillages : 24, 28,
## 34, 44, 45 et 52 points, selon l'ecran ou on l'avait ecrit. C'est ce que le
## joueur a resume par "la c'est n'importe quoi".
##
## Il n'y a plus que DEUX tailles, et chacune a sa raison :
##
##   34 - le bouton FLOTTANT, pose sur un coin d'ecran par-dessus du contenu.
##        C'est la taille de la bataille, la plus juste au pouce sans manger
##        l'ecran.
##   52 - le RETOUR en tete d'ecran, sur plaque royale. Il ouvre la lecture de
##        l'ecran, il a droit a la place. Trois ecrans sur quatre l'avaient
##        deja (preparation, codex, boutique) ; le chateau etait le seul a 44.
##
## Un Control qui ENVELOPPE sa peau plutot qu'un PanelContainer : les deux
## tailles ne se peignent pas pareil - la flottante est un StyleBoxFlat rond,
## le retour est une RoyalPlate, qui est un MarginContainer. Un seul type de
## noeud ne pouvait pas etre les deux.
##

## Bouton flottant pose sur un coin d'ecran.
const FLOATING_SIZE := 34.0
## Retour en tete d'ecran, sur plaque royale.
const BACK_SIZE := 52.0

## Espacement vertical entre deux boutons de la meme colonne.
const STACK_GAP := 8.0
## Marge au bord de l'ecran, pour une colonne de boutons flottants.
const STACK_MARGIN := Vector2(6, 12)

## ⚠️ L'enumeration s'appelle Tone et surtout PAS Variant : Variant est un type
## integre de GDScript, et le nom entrerait en collision. (Pill, dans le meme
## dossier, s'en tire parce que son enum est TOUJOURS lu "Pill.Variant".)
enum Tone {
	NIGHT,   ## bleu nuit translucide - le defaut, pose sur un decor
	GOLD,    ## plaque royale doree - le retour en tete d'ecran
	ACCENT,  ## bleu plein - une entree vers un autre ecran
	DANGER,  ## rouge sourd - quitter
}

const FILL := {
	Tone.NIGHT: Color("0a1230", 0.85),
	Tone.GOLD: Color("1e3278"),
	Tone.ACCENT: Color("3873f2"),
	Tone.DANGER: Color("2a0f14", 0.85),
}
const EDGE := {
	Tone.NIGHT: Color("ffe580", 0.8),
	Tone.GOLD: Color("ffe680"),
	Tone.ACCENT: Color("b6c0f3"),
	Tone.DANGER: Color("c65f5f", 0.9),
}
const GLYPH_COLOR := {
	Tone.NIGHT: Color("ffe580"),
	Tone.GOLD: Color("ffe580"),
	Tone.ACCENT: Color("ffe580"),
	Tone.DANGER: Color("f2dede"),
}

var _pressed: Callable = Callable()


## Bouton flottant : 34 points par defaut, coins arrondis a la moitie, donc rond.
##
## ⚠️ `side` EXISTE POUR LA BARRE DU VILLAGE, ET C'EST LA SEULE RAISON. Le
## joueur a demande des "boutons grossis" en haut ; les 34 points restent la
## valeur par defaut partout ailleurs, pour que ce composant continue de tenir
## la promesse qui l'a fait naitre - une seule taille au lieu des six d'avant.
## N'en ajouter une troisieme que sur une demande explicite, jamais par gout.
static func floating(glyph_name: String, on_press: Callable,
		tone: Tone = Tone.NIGHT, side: float = FLOATING_SIZE) -> Control:
	return _make(glyph_name, "", on_press, tone, side)


## Retour en tete d'ecran : 52 points, plaque royale.
##
## ⚠️ Prendre "arrow_left" et non "chevron_right" retourne : icon.gd connait
## les deux, et ils ne se ressemblent pas.
static func back(on_press: Callable) -> Control:
	return _make("arrow_left", "", on_press, Tone.GOLD, BACK_SIZE)


## Bouton flottant dont le glyphe est une IMAGE et non un trace.
##
## ⚠️ Prendre l'image SOURCE de Figma, jamais l'export du noeud : celui-ci
## arrive avec le fond du bouton cuit dedans, alpha entierement opaque.
static func with_texture(texture_path: String, on_press: Callable,
		tone: Tone = Tone.ACCENT) -> Control:
	return _make("", texture_path, on_press, tone, FLOATING_SIZE)


static func _make(glyph_name: String, texture_path: String, on_press: Callable,
		tone: Tone, side: float) -> Control:
	var button: Control = load("res://scenes/ui/components/corner_button.gd").new()
	# Nomme par son glyphe : sans ca les bancs impriment "@Control@23", ce qui
	# ne dit rien a qui cherche lequel des trois a casse.
	var label := glyph_name
	if label == "":
		label = texture_path.get_file().get_basename()
	button.name = "Corner_%s" % label
	button.custom_minimum_size = Vector2(side, side)
	button.size = Vector2(side, side)
	button._pressed = on_press
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var skin := _skin(tone, side)
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(skin)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.add_child(center)
	center.add_child(_glyph(glyph_name, texture_path, tone, side))

	UiTheme.ignore_mouse_recursive(skin)
	button.gui_input.connect(button._on_gui_input)
	UiTheme.press_feedback(button)
	return button


## La peau. Le retour est une RoyalPlate - c'est la brique de la V2, et trois
## ecrans sur quatre l'utilisaient deja pour ce bouton ; le flottant est un
## StyleBoxFlat rond, parce qu'une plaque a 34 points n'a plus la place de
## montrer son filet interieur.
static func _skin(tone: Tone, side: float) -> Control:
	if tone == Tone.GOLD:
		var plate := RoyalPlate.new()
		plate.border_color = EDGE[tone]
		plate.border_width = 3.5
		plate.corner_radius = 12.0
		plate.inner_outline_color = Color("ffd700", 0.25)
		plate.inner_radius = 8.0
		plate.set_padding_all(6)
		return plate

	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = FILL[tone]
	box.set_corner_radius_all(int(side * 0.5))
	box.border_color = EDGE[tone]
	box.set_border_width_all(1.5)
	box.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", box)
	return panel


static func _glyph(glyph_name: String, texture_path: String, tone: Tone,
		side: float) -> Control:
	var size := Vector2.ONE * (side * 0.42)
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var image := TextureRect.new()
		image.texture = load(texture_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = size
		return image

	var icon := Icon.new()
	icon.icon_name = glyph_name
	icon.color = GLYPH_COLOR[tone]
	icon.custom_minimum_size = size
	return icon


## Pose le bouton dans une colonne ancree au coin haut-droit de son parent.
##
## `rank` vaut 0 pour le premier, 1 pour celui d'en dessous, et ainsi de suite.
## C'est ce qui remplace les six couples de coordonnees ecrits a la main - et
## c'est aussi ce qui garantit qu'ils restent au bord sur un ecran plus large,
## la ou une position absolue les laissait au milieu.
func stack_top_right(rank: int, margin: Vector2 = STACK_MARGIN) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -(margin.x + size.x)
	offset_right = -margin.x
	offset_top = margin.y + float(rank) * (size.y + STACK_GAP)
	offset_bottom = offset_top + size.y


## Pose le bouton dans une RANGEE ancree au coin haut-droit, `rank` places a
## gauche du premier.
##
## ⚠️ Deux dispositions et non une, parce que la maquette en a deux. La
## bataille empile ses boutons VERTICALEMENT le long du bord droit - sa barre
## haute est prise par le badge de tour. Le village les met COTE A COTE dans sa
## barre haute (410:153), qui a la place. Les ramener tous a une colonne
## alignerait le code en desalignant l'ecran, ce que la regle 2 interdit.
func row_top_right(rank: int, margin: Vector2 = STACK_MARGIN) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -(margin.x + float(rank) * (size.x + STACK_GAP))
	offset_left = offset_right - size.x
	offset_top = margin.y
	offset_bottom = margin.y + size.y


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _pressed.is_valid():
			_pressed.call()
