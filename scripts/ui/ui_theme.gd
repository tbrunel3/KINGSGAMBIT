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
const DANGER := Color("c65f5f")
const SUCCESS := Color("339940")
const ENEMY := Color("b5514f")

const RADIUS := 10
const PAD := 12

## Police Inter, chargee depuis assets/fonts si presente ; sinon la police de
## secours de Godot (evite de planter si les fichiers n'ont pas encore ete
## ajoutes au projet).
static var _font: FontFile = null
static var _font_bold: FontFile = null

static func font() -> Font:
	if _font == null and ResourceLoader.exists("res://assets/fonts/Inter-Regular.ttf"):
		_font = load("res://assets/fonts/Inter-Regular.ttf")
	return _font if _font != null else ThemeDB.fallback_font


static func font_bold() -> Font:
	if _font_bold == null and ResourceLoader.exists("res://assets/fonts/Inter-Bold.ttf"):
		_font_bold = load("res://assets/fonts/Inter-Bold.ttf")
	return _font_bold if _font_bold != null else ThemeDB.fallback_font


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


static func make_button(text: String, color: Color = PANEL_LIGHT, font_size: int = 16) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	style_button(button, color)
	return button


## Formate une duree en secondes pour un compte a rebours (1h 05m / 3m 20s).
static func format_duration(seconds: int) -> String:
	if seconds <= 0:
		return "termine"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, s]
	return "%ds" % s
