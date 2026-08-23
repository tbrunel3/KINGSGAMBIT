class_name UiTheme
##
## UI THEME - habillage entierement centralise ici.
##
## Phase 2 : palette et polices tirees de CLAUDE.md (handoff Figma). Aucune
## couleur ne doit etre ecrite ailleurs que dans ce fichier.
##

const BG := Color("0f111a")
const PANEL := Color("161926")
const PANEL_LIGHT := Color("262c3f")
const BORDER := Color("3d4f6b")
const TEXT := Color("e6ecf5")
const TEXT_DIM := Color("8fa0b8")
const GOLD := Color("ffd11a")          ## accent dore vif (bouton primaire)
const GOLD_TEXT := Color("331f00")     ## texte fonce lisible sur fond dore
const GOLD_BUTTON := Color("c59b27")   ## bouton or secondaire (ameliorer, preparer)
const ACCENT := Color("268cd9")        ## accent joueur (bouton bleu, ex. AUTO)
const DANGER := Color("ff3b30")   ## rouge vif (Enemies-Card, modale Defaite) - Phase 2
const SUCCESS := Color("4cd964")  ## vert vif (Progression, Portee) - Phase 2
const ENEMY := Color("b5514f")

const RADIUS := 10
const PAD := 12

## POLICES
##
## Inter est livree en fichier VARIABLE : un seul .ttf porte toutes les
## graisses, de Thin a Black. Regulier et gras sont donc deux FontVariation
## du meme fichier plutot que deux fichiers - c'est ce que recommande Godot 4,
## et ca evite d'embarquer huit .ttf pour deux graisses utilisees.
##
## Comic Relief ne sert qu'aux repliques du Roi (cf. la maquette : c'est la
## seule voix du jeu, elle a droit a sa propre ecriture).
##
## Tout est optionnel : si les fichiers manquent, on retombe sur la police de
## secours de Godot plutot que de planter.
const INTER_PATH := "res://assets/fonts/Inter.ttf"
const DIALOGUE_PATH := "res://assets/fonts/ComicRelief-Regular.ttf"
## POPPINS : l'ecriture d'enseigne, reservee aux NOMS DE LIEUX - les labels de
## batiments du village, le bandeau du Chateau Royal, la pastille MISSIONS.
## Partout ailleurs c'est Inter.
##
## Elle REMPLACE Jaro, qui tenait ce role. Ce n'est pas un changement de gout :
## le relevé de la bibliotheque Figma (page MAINPROJECT) donne ces quatorze
## libelles en Poppins Bold 16 et SemiBold 14, et le manuel dit que la maquette
## apporte l'apparence. Le relevé precedent, qui concluait "tout le fichier est
## en Inter, il n'y a rien a faire", portait sur les ANCIENNES pages et a vieilli.
##
## Poids, mesure avant de decider comme le veut la regle du projet :
## SemiBold 150 Ko + Bold 151 Ko = 302 Ko, soit l'ordre de grandeur de Lora
## (212 Ko pour deux usages). Sans rapport avec Jua, retiree a 2,1 Mo pour un
## seul mot - chiffre reverifie a cette occasion, il est exact.
##
## Jaro.ttf reste dans le depot mais n'est plus reference nulle part.
const DISPLAY_PATH := "res://assets/fonts/Poppins-Bold.ttf"
## La graisse moyenne de la meme famille, pour les pastilles de navigation.
const DISPLAY_MEDIUM_PATH := "res://assets/fonts/Poppins-SemiBold.ttf"
## Lora : la serif des bandeaux de titre (Chateau Royal). Variable elle aussi.
const TITLE_PATH := "res://assets/fonts/Lora.ttf"

const WEIGHT_REGULAR := 400
const WEIGHT_BOLD := 700
## Inter Extra Bold, la graisse des chiffres graves : cachets de la carte de
## campagne, titres de section de la planche de composants.
const WEIGHT_BLACK := 800

static var _font: Font = null
static var _font_bold: Font = null
static var _font_black: Font = null
static var _font_dialogue: Font = null
static var _font_display: Font = null
static var _font_display_medium: Font = null
static var _font_title: Font = null


static func font() -> Font:
	if _font == null:
		_font = _inter_at_weight(WEIGHT_REGULAR)
	return _font


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = _inter_at_weight(WEIGHT_BOLD)
	return _font_bold


static func font_black() -> Font:
	if _font_black == null:
		_font_black = _inter_at_weight(WEIGHT_BLACK)
	return _font_black


## Police des dialogues du Roi. Retombe sur Inter si Comic Relief manque.
static func font_dialogue() -> Font:
	if _font_dialogue == null:
		if ResourceLoader.exists(DIALOGUE_PATH):
			_font_dialogue = load(DIALOGUE_PATH)
		else:
			_font_dialogue = font()
	return _font_dialogue


## Police d'enseigne des batiments. Retombe sur Inter gras si elle manque.
static func font_display() -> Font:
	if _font_display == null:
		if ResourceLoader.exists(DISPLAY_PATH):
			_font_display = load(DISPLAY_PATH)
		else:
			_font_display = font_bold()
	return _font_display


