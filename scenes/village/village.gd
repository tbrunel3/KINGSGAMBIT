extends Control
##
## VILLAGE - ecran principal : chateau, batiments, or, bouton bataille.
##
## Reproduit la maquette Figma (Figma village-avec-dame, node-id 162:4) en positions
## absolues, avec les coordonnees exactes donnees par CLAUDE.md : chaque
## batiment est un label pose directement sur le fond, pas une liste
## generique. Aucune regle de jeu ici : tout vient de GameState/Balance.
##

const MissionPopupScene := preload("res://scenes/village/mission_popup.tscn")
const DevPanelScene := preload("res://scenes/village/dev_panel.tscn")

## Coordonnees relevees sur la maquette V2 (frame village-avec-dame) : chaque
## label est colle au batiment qu'il designe sur le fond illustre.
##
## Les NOMS restent ceux du jeu : la maquette parle d'Atelier, d'Academie et
## de Chapelle, mais le joueur recrute des pions, des cavaliers et des fous.
## Regle de l'import (cf. CLAUDE.md) : le visuel vient de Figma, les regles du
## code.
const CASTLE_POS := Vector2(120, 425)
const BUILDING_POS := {
	"pion": Vector2(57, 240),        # batiment haut-gauche
	"cavalier": Vector2(235, 230),   # batiment haut-droit
	"fou": Vector2(45, 628),         # batiment bas-gauche
	"tour": Vector2(252, 619),       # batiment bas-droit
}
## Teinte de chaque label de batiment (bordure + pastille de niveau) - une
## palette propre a l'UI du Village, distincte des couleurs d'equipe utilisees
## sur la grille de bataille (cf. capture Figma 01 : chaque batiment a sa
## propre couleur d'accent, sans rapport avec Balance.unit_color()).
const BUILDING_ACCENT := {
	"pion": "66a6ff",
	"cavalier": "4dcc66",
	"fou": "b266e5",
	"tour": "e5594d",
}
## Halo du chateau et lumieres qui s'allument aux fenetres quand une Dame est
## rentree : c'est la difference entre les frames village-sans-dame et
## village-avec-dame de la maquette. Positions relevees sur celle-ci.
const CASTLE_GLOW_RECT := Rect2(106, 290, 180, 200)
const GLOW_LIGHTS := [
	{"asset": "glow_window_side.svg", "rect": Rect2(168, 375, 14, 18)},
	{"asset": "glow_window_center.svg", "rect": Rect2(186, 385, 20, 24)},
	{"asset": "glow_window_side.svg", "rect": Rect2(212, 375, 14, 18)},
	{"asset": "glow_tower.svg", "rect": Rect2(173, 345, 10, 14)},
	{"asset": "glow_tower.svg", "rect": Rect2(213, 345, 10, 14)},
	{"asset": "glow_crown.svg", "rect": Rect2(182, 305, 28, 20)},
]

## LES BATIMENTS EUX-MEMES SONT CLIQUABLES, pas seulement leurs enseignes.
##
## Demande du joueur. Les enseignes restent visees naturellement - elles
## portent le niveau et la progression - mais viser une enseigne de 24 points
## de haut quand un batiment entier est dessine juste au-dessus n'a aucun sens
## au pouce.
##
## Rectangles releves sur le rendu en 393 x 852, VOLONTAIREMENT plus larges que
## le dessin : au pouce, une cible trop juste se rate. Ils vivent sur le calque
## de decor et suivent donc l'illustration exactement comme les enseignes -
## sans quoi ils seraient decales de 34 points sur un ecran court, ce qui est
## pire que pas de zone du tout.
const BUILDING_HITBOX := {
	"pion": Rect2(28, 92, 130, 152),
	"cavalier": Rect2(238, 126, 146, 126),
	"fou": Rect2(30, 470, 130, 162),
	"tour": Rect2(226, 486, 150, 150),
}
## Le chateau a la sienne, plus grande : c'est le batiment central, et il mene
## a un ecran plein plutot qu'a un popup.
const CASTLE_HITBOX := Rect2(108, 292, 182, 140)

## LA TRANSITION VERS UN BATIMENT - zoom vers le point touche, puis voile.
##
## ⚠️ Ces quatre valeurs sont le seul endroit a changer si le prototype Figma
## rend un mouvement different. Elles ne sont copiees nulle part ailleurs.
const ZOOM_SCALE := 1.18
## ⚠️ ZOOM_SECONDS, VEIL_SECONDS et VEIL_DELAY_RATIO ont ete RETIREES d'ici.
## La duree du zoom vit maintenant dans Balance.MOTION ("village_zoom"), et le
## voile local a disparu au profit de ScreenVeil - voir _zoom_to. Le dezoom,
## lui, n'existe plus : la caserne est un ECRAN, donc le village est detruit.

const SCREEN_WIDTH := 393.0
const SCREEN_MARGIN := 8.0
const BATTLE_RECT := Rect2(102, 765, 189, 59)
## ══════════════════════════ LA BARRE DU HAUT ═══════════════════════════════
##
## Retour du joueur : "les gemmes n'apparaissent pas a cote de l'or ; a reunir
## dans une barre haute, boutons grossis, au style de l'interface, VRAIMENT
## collee en haut".
##
## Trois defauts, tous mesures sur la capture du village :
##
##  - RIEN N'ETAIT ALIGNE, et c'est de l'arithmetique. Les pastilles etaient
##    posees a y = 44, les deux boutons de coin AUSSI a 44 - mais une pastille
##    fait 26 de haut et un bouton 34 : leurs centres tombaient a 57 et a 61.
##    Poser deux hauteurs differentes au meme Y ne les aligne pas, ca les
##    decale de la moitie de leur difference.
##  - ELLE N'ETAIT PAS COLLEE EN HAUT. Les 44 points etaient une allocation
##    d'encoche ECRITE A LA MAIN, alors que `UiLayer` n'est PAS dans une zone
##    sure. Sur un appareil sans encoche - le Web, precisement la ou il teste -
##    c'etaient 44 points de vide.
##  - LES BOUTONS ETAIENT PETITS : 34 points, contre 45 pour la boutique en bas.
##
## Desormais tout se centre sur UNE seule ligne, `_top_bar_center()`, la marge
## haute vient du systeme au lieu d'etre devinee, et les boutons passent a 40.
const TOP_BAR_MIN_TOP := 10.0
const TOP_BAR_HEIGHT := 40.0
const TOP_BAR_BUTTON := 40.0
## Garde-fou : sur un appareil a tres grande encoche, la barre ne doit pas
## descendre au point de mordre sur l'ile.
const TOP_BAR_MAX_TOP := 52.0
## Fondus haut et bas de la maquette, qui detachent les pastilles et le bouton
## du decor sans assombrir toute l'ile.
const TOP_FADE_HEIGHT := 143.0
const BOTTOM_FADE_TOP := 720.0
const BOTTOM_FADE_HEIGHT := 132.0
## LE GESTE QUI OUVRE LE PANNEAU DE DEVELOPPEMENT.
##
## Plus large que haute, et calee AU-DESSUS de la barre du haut : les boutons
## de reglages et de codex commencent a y=44, une zone plus profonde leur
## volerait leurs taps.
const DEV_GESTURE_SIZE := Vector2(72, 40)
const DEV_GESTURE_HOLD := 1.2
## ⚠️ LE CODEX N'A PLUS DE RECTANGLE A LUI. Il est ancre au bord droit par le
## composant partage, comme l'engrenage. Son icone reste discrete et sans
## libelle, decision inchangee : le codex se consulte, il ne se joue pas - lui
## donner un libelle le mettrait au meme rang que MISSIONS, qui dit quoi faire
## ensuite.
## Bouton BOUTIQUE, pose A GAUCHE DE "BATAILLE" et non plus en haut a droite
## avec le codex : c'est le joueur qui l'a place la dans la maquette
## (Boutique-Button, 445:6). Le bas de l'ecran est la zone du POUCE, et la
## boutique est un geste courant - on y passe entre deux batailles.
##
## Sa pastille est bleue, pas doree : l'or est reserve a l'action principale,
## et deux boutons dores cote a cote se disputeraient le regard.
##
## Position ABSOLUE parce que le village est le dernier ecran qui n'est pas
## encore decoupe en zones ancrees (cf. CLAUDE.md, regle 4).
const SHOP_BUTTON_RECT := Rect2(40, 761, 45, 45)
## Le picto dessine par le joueur. C'est l'image SOURCE de la maquette, la
## seule detouree : l'export du noeud, lui, arrive avec le fond bleu du bouton
## cuit dedans (alpha entierement opaque - verifie).
const SHOP_ICON := "res://assets/ui/shop_icon.png"

