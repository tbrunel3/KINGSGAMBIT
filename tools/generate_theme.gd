extends Node
##
## GENERATEUR DE THEME - construit kings_gambit_theme.tres a partir de UiTheme.
##
## UiTheme.gd reste l'unique source de verite pour les couleurs (voir son
## en-tete) : ce script traduit ses constantes en un Theme Godot exploitable
## via theme_type_variation dans les scenes, sans dupliquer la palette.
##
## Lancement :
##   godot --headless --path . tools/generate_theme.tscn
##

const OUTPUT_DIR := "res://assets/theme"
const OUTPUT_PATH := "res://assets/theme/kings_gambit_theme.tres"


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 15
	# Sans police par defaut, TOUT le jeu s'affiche dans la police de secours
	# de Godot : les tailles de la maquette sont calees sur Inter.
	var default_font := UiTheme.font()
	if default_font != null:
		theme.default_font = default_font

	_setup_buttons(theme)
	_setup_panels(theme)
	_setup_labels(theme)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var err := ResourceSaver.save(theme, OUTPUT_PATH)
	if err == OK:
		print("Theme genere : %s" % OUTPUT_PATH)
	else:
		print("ERREUR : impossible d'enregistrer le theme (code %d)" % err)

	get_tree().quit()


# ------------------------------- BOUTONS --------------------------------------
# Cf. CLAUDE.md > "Composants UI a creer en Godot > Boutons"

func _setup_buttons(theme: Theme) -> void:
	# Primaire : BATAILLE, COMBATTRE
	_button_variant(theme, "PrimaryButton", UiTheme.GOLD, UiTheme.GOLD_TEXT, 18,
		Color("d4af37"), 2, 19, true)
	# Action Or : Ameliorer, Preparer, Bataille suivante - texte fonce, pas
	# blanc : la maquette Figma Phase 2 (Gold-Button, Btn-Next) l'ecrit en
	# noir/brun fonce sur le fond dore, CLAUDE.md est reste sur l'ancienne
	# valeur blanche de la Phase 1.
	_button_variant(theme, "GoldButton", UiTheme.GOLD_BUTTON, UiTheme.GOLD_TEXT, 10,
		Color("ffd700"), 1, 14, true)
	# Action Bleu : AUTO
	_button_variant(theme, "AccentButton", UiTheme.ACCENT, UiTheme.TEXT, 10,
		Color(0, 0, 0, 0), 0, 15, false)
	# Secondaire : Reessayer, Annuler
	_button_variant(theme, "SecondaryButton", UiTheme.PANEL_LIGHT, UiTheme.TEXT, 10,
		UiTheme.BORDER, 1, 15, false)
	# Danger : Abandonner
	_button_variant(theme, "DangerButton", UiTheme.DANGER, UiTheme.TEXT, 10,
		Color(0, 0, 0, 0), 0, 15, false)
	# Discret / Lien : Village (retour)
	_button_variant(theme, "DiscreetButton", Color(0, 0, 0, 0), UiTheme.TEXT_DIM, 0,
		Color(0, 0, 0, 0), 0, 14, false)

	# Bouton par defaut (non stylise explicitement) : rendu Secondaire, pour
	# qu'un Button oublie reste lisible plutot que de tomber sur le gris moteur.
	theme.set_stylebox("normal", "Button", _button_box(UiTheme.PANEL_LIGHT, 10, UiTheme.BORDER, 1))
	theme.set_stylebox("hover", "Button", _button_box(UiTheme.PANEL_LIGHT.lightened(0.12), 10, UiTheme.BORDER, 1))
	theme.set_stylebox("pressed", "Button", _button_box(UiTheme.PANEL_LIGHT.darkened(0.18), 10, UiTheme.BORDER, 1))
	theme.set_stylebox("disabled", "Button", _button_box(UiTheme.PANEL_LIGHT.darkened(0.45), 10, UiTheme.BORDER, 1))
	theme.set_color("font_color", "Button", UiTheme.TEXT)
	theme.set_color("font_disabled_color", "Button", UiTheme.TEXT_DIM)
	theme.set_font_size("font_size", "Button", 15)