## La meme, en graisse moyenne : les pastilles de navigation du village.
static func font_display_medium() -> Font:
	if _font_display_medium == null:
		if ResourceLoader.exists(DISPLAY_MEDIUM_PATH):
			_font_display_medium = load(DISPLAY_MEDIUM_PATH)
		else:
			_font_display_medium = font_display()
	return _font_display_medium


## Serif des bandeaux de titre. Retombe sur Inter gras si Lora manque.
static func font_title() -> Font:
	if _font_title == null:
		if ResourceLoader.exists(TITLE_PATH):
			var variation := FontVariation.new()
			variation.base_font = load(TITLE_PATH)
			variation.variation_opentype = {"wght": WEIGHT_BOLD}
			_font_title = variation
		else:
			_font_title = font_bold()
	return _font_title


static func _inter_at_weight(weight: int) -> Font:
	if not ResourceLoader.exists(INTER_PATH):
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = load(INTER_PATH)
	variation.variation_opentype = {"wght": weight}
	return variation


static func panel_box(color: Color = PANEL, border: Color = BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(RADIUS)
	box.set_content_margin_all(PAD)
	return box


static func button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(RADIUS)
	box.set_content_margin_all(PAD)
	return box


## Applique le style de bouton par defaut. `color` = teinte au repos.
##
## Sur un fond dore vif (bouton primaire), le texte clair standard devient
## illisible : on bascule automatiquement sur GOLD_TEXT, comme specifie pour
## le bouton BATAILLE.
static func style_button(button: Button, color: Color = PANEL_LIGHT) -> void:
	button.add_theme_stylebox_override("normal", button_box(color))
	button.add_theme_stylebox_override("hover", button_box(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", button_box(color.darkened(0.18)))
	button.add_theme_stylebox_override("focus", button_box(color))
	button.add_theme_stylebox_override("disabled", button_box(color.darkened(0.45)))
	var font_color := GOLD_TEXT if color == GOLD else TEXT
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)


static func style_panel(panel: PanelContainer, color: Color = PANEL) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(color))


## Cree un label deja stylise, pour eviter cinq lignes repetees partout.
##
## Le retour a la ligne automatique est actif par defaut : sur un ecran de 393
## points, un label d'une seule ligne un peu long impose sa largeur a tout son
## conteneur et fait deborder l'ecran entier.
static func make_label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Libelle d'or grave de la V2 (plaques de titre, montants, boutons d'action).
##
## La maquette remplit ces mots d'un degrade #ffe680 -> #ffd700 -> #c8960c :
## Godot ne sait pas peindre un Label en degrade sans passer par un shader
## par glyphe, dont le rendu depend de la hauteur de chaque lettre. On garde
## donc l'or median a plat, avec l'ombre portee de la maquette - a ces corps
## (9 a 19 points), la difference ne se voit pas, et le relief vient de
## l'ombre bien plus que du degrade.
static func gold_label(text: String, size: int) -> Label:
	var label := make_label(text, size, Color("ffd700"))
	label.add_theme_font_override("font", font_black())
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


static func make_button(text: String, color: Color = PANEL_LIGHT, font_size: int = 16) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	style_button(button, color)
	return button


## Ligne "libelle a gauche / valeur a droite" pour les cartes de stats (popups
## de batiment, modales de resultat). Autowrap desactive : ces lignes tiennent
## toujours sur une seule ligne, et le wrap casse le layout dans un HBox etroit.
static func stat_row(label_text: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := make_label(label_text, 14, TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if value is Label:
		(value as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	return row


## Rend un sous-arbre transparent a la souris.
##
## Un Control a mouse_filter STOP (le defaut) par-dessus un parent cliquable
## intercepte le clic avant qu'il n'atteigne le gui_input du parent : chaque
## composant "panneau + gui_input" (chip de selection, pastille de campagne,
## label de batiment...) doit donc neutraliser tout son contenu decoratif, ou
## le joueur ne peut cliquer que sur les quelques pixels de marge non couverts.
static func ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse_recursive(child)


## Formate une duree en secondes pour un compte a rebours (1h 05m / 3m 20s).
## "15 530" plutot que "15530". Un montant a cinq chiffres sans separateur se
## dechiffre au lieu de se lire, et la campagne en verse jusqu'a 15 000 d'un
## coup sur la derniere serie.
static func format_thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return ("-" if n < 0 else "") + out


static func format_duration(seconds: int) -> String:
	if seconds <= 0:
		return "terminé"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, s]
	return "%ds" % s


## Duree COMPACTE, pour les libelles de la boutique et les comptes a rebours
## des coffres gratuits : "15 min", "1 h", "2 h 14".
##
## Distincte de format_duration ci-dessus, qui rend "15m 00s" - juste pour un
## chrono d'amelioration qui defile sous les yeux du joueur, illisible sur une
## etiquette de carte large de 84 points.
static func format_span(seconds: int) -> String:
	if seconds <= 0:
		return "prêt"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h > 0:
		return "%d h %02d" % [h, m] if m > 0 else "%d h" % h
	if m > 0:
		return "%d min" % m
	return "%d s" % seconds
