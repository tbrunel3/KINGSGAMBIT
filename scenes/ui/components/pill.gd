class_name Pill
extends PanelContainer
##
## PILL / BADGE - petit indicateur arrondi (or, niveau, statut).
##
## Cf. CLAUDE.md > "Pills / Badges" : fond noir ou #262c3f, radius 8-10,
## texte 10-12px semi-bold. Quatre variantes couvrent les cas releves dans
## 12_Composants (bloque, amelioration, niveau, promotion).
##

enum Variant { DEFAULT, OUTLINE, INFO, GOLD, TOPBAR }

@onready var _icon: Icon = %Icon
@onready var _texture: TextureRect = %Texture
@onready var _text: Label = %Text


func _ready() -> void:
	set_variant(Variant.DEFAULT)


## `icon_name` est un nom reconnu par Icon ("lock", "wrench", "star"...) ;
## laisser vide pour l'omettre. `icon_color` force la couleur de l'icone
## independamment du texte (ex. pastille or/gemmes de la top bar Village,
## ou l'icone est teintee mais le texte reste blanc) ; laisser transparent
## (alpha 0) pour heriter de la couleur de texte du variant.
func set_data(icon_name: String, text: String, variant: Variant = Variant.DEFAULT,
		icon_color: Color = Color(0, 0, 0, 0)) -> void:
	# Une pastille qui porte une IMAGE la garde : sinon le moindre
	# rafraichissement de son texte reposerait un glyphe par-dessus.
	_icon.visible = not icon_name.is_empty() and not _texture.visible
	if not icon_name.is_empty():
		_icon.icon_name = icon_name
	_text.text = text
	set_variant(variant, icon_color)


func set_variant(variant: Variant, icon_color: Color = Color(0, 0, 0, 0)) -> void:
	var bg := Color("0a0d14")
	var border := Color(0, 0, 0, 0)
	var border_width := 0
	var font_color := UiTheme.TEXT

	match variant:
		Variant.OUTLINE:
			bg = Color(0, 0, 0, 0)
			border = UiTheme.GOLD
			border_width = 1
			font_color = UiTheme.GOLD
		Variant.INFO:
			bg = UiTheme.ACCENT
			font_color = UiTheme.TEXT
		Variant.GOLD:
			bg = UiTheme.GOLD
			font_color = UiTheme.GOLD_TEXT
		Variant.TOPBAR:
			bg = Color(0, 0, 0, 0.25)
			font_color = UiTheme.TEXT

	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(10)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	add_theme_stylebox_override("panel", box)

	_icon.set_icon(_icon.icon_name, icon_color if icon_color.a > 0 else font_color)
	_text.add_theme_color_override("font_color", font_color)


## Remplace le glyphe par une IMAGE - la piece d'or du jeu, par exemple.
##
## Un glyphe vectoriel rend bien une forme simple (cadenas, couronne, etoile) ;
## il ne rend pas une piece frappee. La maquette pose une vraie piece dans la
## pastille d'or de la barre du haut, et le projet l'a deja en asset : autant
## la montrer plutot que d'en dessiner une approximation au compas.
func set_texture(texture: Texture2D, taille: float = 16.0) -> void:
	_icon.visible = false
	_texture.visible = texture != null
	_texture.texture = texture
	_texture.custom_minimum_size = Vector2(taille, taille)


## Ecarte ponctuellement la couleur de texte fixee par le variant (ex. le
## "Nv. X" dore de la pastille couronne, distinct du blanc des autres
## pastilles de la top bar).
func set_text_color(color: Color) -> void:
	_text.add_theme_color_override("font_color", color)


func set_bold(bold: bool) -> void:
	_text.add_theme_font_override("font", UiTheme.font_bold() if bold else UiTheme.font())


## Pastille a couleur libre (fond + texte), pour les cas ou aucun des cinq
## variants ne correspond - ex. le niveau de chaque batiment du Village,
## teinte selon la couleur de l'unite (cf. captures Figma 01, ou chaque label
## a sa propre teinte plutot que le bleu uniforme du variant INFO).
func set_custom(icon_name: String, text: String, bg: Color, text_color: Color,
		radius: int = 6, pad_h: int = 6, pad_v: int = 2) -> void:
	_icon.visible = not icon_name.is_empty()
	if not icon_name.is_empty():
		_icon.icon_name = icon_name
	_text.text = text

	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad_h
	box.content_margin_right = pad_h
	box.content_margin_top = pad_v
	box.content_margin_bottom = pad_v
	add_theme_stylebox_override("panel", box)

	_icon.set_icon(_icon.icon_name, text_color)
	_text.add_theme_color_override("font_color", text_color)