const CoverFit := preload("res://scripts/ui/cover_fit.gd")
const CornerButton := preload("res://scenes/ui/components/corner_button.gd")

## Taille REELLE du fichier de fond, relevee sur le PNG - pas celle de la
## maquette. Son rapport (0,4745) differe de celui de la reference (0,4613), et
## c'est tout le probleme : en KEEP_ASPECT_COVERED l'illustration GROSSIT avec
## la hauteur du viewport pendant que des coordonnees calees sur 852 ne bougent
## pas. Mesure avant correction : ~34 points de derive sur un ecran court, et
## le bouton BATAILLE a 42 points du centre.
const BACKGROUND_SIZE := Vector2(864, 1821)

## La reference du projet, celle dans laquelle toutes les coordonnees Figma de
## ce fichier sont exprimees.
const DESIGN_SIZE := Vector2(393, 852)

## LE DECOR suit l'illustration, L'INTERFACE suit l'ecran.
##
## Deux calques, parce que ce sont deux choses : les etiquettes sont collees a
## des batiments PEINTS DANS l'image, alors qu'un bouton de reglages qui
## s'eloignerait du bord parce que le decor a grossi serait faux.
@onready var _decor: Control = $DecorLayer
@onready var _ui: Control = $UiLayer
## Le fond illustre : il zoome avec le decor, sinon le decor glisserait sur une
## image immobile.
@onready var _background: TextureRect = $BackgroundImage

## Une transition est en cours : elle avale les clics, sinon un double appui
## empile deux zooms.
var _zooming: bool = false

## Les noeuds poses sur le decor, avec leur coordonnee MAQUETTE d'origine.
## C'est la seule source de verite de leur position : elle est reappliquee a
## chaque redimensionnement.
var _decor_anchors: Dictionary = {}

var _popup: Control = null
var _gold_pill: Pill
var _gem_pill: Pill
var _missions_button: PanelContainer
var _missions_label: Label
var _missions_badge: PanelContainer
var _codex_button: Control
var _shop_button: Control
var _castle_label: PanelContainer
var _castle_glow: TextureRect
var _castle_glow_tween: Tween
var _castle_sub_row: HBoxContainer
var _building_labels: Dictionary = {}   # type -> {"panel":.., "sub_row":..}
var _building_buttons: Dictionary = {}  # type -> panel cliquable (cf. tools/ui_test.gd)
var _battle_button: PanelContainer
var _battle_label: Label


func _ready() -> void:
	_fit_decor_to_background()
	get_viewport().size_changed.connect(_fit_decor_to_background)

	# Avant tout le reste : premier enfant du DECOR, donc dessine DERRIERE les
	# labels de batiments.
	_build_castle_glow()
	# Puis les zones de clic, AVANT les enseignes : celles-ci restent donc
	# au-dessus et gardent leur clic a elles.
	_build_building_hitboxes()
	_build_top_bar()
	_build_castle_label()
	for type in Balance.UNIT_TYPES:
		_build_building_label(type)
	_build_battle_button()
	_build_dev_gesture()

	Game.gold_changed.connect(func(_g): _refresh())
	Game.gems_changed.connect(func(_g): _refresh())
	Game.units_changed.connect(_refresh)
	Game.buildings_changed.connect(_refresh)
	Game.progress_changed.connect(_refresh)
	Game.missions_changed.connect(_refresh)

	# LE COURRIER DU ROI. Un seul endroit lit les quatre jalons (cf.
	# Letters.deliver_pending) : c'est ce qui garantit qu'une lettre n'arrive
	# jamais par-dessus un ecran de defaite ni en pleine serie.
	#
	# `call_deferred` comme le popup d'aura : changer de scene depuis le _ready
	# de la scene courante la detruit pendant qu'elle se construit.
	var imposee := Letters.deliver_pending()
	if imposee != "":
		Router.goto_letter.call_deferred(imposee, Router.RETURN_VILLAGE)

	# L'AURA DE LA DAME, a la premiere Dame ramenee vivante.
	#
	# Au village et non au combat : c'est ici que le choix se pose - la laisser
	# tenir la cour, ou la deployer. Et c'est ici qu'on revient juste apres
	# l'avoir ramenee.
	if Game.dames_owned() > 0:
		GuidePopup.show_once.call_deferred(self, GuidePopup.DAME_AURA)

	Game.check_upgrades()
	var ticker := Timer.new()
	ticker.wait_time = 1.0
	ticker.timeout.connect(func():
		Game.check_upgrades()
		_refresh())
	add_child(ticker)
	ticker.start()

	_refresh()


# ------------------------------- CONSTRUCTION --------------------------------

## LES DEUX CALQUES, et pourquoi ce n'est pas un decoupage arbitraire.
##
## Les coordonnees de ce fichier sont relevees sur la maquette 393 x 852, et
## chaque etiquette est collee a un batiment PEINT DANS l'illustration. Or le
## fond est pose en KEEP_ASPECT_COVERED et fait 864 x 1821 : son rapport n'est
## pas celui de la reference, donc il GROSSIT avec la hauteur du viewport.
##
## Une bande de 852 points centree - ce qu'on faisait avant - laissait donc les
## etiquettes derriere leur decor : ~34 points sur un ecran court. Et le calque
## unique faisait sa largeur du viewport tout en gardant des coordonnees calees
## sur 393, ce qui mettait le bouton BATAILLE a 42 points du centre.
##
## D'ou DEUX calques : le DECOR suit l'illustration, l'INTERFACE suit l'ecran.