func _button_variant(theme: Theme, variation: String, bg: Color, font_color: Color,
		radius: int, border: Color, border_width: int, font_size: int, bold: bool) -> void:
	theme.set_type_variation(variation, "Button")
	theme.set_stylebox("normal", variation, _button_box(bg, radius, border, border_width))
	theme.set_stylebox("hover", variation, _button_box(bg.lightened(0.12), radius, border, border_width))
	theme.set_stylebox("pressed", variation, _button_box(bg.darkened(0.18), radius, border, border_width))
	theme.set_stylebox("focus", variation, _button_box(bg, radius, border, border_width))
	theme.set_stylebox("disabled", variation, _button_box(bg.darkened(0.45) if bg.a > 0 else bg, radius, border, border_width))
	theme.set_color("font_color", variation, font_color)
	theme.set_color("font_hover_color", variation, font_color)
	theme.set_color("font_pressed_color", variation, font_color)
	theme.set_color("font_disabled_color", variation, UiTheme.TEXT_DIM)
	theme.set_font_size("font_size", variation, font_size)
	# Inter etant une police variable, ses graisses sont des FontVariation
	# construites a la volee : elles n'ont pas de resource_path, il ne faut
	# donc pas s'en servir comme condition.
	var font := UiTheme.font_bold() if bold else UiTheme.font()
	if font != null:
		theme.set_font("font", variation, font)


func _button_box(bg: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(UiTheme.PAD)
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box


# ------------------------------- PANNEAUX --------------------------------------
# Cf. CLAUDE.md > "Modales" / "Pills / Badges"

func _setup_panels(theme: Theme) -> void:
	# Modale : fond #161926, radius 16-20, stroke 2px (couleur de contexte ;
	# l'or est le defaut, les modales rouge/bleu l'ecrasent via ModalComponent).
	theme.set_type_variation("ModalPanel", "PanelContainer")
	theme.set_stylebox("panel", "ModalPanel", _panel_box(UiTheme.PANEL, 18, UiTheme.GOLD, 2))

	# Card interne : fond #262c3f, radius 12, sans bordure.
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _panel_box(UiTheme.PANEL_LIGHT, 12, Color(0, 0, 0, 0), 0))

	# Pill / badge : fond noir, radius 10.
	theme.set_type_variation("PillPanel", "PanelContainer")
	theme.set_stylebox("panel", "PillPanel", _panel_box(Color("0a0d14"), 10, Color(0, 0, 0, 0), 0))

	# Panel par defaut : identique a UiTheme.panel_box(), pour rester coherent
	# avec les ecrans deja construits en code.
	theme.set_stylebox("panel", "PanelContainer", _panel_box(UiTheme.PANEL, UiTheme.RADIUS, UiTheme.BORDER, 1))


func _panel_box(bg: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(UiTheme.PAD)
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	return box


# ------------------------------- LABELS ----------------------------------------

func _setup_labels(theme: Theme) -> void:
	theme.set_type_variation("TitleLabel", "Label")
	theme.set_color("font_color", "TitleLabel", UiTheme.GOLD)
	theme.set_font_size("font_size", "TitleLabel", 26)
	var bold := UiTheme.font_bold()
	if bold != null and bold.resource_path != "":
		theme.set_font("font", "TitleLabel", bold)

	theme.set_type_variation("HeadingLabel", "Label")
	theme.set_color("font_color", "HeadingLabel", UiTheme.TEXT)
	theme.set_font_size("font_size", "HeadingLabel", 17)
	if bold != null and bold.resource_path != "":
		theme.set_font("font", "HeadingLabel", bold)

	theme.set_type_variation("DimLabel", "Label")
	theme.set_color("font_color", "DimLabel", UiTheme.TEXT_DIM)
	theme.set_font_size("font_size", "DimLabel", 12)

	theme.set_color("font_color", "Label", UiTheme.TEXT)
	theme.set_font_size("font_size", "Label", 15)
