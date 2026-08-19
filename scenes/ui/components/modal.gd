class_name Modal
extends Control
##
## MODALE GENERIQUE - fond assombri + panneau centre + contenu libre.
##
## Generalise le couple Dim/Center/Panel deja utilise par
## scenes/village/building_popup.gd, pour que victoire/defaite et les popups
## de batiment partagent le meme composant plutot que de re-coder le meme
## dim+panneau+croix a chaque ecran.
##
## Usage :
##   var modal := preload("res://scenes/ui/components/modal.tscn").instantiate()
##   add_child(modal)
##   modal.open("VICTOIRE", Modal.Context.GOLD)
##   modal.body.add_child(some_label)
##   modal.closed.connect(...)
##

enum Context { GOLD, RED, BLUE, NEUTRAL }

signal closed

@export var close_on_dim_click: bool = true
@export var show_close_button: bool = true

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Center/Panel
@onready var _content: Control = $Center/Panel/Content
@onready var _background_image: TextureRect = %BackgroundImage
@onready var _background_overlay: ColorRect = %BackgroundOverlay
@onready var _content_margin: MarginContainer = $Center/Panel/Content/Margin
@onready var _header_icon_wrap: CenterContainer = %HeaderIcon
@onready var _header_icon: Icon = %HeaderIconGlyph
@onready var _title: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var body: VBoxContainer = %Body


func _ready() -> void:
	_dim.gui_input.connect(_on_dim_input)
	_close_button.pressed.connect(close)
	_close_button.visible = show_close_button

	# "Content" est un Control nu (pas un Container) - il ne remonte jamais
	# la taille minimale de "Margin" vers Panel, qui se retrouve alors reduit
	# a ses seules marges (~24px) pendant que Root deborde sans fond derriere
	# lui. Un Container se re-sonderait automatiquement ; ici il faut recopier
	# la taille min de Margin a la main a chaque fois qu'elle change.
	_content_margin.minimum_size_changed.connect(_sync_content_size)
	_sync_content_size()


func _sync_content_size() -> void:
	_content.custom_minimum_size = _content_margin.get_combined_minimum_size()


## Affiche la modale. `title` vide masque le label de titre. `header_icon`
## (nom reconnu par Icon, ex. "crown") ajoute un glyphe centre au-dessus du
## titre, comme sur les modales Victoire/Defaite/Chateau des captures Figma ;
## laisser vide pour l'omettre (cas des popups de batiment, cf. building_popup.gd).
func open(title: String = "", context: Context = Context.GOLD, header_icon: String = "") -> void:
	set_context(context)
	_title.visible = not title.is_empty()
	_title.text = title
	_header_icon_wrap.visible = not header_icon.is_empty()
	if not header_icon.is_empty():
		_header_icon.set_icon(header_icon, _header_icon.color)
	visible = true


## Image de fond optionnelle derriere le contenu, avec un voile sombre pour
## garder le texte lisible - cf. Victory-Modal/Defeat-Modal des captures
## Figma. Sans appel, la modale garde son fond plat habituel.
func set_background(texture: Texture2D, overlay_alpha: float = 0.35) -> void:
	_background_image.texture = texture
	_background_image.visible = texture != null
	_background_overlay.color.a = overlay_alpha
	_background_overlay.visible = texture != null


func set_context(context: Context) -> void:
	var color := UiTheme.GOLD
	# Bordure plus sourde que le titre/icone en contexte or - cf. captures
	# Figma 06/08, ou le contour de la modale (#d4af37) est nettement plus
	# terne que le "CHÂTEAU ROYAL"/"VICTOIRE" en #ffd700 au-dessus.
	var border := Color("d4af37")
	match context:
		Context.RED:
			color = UiTheme.DANGER
			border = color
		Context.BLUE:
			color = UiTheme.ACCENT
			border = color
		Context.NEUTRAL:
			color = UiTheme.BORDER.lightened(0.2)
			border = color
	var base := _panel.get_theme_stylebox("panel", "ModalPanel") as StyleBoxFlat
	var box := base.duplicate() as StyleBoxFlat
	box.border_color = border
	_panel.add_theme_stylebox_override("panel", box)
	_title.add_theme_color_override("font_color", color)
	_header_icon.set_icon(_header_icon.icon_name, color)


func close() -> void:
	closed.emit()
	queue_free()


func _on_dim_input(event: InputEvent) -> void:
	if close_on_dim_click and event is InputEventMouseButton and event.pressed:
		close()