## Le rectangle que l'illustration occupe reellement, pour un viewport donne.
## STATIQUE : c'est ce qui la rend mesurable sans instancier l'ecran
## (cf. tools/format_test.gd).
static func decor_rect(viewport: Vector2) -> Rect2:
	return CoverFit.rect(viewport, BACKGROUND_SIZE)


## Une coordonnee de la MAQUETTE, placee la ou elle tombe reellement sur le
## decor. Elle passe par le repere de l'IMAGE, qui est son repere d'origine -
## c'est pour ca qu'elle redevient vraie sur tous les formats.
static func design_to_decor(point: Vector2, viewport: Vector2) -> Vector2:
	var in_texture := CoverFit.to_texture(point, DESIGN_SIZE, BACKGROUND_SIZE)
	return CoverFit.from_texture(in_texture, viewport, BACKGROUND_SIZE)


## Le bouton BATAILLE suit l'ECRAN, pas le decor : un bouton d'action qui
## glisse parce que l'illustration a grossi serait faux. Il est donc centre, et
## non plus pose a x=102 comme le voulait un Rect2 cale sur 393 de large - dont
## le centre tombait a 196,5 quand le viewport peut faire 478.
static func battle_center_x(viewport: Vector2) -> float:
	return viewport.x * 0.5


## Recale le calque de decor sur le fond. Appelee au demarrage et a chaque
## redimensionnement : c'est le seul endroit du fichier qui connaisse la taille
## de l'ecran.
##
## ⚠️ LE CALQUE PORTE UN RAPPORT, PAS L'ECHELLE DU FOND. Poser directement
## l'echelle du KEEP_ASPECT_COVERED (0,468 a la reference) rendrait les
## coordonnees justes mais retrecirait le TEXTE des etiquettes de moitie - une
## etiquette a une position en points ET une taille en points, et seule la
## premiere doit suivre l'image. On met donc le rapport entre l'echelle
## courante et celle de la reference : il vaut exactement 1,0 en 393x852, donc
## l'ecran de reference est rigoureusement inchange.
func _fit_decor_to_background() -> void:
	var viewport := get_viewport_rect().size
	var design_rect := decor_rect(DESIGN_SIZE)
	var design_scale := CoverFit.scale(DESIGN_SIZE, BACKGROUND_SIZE)

	var ratio := CoverFit.scale(viewport, BACKGROUND_SIZE) / design_scale

	# ⚠️ LE CALQUE NE PORTE PAS L'ECHELLE, et c'est une decision mesuree.
	#
	# Lui donner le rapport (1,22 sur un ecran court) reposait bien les
	# enseignes sur leurs batiments, mais les faisait GROSSIR avec l'image -
	# une enseigne a une position en points ET une taille en points, et seule
	# la premiere doit suivre le decor. Mesure : "Caserne des Pions" et
	# "Ecuries" se frolaient en 360x620, et le texte variait de 22 % d'un
	# telephone a l'autre. Les deux modes ont ete rendus cote a cote et le
	# joueur a tranche pour celui-ci.
	#
	# Chaque enfant est donc repose a la main, en gardant sa taille.
	_decor.scale = Vector2.ONE
	_decor.position = Vector2.ZERO
	_decor.size = viewport

	for node in _decor_anchors:
		_apply_decor_anchor(node, ratio)


## Pose un noeud sur le decor a une coordonnee de la MAQUETTE, et retient
## cette coordonnee : c'est elle la source de verite, jamais la position
## courante, qui depend du format.
func _anchor_on_decor(node: Control, design_pos: Vector2, is_artwork: bool = false) -> void:
	_decor_anchors[node] = design_pos
	node.set_meta("decor_artwork", is_artwork)
	if is_inside_tree():
		var design_scale := CoverFit.scale(DESIGN_SIZE, BACKGROUND_SIZE)
		_apply_decor_anchor(node,
			CoverFit.scale(get_viewport_rect().size, BACKGROUND_SIZE) / design_scale)


func _apply_decor_anchor(node: Control, ratio: float) -> void:
	if not is_instance_valid(node):
		return
	var design_pos: Vector2 = _decor_anchors[node]
	node.position = design_to_decor(design_pos, get_viewport_rect().size)
	# Le halo est de l'ILLUSTRATION : il doit grandir avec le chateau qu'il
	# eclaire, meme quand les enseignes, elles, gardent leur taille.
	if bool(node.get_meta("decor_artwork", false)):
		node.scale = Vector2(ratio, ratio)


