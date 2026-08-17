class_name UiTheme
##
## UI THEME - habillage temporaire, entierement centralise ici.
##
## Phase 1 : formes simples, palette sobre, texte lisible.
## Phase 2 : ce fichier est le seul a remplacer pour brancher la direction
## artistique definitive. Aucune couleur ne doit etre ecrite ailleurs.
##

const BG := Color("141b28")
const PANEL := Color("1e293b")
const PANEL_LIGHT := Color("2c3b52")
const BORDER := Color("3d4f6b")
const TEXT := Color("e6ecf5")
const TEXT_DIM := Color("8fa0b8")
const GOLD := Color("e8c15a")
const ACCENT := Color("4f86c6")
const DANGER := Color("c65f5f")
const SUCCESS := Color("5fb37a")
const ENEMY := Color("b5514f")

const RADIUS := 10
const PAD := 12


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
static func style_button(button: Button, color: Color = PANEL_LIGHT) -> void:
	button.add_theme_stylebox_override("normal", button_box(color))
	button.add_theme_stylebox_override("hover", button_box(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", button_box(color.darkened(0.18)))
	button.add_theme_stylebox_override("focus", button_box(color))
	button.add_theme_stylebox_override("disabled", button_box(color.darkened(0.45)))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)


static func style_panel(panel: PanelContainer, color: Color = PANEL) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(color))


## Cree un label deja stylise, pour eviter cinq lignes repetees partout.
static func make_label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
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