## Bandeau plein (rgba(10,13,20,0.75), h46, y38) derriere les pastilles -
## cf. capture Figma 01 "Top-Bar" : sans lui les pastilles flottent seules
## sur le fond illustre plutot que de reposer sur une barre continue.
## La maquette V2 ne pose plus de bandeau plein en haut : les pastilles
## reposent sur un simple fondu sombre, qui laisse voir l'ile.
func _build_top_bar() -> void:
	# LES DEUX FONDUS SUIVENT L'ECRAN, en largeur comme en position verticale.
	#
	# Ils etaient larges de SCREEN_WIDTH (393) : sur un viewport de 478, ils
	# laissaient 85 points de decor en pleine lumiere a droite, et les pastilles
	# du bout de la barre flottaient sur l'illustration.
	#
	# Le fondu du BAS s'ancre au bas de l'ecran, pas a y=720 : il est la pour
	# detacher le bouton BATAILLE du decor, et le bouton vient lui aussi de
	# passer en ancrage bas.
	var top_fade := _fade_rect(
		Vector2.ZERO, Vector2(SCREEN_WIDTH, TOP_FADE_HEIGHT),
		Color("0a0d14", 0.65), Color("0a0d14", 0.0))
	_ui.add_child(top_fade)
	top_fade.anchor_right = 1.0
	top_fade.offset_left = 0.0
	top_fade.offset_right = 0.0

	var bottom_fade := _fade_rect(
		Vector2.ZERO, Vector2(SCREEN_WIDTH, BOTTOM_FADE_HEIGHT),
		Color("0a0d14", 0.0), Color("0a0d14", 0.95))
	_ui.add_child(bottom_fade)
	bottom_fade.anchor_right = 1.0
	bottom_fade.anchor_top = 1.0
	bottom_fade.anchor_bottom = 1.0
	bottom_fade.offset_left = 0.0
	bottom_fade.offset_right = 0.0
	bottom_fade.offset_top = -(DESIGN_SIZE.y - BOTTOM_FADE_TOP)
	bottom_fade.offset_bottom = 0.0

	var pill_y := _top_bar_center()

	_gold_pill = _place_pill(12, pill_y, "", Pill.Variant.TOPBAR)
	_gold_pill.set_data("", "", Pill.Variant.TOPBAR)
	# La piece frappee du jeu, comme la maquette - pas une pastille ronde.
	_gold_pill.set_texture(load("res://assets/ui/kg_coin.png"), 22.0)
	_gold_pill.set_bold(true)

	# LA PASTILLE DE GEMMES, et non plus celle du niveau de chateau.
	#
	# La maquette (village-avec-dame, 410:153) met les gemmes juste apres l'or,
	# et n'affiche AUCUN niveau de chateau en barre haute - il est deja ecrit
	# sous "CHÂTEAU ROYAL", au milieu de l'ecran. La pastille de niveau faisait
	# donc doublon, et elle occupait precisement la place des gemmes.
	#
	# Sans elle, la deuxieme monnaie du jeu n'existe que dans la boutique : on
	# ne peut pas savoir ce qu'on a sans aller voir.
	_gem_pill = _place_pill(122, pill_y, "", Pill.Variant.TOPBAR)
	_gem_pill.set_data("diamond", "", Pill.Variant.TOPBAR, Color("4f9ff0"))
	_gem_pill.set_text_color(Color("cfe3ff"))

	_build_missions_button(pill_y)

	# LES DEUX BOUTONS DE LA BARRE HAUTE, un seul composant pour les deux.
	#
	# Ils etaient a 28 x 28 en coordonnees absolues, (319, 44) et (353, 44) :
	# sur un viewport de 478 de large ils se retrouvaient au MILIEU de la barre
	# au lieu de son bord. Ancres a droite, ils y restent, et ils passent a 34
	# comme tous les boutons de coin du jeu.
	#
	# ⚠️ EN RANGEE, PAS EN COLONNE. La maquette du village (410:153) les met
	# cote a cote ; c'est la BATAILLE qui les empile, parce que sa barre haute
	# est prise par le badge de tour. Aligner le code en desalignant l'ecran
	# serait exactement ce que la regle 2 interdit.
	# "Boutons grossis", demande du joueur : 34 -> 40. Et leur marge haute se
	# calcule pour que leur CENTRE tombe sur la meme ligne que les pastilles.
	var marge_bouton := _top_bar_center() - TOP_BAR_BUTTON * 0.5
	var settings: Control = CornerButton.floating(
		"gear", func(): pass, CornerButton.Tone.NIGHT, TOP_BAR_BUTTON)
	_ui.add_child(settings)
	settings.row_top_right(0, Vector2(12, marge_bouton))

	_codex_button = CornerButton.floating(
		"info", _on_codex_pressed, CornerButton.Tone.NIGHT, TOP_BAR_BUTTON)
	_ui.add_child(_codex_button)
	_codex_button.row_top_right(1, Vector2(12, marge_bouton))

	# LA BOUTIQUE NE CHANGE PAS DE PLACE. Elle est en bas a gauche parce que le
	# joueur l'y a mise : le bas de l'ecran est la zone du POUCE, et on y passe
	# entre deux batailles. Elle prend seulement l'habillage commun.
	#
	# ⚠️ Elle garde aussi sa TAILLE (45, pas 34). Les deux tailles du composant
	# valent pour les boutons de COIN ; celle-ci est une action de bas d'ecran,
	# voisine de BATAILLE, et la retrecir de 45 a 34 la rendrait plus dure a
	# viser la ou le pouce tombe naturellement.
	_shop_button = CornerButton.with_texture(SHOP_ICON, _on_shop_pressed)
	_shop_button.custom_minimum_size = SHOP_BUTTON_RECT.size
	_shop_button.size = SHOP_BUTTON_RECT.size
	_ui.add_child(_shop_button)
	_shop_button.position = SHOP_BUTTON_RECT.position
	_shop_button.anchor_top = 1.0
	_shop_button.anchor_bottom = 1.0
	_shop_button.offset_left = SHOP_BUTTON_RECT.position.x
	_shop_button.offset_right = SHOP_BUTTON_RECT.position.x + SHOP_BUTTON_RECT.size.x
	# ⚠️ ELLE S'ALIGNE SUR BATAILLE, ELLE N'A PLUS SON PROPRE Y.
	#
	# Mesure avant : le centre de BATAILLE tombait a 794,5 du haut, celui de la
	# boutique a 783,5 - ONZE POINTS d'ecart, sur deux boutons cote a cote. Deux
	# Rect2 ecrits a la main a deux moments differents ne peuvent que deriver ;
	# celui-ci se CALCULE, donc il ne peut plus.
	var centre_bataille := DESIGN_SIZE.y 		- (BATTLE_RECT.position.y + BATTLE_RECT.size.y * 0.5)
	_shop_button.offset_top = -(centre_bataille + SHOP_BUTTON_RECT.size.y * 0.5)
	_shop_button.offset_bottom = _shop_button.offset_top + SHOP_BUTTON_RECT.size.y


func _on_shop_pressed() -> void:
	Router.goto_shop()


func _on_codex_pressed() -> void:
	Router.goto_codex()


## Bandeau degrade vertical, pose sur le decor.
func _fade_rect(pos: Vector2, size: Vector2, from_color: Color, to_color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([from_color, to_color])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = int(size.y)

	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.position = pos
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Bouton MISSIONS de la barre du haut. C'est le seul endroit du village qui
## dise au joueur quoi faire ensuite : il porte une pastille doree des qu'une
## recompense attend d'etre prise, sinon personne ne l'ouvrirait jamais.
func _build_missions_button(y: float) -> void:
	_missions_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.25)
	box.set_corner_radius_all(10)
	box.border_color = Color(UiTheme.GOLD, 0.3)
	box.set_border_width_all(1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	_missions_button.add_theme_stylebox_override("panel", box)
	_ui.add_child(_missions_button)
	_missions_button.position.y = y

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_missions_button.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "star"
	icon.color = UiTheme.GOLD
	icon.custom_minimum_size = Vector2(13, 13)
	row.add_child(icon)

	_missions_label = UiTheme.make_label("Missions", 14, Color.WHITE)
	# Poppins SemiBold 14, releve sur la maquette (village-avec-dame, 410:153).
	_missions_label.add_theme_font_override("font", UiTheme.font_display_medium())
	_missions_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_missions_label)

	# Pastille de notification. VOISINE du bouton, jamais son enfant : un
	# PanelContainer etire tous ses enfants a sa taille, la pastille
	# recouvrirait le libelle.
	_missions_badge = PanelContainer.new()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = UiTheme.GOLD
	badge_box.set_corner_radius_all(7)
	badge_box.content_margin_left = 5
	badge_box.content_margin_right = 5
	badge_box.content_margin_top = 1
	badge_box.content_margin_bottom = 1
	_missions_badge.add_theme_stylebox_override("panel", badge_box)
	_missions_badge.visible = false
	_ui.add_child(_missions_badge)

	var badge_label := UiTheme.make_label("", 9, Color("331f00"))
	badge_label.name = "Count"
	badge_label.add_theme_font_override("font", UiTheme.font_bold())
	badge_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_missions_badge.add_child(badge_label)

	UiTheme.ignore_mouse_recursive(row)
	UiTheme.ignore_mouse_recursive(_missions_badge)
	_missions_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_missions_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_missions_pressed()
	)


func _refresh_missions_button() -> void:
	if not is_instance_valid(_missions_button):
		return
	var claimable := Game.claimable_missions()
	_missions_badge.visible = claimable > 0
	if claimable > 0:
		var count: Label = _missions_badge.get_node("Count")
		count.text = str(claimable)
		_missions_badge.reset_size()
		# Coin haut-droit du bouton, legerement debordant.
		_missions_badge.position = _missions_button.position + Vector2(
			_missions_button.size.x - _missions_badge.size.x * 0.6,
			-_missions_badge.size.y * 0.35)


func _on_missions_pressed() -> void:
	if is_instance_valid(_popup):
		return
	_popup = MissionPopupScene.instantiate()
	# La bourse d'or lui est DONNEE : les pieces d'une mission reclamee y
	# volent, et elle vit dans cet ecran-ci, pas dans le popup.
	_popup.purse = _gold_pill
	add_child(_popup)


## LE HAUT DE LA BARRE, pris au systeme et non plus devine.
##
## Meme calcul que `SafeArea._apply` : la zone sure est en pixels d'ecran, il
## faut la ramener en unites d'interface. `UiLayer` couvre tout l'ecran, donc
## `size` est le viewport - c'est le bon diviseur.
func _top_bar_top() -> float:
	var haut := TOP_BAR_MIN_TOP
	var fenetre := DisplayServer.window_get_size()
	var sure := DisplayServer.get_display_safe_area()
	if fenetre.x > 0 and fenetre.y > 0 and sure.size.x > 0 and size.y > 0:
		haut = maxf(haut, float(sure.position.y) * (size.y / float(fenetre.y)))
	return clampf(haut, TOP_BAR_MIN_TOP, TOP_BAR_MAX_TOP)


## LA LIGNE MEDIANE DE LA BARRE. Tout s'y centre — pastilles, bouton des
## missions, boutons de coin. C'est ce qui remplace les trois Y ecrits a la
## main qui ne tombaient pas ensemble.
func _top_bar_center() -> float:
	return _top_bar_top() + TOP_BAR_HEIGHT * 0.5


## Pose un controle de facon que son CENTRE tombe sur la ligne de la barre.
func _center_on_top_bar(node: Control, x: float) -> void:
	node.position = Vector2(x, _top_bar_center() - node.size.y * 0.5)


func _place_pill(x: float, y: float, text: String, variant: Pill.Variant) -> Pill:
	var pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_ui.add_child(pill)
	pill.set_data("", text, variant)
	pill.size = pill.get_combined_minimum_size()
	pill.position = Vector2(x, y)
	return pill


## Halo dore pose sur le Chateau Royal, allume tant qu'une Dame au moins est
## rentree. C'est la recompense visible de la campagne : le Roi a retrouve sa
## Dame, son chateau rayonne a nouveau.
##
## Un degrade radial plutot qu'une image : ca ne coute aucun asset, ca se
## teinte librement, et ca reste net a n'importe quelle definition d'ecran.
func _build_castle_glow() -> void:
	# Le grand halo reste discret : c'est la lueur qui deborde du chateau.
	_castle_glow = _glow_rect(0.34, CASTLE_GLOW_RECT)
	_decor.add_child(_castle_glow)
	_anchor_on_decor(_castle_glow, CASTLE_GLOW_RECT.position, true)

	# Les lumieres des fenetres et de la couronne s'allument avec le halo :
	# c'est ce qui separe village-avec-dame de village-sans-dame dans la
	# maquette. Elles suivent l'opacite du halo, dont elles sont enfants.
	# Les lumieres des fenetres sont petites : il leur faut un coeur plus
	# franc pour se voir, et un cadre elargi pour que leur halo deborde.
	for light in GLOW_LIGHTS:
		var rect: Rect2 = light["rect"]
		var spread: Vector2 = rect.size * 1.6
		var lamp := _glow_rect(0.7, Rect2(
			rect.position - CASTLE_GLOW_RECT.position - (spread - rect.size) * 0.5, spread))
		_castle_glow.add_child(lamp)


## Un halo de la maquette, reproduit en degrade radial plutot qu'importe tel
## quel : les SVG fournis sont des ellipses #FFD94D floutees par un
## feGaussianBlur, et l'import vectoriel de Godot n'applique pas les filtres
## SVG - la lumiere ne s'allumait pas du tout. Un degrade rend exactement le
## meme resultat, sans asset a embarquer et net a toute definition.
##
## Melange additif, comme le "mix-blend-mode: screen" de la maquette : le halo
## AJOUTE de la lumiere au decor au lieu de peindre un voile jaune par-dessus.
## C'est la difference entre un chateau qui brille et un chateau sali.
func _glow_rect(core_alpha: float, rect: Rect2) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("ffd94d", core_alpha))
	gradient.set_color(1, Color("ffd94d", 0.0))
	gradient.add_point(0.45, Color("ffd94d", core_alpha * 0.45))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128

	var glow := TextureRect.new()
	glow.texture = texture

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material

	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = rect.position
	glow.size = rect.size
	return glow


## Le halo respire lentement tant qu'il y a une Dame au village, et s'eteint
## sinon. La boucle n'est relancee que si elle ne tourne pas deja : _refresh()
## repasse ici chaque seconde (cf. le ticker de _ready).
func _refresh_castle_glow() -> void:
	var dames := Game.dames_owned()
	_castle_glow.visible = dames > 0

	if dames <= 0:
		if _castle_glow_tween != null and _castle_glow_tween.is_valid():
			_castle_glow_tween.kill()
		_castle_glow_tween = null
		return

	# Chaque Dame supplementaire fait rayonner le chateau un peu plus loin,
	# sans jamais noyer la carte.
	var spread := 1.0 + minf(float(dames - 1) * 0.12, 0.36)
	_castle_glow.size = CASTLE_GLOW_RECT.size * spread
	_castle_glow.position = CASTLE_GLOW_RECT.position \
		- (CASTLE_GLOW_RECT.size * (spread - 1.0)) * 0.5

	if _castle_glow_tween != null and _castle_glow_tween.is_valid():
		return
	_castle_glow.modulate.a = 0.55
	_castle_glow_tween = create_tween().set_loops()
	_castle_glow_tween.tween_property(_castle_glow, "modulate:a", 1.0, 1.7) \
		.set_trans(Tween.TRANS_SINE)
	_castle_glow_tween.tween_property(_castle_glow, "modulate:a", 0.55, 1.7) \
		.set_trans(Tween.TRANS_SINE)


func _build_castle_label() -> void:
	_castle_label = PanelContainer.new()
	_style_building_panel(_castle_label, Color("ffd933", 1.22), 14)
	_decor.add_child(_castle_label)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_castle_label.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Poppins Bold 16, comme les autres enseignes de la maquette.
	var title := UiTheme.make_label("CHÂTEAU ROYAL", 16, Color("ffd933"))
	title.add_theme_font_override("font", UiTheme.font_display())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_castle_sub_row = HBoxContainer.new()
	_castle_sub_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_castle_sub_row)

	_anchor_on_decor(_castle_label, CASTLE_POS)
	_make_clickable(_castle_label,
		func(): _on_building_pressed(Balance.CASTLE,
			_castle_label.get_global_rect().get_center()))
	_building_buttons[Balance.CASTLE] = _castle_label
	UiTheme.ignore_mouse_recursive(margin)


func _build_building_label(type: String) -> void:
	var panel := PanelContainer.new()
	_style_building_panel(panel, Color(String(BUILDING_ACCENT[type])), 12)
	_decor.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Le nom vient de Balance, comme celui qu'affiche le popup du batiment : il
	# y avait deux tables pour la meme chose, et elles ne disaient deja plus
	# tout a fait la meme chose.
	# 16 et non 15 : la maquette met tous les noms de batiments a 16 points.
	var title := UiTheme.make_label(Balance.building_name(type), 16, Color.WHITE)
	title.add_theme_font_override("font", UiTheme.font_display())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sub_row)

	_anchor_on_decor(panel, BUILDING_POS[type])
	_building_labels[type] = {"panel": panel, "sub_row": sub_row}
	# L'enseigne zoome depuis SA position, pas depuis le centre de l'ecran :
	# c'est le meme geste que sur le batiment, vise un peu plus bas.
	_make_clickable(panel,
		func(): _on_building_pressed(type, panel.get_global_rect().get_center()))
	_building_buttons[type] = panel
	UiTheme.ignore_mouse_recursive(margin)


## Les labels de batiments sont des PanelContainer (pas des Button) pour
## coller au visuel Figma - fond sombre pose sur la carte, pas un bouton
## classique. On reproduit juste l'interaction click.
func _make_clickable(panel: PanelContainer, action: Callable) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# BATAILLE, BOUTIQUE, CODEX : ce sont des PanelContainer et non des Button
	# (il fallait y glisser une Icon vectorielle), donc rien ne leur donnait le
	# retour a l'appui. Le joueur l'a signale sur BATAILLE en premier.
	UiTheme.press_feedback(panel)
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			action.call())


## Panneau clic-able (pas un Button) : seul moyen d'inserer une Icon
## vectorielle (epee) a cote du texte.
func _build_battle_button() -> void:
	_battle_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("ffd700")
	box.set_corner_radius_all(12)
	box.border_color = Color("b8860b")
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	_battle_button.add_theme_stylebox_override("panel", box)
	_ui.add_child(_battle_button)
	# ANCRE, PAS POSITIONNE. Son Rect2 d'origine (102, 765, 189, 59) a un centre
	# a 196,5 - exactement 393/2, donc juste a la reference et faux partout
	# ailleurs : sur un viewport de 478 de large, le bouton le plus important du
	# village se retrouvait a 42 points a gauche du centre reel.
	_battle_button.anchor_left = 0.5
	_battle_button.anchor_right = 0.5
	_battle_button.anchor_top = 1.0
	_battle_button.anchor_bottom = 1.0
	_battle_button.offset_left = -BATTLE_RECT.size.x * 0.5
	_battle_button.offset_right = BATTLE_RECT.size.x * 0.5
	# Sa distance au BAS de l'ecran, et non plus son y absolu : c'est la seule
	# des deux qui veuille encore dire quelque chose quand la hauteur varie.
	_battle_button.offset_top = -(DESIGN_SIZE.y - BATTLE_RECT.position.y)
	_battle_button.offset_bottom = _battle_button.offset_top + BATTLE_RECT.size.y

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_battle_button.add_child(row)

	# PAS D'ICONE ici, et c'est la maquette qui tranche : son bouton BATAILLE
	# porte le seul mot, centre. Le jeu y mettait deux epees croisees, mais a
	# 20 points leurs gardes disparaissent et il n'en reste qu'une CROIX - le
	# bouton le plus important du village avait l'air de fermer quelque chose.

	_battle_label = UiTheme.make_label("BATAILLE", 19, Color("331f00"))
	_battle_label.add_theme_font_override("font", UiTheme.font_bold())
	_battle_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_battle_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(_battle_label)

	_make_clickable(_battle_button, _on_battle_pressed)
	UiTheme.ignore_mouse_recursive(row)


## LE PANNEAU DE DEVELOPPEMENT N'A PLUS DE BOUTON.
##
## Il n'etait dans aucune maquette, il chevauchait la rangee des reglages, et
## c'est un des ecarts que le joueur a signales.
##
## ⚠️ MAIS LE MASQUER HORS BUILD DE DEBUG NE MARCHE PAS ICI. Le joueur teste
## sur son telephone via le build web EXPORTE, donc en release :
## OS.is_debug_build() lui retirerait son seul raccourci. D'ou un geste - le
## panneau reste accessible, l'ecran redevient celui de la maquette.
##
## Le geste : UN APPUI LONG DE 1,2 s dans le coin haut-droit, sur une zone
## invisible. Elle est volontairement PLUS BASSE QUE HAUTE et s'arrete au-
## dessus de la barre du haut : une zone de 60 x 60 descendrait jusqu'a y=60 et
## volerait ses taps a l'engrenage, qui commence a y=44.
func _build_dev_gesture() -> void:
	var zone := Control.new()
	zone.name = "DevGesture"
	# ⚠️ ELLE EST PASSEE A GAUCHE, ET CE N'EST PAS UN GOUT.
	#
	# Elle etait ancree A DROITE et en MOUSE_FILTER_STOP, juste au-dessus des
	# boutons de reglages et de codex - ca tenait tant que la barre du haut
	# commencait a y=44. En la collant en haut (demande du joueur), les deux
	# boutons sont remontes DANS cette zone : elle leur volait leurs taps.
	#
	# A gauche, elle ne recouvre que la pastille d'or, qui ne se clique pas.
	# Le banc le verifie : la zone ne doit croiser AUCUN bouton de coin.
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.anchor_left = 0.0
	zone.anchor_right = 0.0
	zone.grow_horizontal = Control.GROW_DIRECTION_END
	zone.offset_left = 0.0
	zone.offset_right = DEV_GESTURE_SIZE.x
	zone.offset_top = 0.0
	zone.offset_bottom = DEV_GESTURE_SIZE.y
	_ui.add_child(zone)

	# Un Timer a un coup plutot qu'un compteur dans _process : le doigt qui se
	# leve l'arrete, et il n'y a rien a remettre a zero a la main.
	var hold := Timer.new()
	hold.one_shot = true
	hold.wait_time = DEV_GESTURE_HOLD
	hold.timeout.connect(_on_dev_pressed)
	zone.add_child(hold)

	zone.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				hold.start()
			else:
				hold.stop())
	# Le doigt qui glisse hors de la zone annule aussi : sans ca, un balayage
	# qui commence dans le coin ouvre le panneau une seconde plus tard.
	zone.mouse_exited.connect(hold.stop)


## Chaque label a la teinte de son batiment en bordure + halo - cf. captures
## Figma 01, ou seul le Chateau (or) et les quatre casernes (bleu/vert/mauve/
## rouge) different par cette seule couleur d'accent. Le halo reprend cette
## meme teinte plutot qu'une ombre noire generique - il s'estompe de lui-meme
## sur un batiment verrouille via le modulate applique dans _refresh_building().
## Enseigne de batiment de la maquette V2 : fond presque noir, fine bordure
## a la teinte du batiment, ombre portee franche. Plus de halo colore - la
## V2 est plus sobre que la V1.
func _style_building_panel(panel: PanelContainer, accent: Color, radius: int,
		shadow: float = 10.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a0d14", 0.85)
	box.set_corner_radius_all(radius)
	box.border_color = Color(accent, 0.45)
	box.set_border_width_all(1.5)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = int(shadow)
	box.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", box)


## "2 450" plutot que "2450" - separateur de milliers a la francaise, comme
## la pastille Or de la capture Figma 01.
func _format_thousands(n: int) -> String:
	return UiTheme.format_thousands(n)


# ------------------------------- RAFRAICHISSEMENT ----------------------------

## Pose la barre du haut a partir de la valeur AFFICHEE de l'or.
##
## Extrait de `_refresh` parce que le compteur la rappelle a chaque pas : la
## pastille change de largeur en passant de 930 a 1 080, et sans ca les gemmes
## et le bouton des missions resteraient a leur ancienne place pendant toute la
## montee, puis sauteraient a la fin.
func _layout_topbar() -> void:
	# ⚠️ UNE SEULE LIGNE MEDIANE POUR TOUT. Avant, chaque element avait son
	# propre Y ecrit a la main (44, 44, 44 - 2, 55,5) et aucun ne tombait au
	# meme endroit, parce qu'ils n'ont pas la meme hauteur.
	_gold_pill.set_data("", _format_thousands(maxi(_gold_affiche, 0)),
		Pill.Variant.TOPBAR)
	_gold_pill.set_bold(true)
	_gold_pill.size = _gold_pill.get_combined_minimum_size()
	_center_on_top_bar(_gold_pill, 12)

	_gem_pill.set_data("diamond", _format_thousands(Game.gems),
		Pill.Variant.TOPBAR, Color("4f9ff0"))
	_gem_pill.set_text_color(Color("cfe3ff"))
	_gem_pill.set_bold(true)
	_gem_pill.size = _gem_pill.get_combined_minimum_size()
	_center_on_top_bar(_gem_pill, _gold_pill.position.x + _gold_pill.size.x + 12)

	_missions_button.reset_size()
	_center_on_top_bar(_missions_button,
		_gem_pill.position.x + _gem_pill.size.x + 12)


## Decide si l'or se pose ou s'il monte.
func _maj_or() -> void:
	if _gold_affiche == Game.gold:
		return
	# ⚠️ PREMIERE OUVERTURE : ON POSE, ON NE FAIT PAS MONTER DEPUIS ZERO. Une
	# montee a l'arrivee au village ferait croire a un gain a chaque retour.
	if _gold_affiche < 0:
		_gold_affiche = Game.gold
		return
	if _gold_tween != null and _gold_tween.is_valid():
		_gold_tween.kill()
	var depuis := _gold_affiche
	# Un gain de vingt et un gain de cinq mille ne peuvent pas durer pareil :
	# le premier trainerait, le second defilerait trop vite pour se lire.
	var ecart := absi(Game.gold - depuis)
	var duree := Balance.motion("gold_count") \
		* clampf(float(ecart) / 500.0, 0.35, 1.0)
	_gold_tween = create_tween()
	_gold_tween.set_trans(Tween.TRANS_CUBIC)
	_gold_tween.set_ease(Tween.EASE_OUT)
	_gold_tween.tween_method(
		func(valeur: int) -> void:
			_gold_affiche = valeur
			_layout_topbar(),
		depuis, Game.gold, duree)


## L'OR MONTE, IL NE SAUTE PLUS.
##
## Retour du joueur : "l'or saute au lieu de monter". Un chiffre qui change d'un
## coup ne se lit pas comme un gain - on voit l'ancien, puis l'autre, et rien ne
## relie les deux. C'est le seul endroit du village ou une somme change sous les
## yeux du joueur, et c'etait le seul a ne rien en dire.
##
## ⚠️ LA VALEUR AFFICHEE EST UN ETAT DE L'ECRAN, PAS DU JEU. `Game.gold` est
## juste a tout instant ; c'est la pastille qui prend son temps pour le
## rattraper. Un banc qui lit `Game.gold` ne voit donc aucune difference - c'est
## exactement ce qu'on veut : l'animation ne doit rien pouvoir casser.
var _gold_affiche: int = -1
var _gold_tween: Tween = null


func _refresh() -> void:
	_maj_or()
	_layout_topbar()
	_refresh_missions_button.call_deferred()

	_refresh_castle_glow()
	_refresh_castle()
	for type in Balance.UNIT_TYPES:
		_refresh_building(type)

	if Game.is_campaign_complete():
		_battle_label.text = "REJOUER LA DERNIERE"
	else:
		_battle_label.text = "BATAILLE"


func _refresh_castle() -> void:
	# free() immediat : ce panneau se reconstruit chaque seconde, un
	# queue_free() laisserait l'ancien contenu compter dans la largeur
	# calculee juste apres (cf. le meme correctif sur building_popup.gd).
	for child in _castle_sub_row.get_children():
		_castle_sub_row.remove_child(child)
		child.free()

	var level_pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
	_castle_sub_row.add_child(level_pill)
	level_pill.set_custom("", "Nv.%d" % Game.castle_level(), Color("ffd933", 0.2), Color("ffd933"))
	level_pill.get_node("%Text").add_theme_font_size_override("font_size", 11)

	var deploy := UiTheme.make_label("Charge : %d" % Game.deploy_capacity(), 10, Color("ccd1e0"))
	deploy.autowrap_mode = TextServer.AUTOWRAP_OFF
	_castle_sub_row.add_child(deploy)

	# Les Dames retrouvees vivent ici, avec le Roi : c'est le chateau qui
	# annonce combien il en abrite et ce qu'elles rapportent.
	var dames := Game.dames_owned()
	if dames > 0:
		var crown := Icon.new()
		crown.icon_name = "crown"
		crown.color = Color("d8a0d0")
		crown.custom_minimum_size = Vector2(11, 11)
		_castle_sub_row.add_child(crown)

		var dame_label := UiTheme.make_label(
			"%d  +%d%% or" % [dames, int(Balance.DAME_GOLD_BONUS * 100.0 * dames)],
			10, Color("e5b8e0"))
		dame_label.add_theme_font_override("font", UiTheme.font_bold())
		dame_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_castle_sub_row.add_child(dame_label)


	if Game.is_upgrading(Balance.CASTLE):
		var eta := UiTheme.make_label(UiTheme.format_duration(Game.upgrade_remaining(Balance.CASTLE)),
			11, UiTheme.GOLD)
		eta.autowrap_mode = TextServer.AUTOWRAP_OFF
		_castle_sub_row.add_child(eta)

	UiTheme.ignore_mouse_recursive(_castle_sub_row)
	# Le label lui-meme se pare d'un halo plus large quand une Dame est rentree.
	_style_building_panel(_castle_label, Color("ffd933"), 14,
		26.0 if Game.dames_owned() > 0 else 14.0)

	_castle_label.size = _castle_label.get_combined_minimum_size()
	_castle_label.position.x = _clamp_x(CASTLE_POS.x, _castle_label.size.x)


func _refresh_building(type: String) -> void:
	var refs: Dictionary = _building_labels[type]
	var panel: PanelContainer = refs["panel"]
	var sub_row: HBoxContainer = refs["sub_row"]
	for child in sub_row.get_children():
		sub_row.remove_child(child)
		child.free()

	var color := Color(String(BUILDING_ACCENT[type]))

	if not Game.is_building_unlocked(type):
		panel.modulate.a = 0.6
		# La Dame n'a pas de batiment a elle : elle vit au Chateau Royal, et
		# n'y apparait que le jour ou l'une d'elles y entre.
		var hint := UiTheme.make_label(
			"Château Nv.%d requis" % Balance.unlock_castle_level(type), 11, UiTheme.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_row.add_child(hint)
	else:
		panel.modulate.a = 1.0
		var level_pill: Pill = preload("res://scenes/ui/components/pill.tscn").instantiate()
		sub_row.add_child(level_pill)
		level_pill.set_custom("", "Nv.%d" % Game.building_level(type), Color(color, 0.2), color)
		level_pill.get_node("%Text").add_theme_font_size_override("font_size", 10)

		var owned := Game.units_owned(type)
		var cap := Balance.capacity(type, Game.building_level(type))
		var bar := _progress_bar(float(owned) / float(maxi(cap, 1)), color)
		sub_row.add_child(bar)

		var count := UiTheme.make_label("%d/%d" % [owned, cap], 10, Color("bfc7d9"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		sub_row.add_child(count)

	UiTheme.ignore_mouse_recursive(sub_row)
	panel.size = panel.get_combined_minimum_size()
	# Le garde-fou s'applique dans le repere de la MAQUETTE, avant conversion :
	# c'est la que les largeurs des enseignes sont exprimees.
	_anchor_on_decor(panel, Vector2(
		_clamp_x(BUILDING_POS[type].x, panel.size.x), BUILDING_POS[type].y))


## Les positions de BUILDING_POS/CASTLE_POS sont des coins haut-gauche fixes,
## mais la largeur reelle du label depend de son contenu (progression,
## compte a rebours...) : sans ce garde-fou, les labels de la colonne de
## droite (Ecuries, Donjon des Tours) peuvent deborder de l'ecran 393px.
func _clamp_x(x: float, width: float) -> float:
	return clampf(x, SCREEN_MARGIN, SCREEN_WIDTH - width - SCREEN_MARGIN)


func _progress_bar(fraction: float, color: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(50, 6)

	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.12)
	track.position = Vector2.ZERO
	track.size = Vector2(50, 6)
	wrap.add_child(track)

	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2.ZERO
	fill.size = Vector2(50 * clampf(fraction, 0.0, 1.0), 6)
	wrap.add_child(fill)

	return wrap


# ------------------------------- ACTIONS -------------------------------------

## Une zone de clic posee sur un batiment de l'illustration.
##
## Un Control nu, invisible et sans dessin : il n'existe que pour recevoir le
## doigt. Il est marque "artwork" pour suivre l'echelle du decor - une zone a
## taille fixe couvrirait le mauvais bout d'une illustration qui a grossi.
func _build_building_hitboxes() -> void:
	var zones := {Balance.CASTLE: CASTLE_HITBOX}
	for type in BUILDING_HITBOX:
		zones[type] = BUILDING_HITBOX[type]

	for type in zones:
		var rect: Rect2 = zones[type]
		var zone := Control.new()
		zone.name = "Hitbox_%s" % type
		zone.size = rect.size
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		_decor.add_child(zone)
		_anchor_on_decor(zone, rect.position, true)

		var building := String(type)
		zone.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_on_building_pressed(building, zone.get_global_rect().get_center()))


func _on_building_pressed(type: String, from: Vector2 = Vector2.INF) -> void:
	if is_instance_valid(_popup) or _zooming:
		return
	# Sans point de depart (un clic sur l'enseigne, ou un appel de banc), le
	# zoom part du centre de l'ecran : il reste lisible, il ne vise juste rien
	# en particulier.
	var target := from
	if not target.is_finite():
		target = get_viewport_rect().size * 0.5
	_zoom_to(target, func(): _open_building(type))


## Ce qui s'ouvre au bout du zoom. Le Chateau Royal a son propre ecran - la
## salle du trone, ou l'on voit d'un coup d'oeil si la Dame est rentree - donc
## il change de scene la ou les quatre autres posent un popup.
func _open_building(type: String) -> void:
	# ⚠️ LES QUATRE CASERNES NE SONT PLUS DES MODALES. Le joueur, apres test :
	# "ce n'est pas vraiment une pop up, c'est une transition vers un nouvel
	# ecran". Chacune a desormais son propre decor (Figma 517:2), ce qu'une
	# modale posee sur le village ne pouvait pas rendre - elles partageaient
	# toutes le meme fond, defaut deja signale au chantier E.
	#
	# Le zoom du village reste : il donne son elan a la transition, et le voile
	# global prend le relais quand la scene change. Il n'y a donc plus rien a
	# "dezoomer" - le village est detruit.
	if type == Balance.CASTLE:
		Router.goto_castle()
		return
	Router.goto_building(type)


## LE ZOOM VERS LE POINT TOUCHE.
##
## Le fond et le calque de decor grossissent ensemble autour du point sous le
## doigt, qui reste donc immobile.
##
## ⚠️ IL Y AVAIT UN VOILE NOIR ICI, ET C'ETAIT LE BUG DU POPUP EN DOUBLE.
## L'ancienne version noircissait l'ecran sur la fin du zoom, ouvrait le popup
## derriere, puis relevait le voile en 0,22 s - pendant que le popup, lui,
## entrait en 0,45 s (Modal.ENTRY_DURATION). Le voile avait disparu quand le
## popup n'etait qu'a moitie la : on le voyait surgir A TRAVERS le voile, puis
## continuer d'apparaitre. Deux fondus concurrents a deux vitesses, ce que le
## joueur decrivait comme "on le voit apparaitre deux fois".
##
## Le zoom ne voile donc plus rien : il zoome, et le popup joue SA propre
## entree. Une seule apparition. Le changement d'ecran, lui, est voile par
## ScreenVeil, qui survit a la scene - voir Router._change.
##
## ⚠️ L'INTERFACE NE ZOOME PAS. La barre haute et le bouton BATAILLE suivent
## l'ecran, pas le decor - les faire glisser avec la camera les detacherait du
## bord auquel ils sont ancres.
func _zoom_to(point: Vector2, then: Callable) -> void:
	_zooming = true
	for node in [_background, _decor]:
		node.pivot_offset = point - node.position

	var tween := create_tween().set_parallel(true)
	for node in [_background, _decor]:
		tween.tween_property(node, "scale", Vector2.ONE * ZOOM_SCALE,
				Balance.motion("village_zoom")) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished
	then.call()
	_zooming = false

func _on_battle_pressed() -> void:
	Router.goto_campaign()


func _on_dev_pressed() -> void:
	if is_instance_valid(_popup):
		return
	_popup = DevPanelScene.instantiate()
	add_child(_popup)
