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

## L'ENTREE DE MODALE DU JEU ENTIER, posee ici une seule fois.
##
## Relevee sur les trois popups de batiment (410:7342, 410:7488, 410:7629),
## qui portent exactement la meme timeline : le voile monte sur les 20 premiers
## pour cent, puis la modale apparait de 0,15 s a 0,6 s en opacite et en
## echelle, courbe cubic-bezier(0, 0, 0.2, 1).
##
## Elle sert d'un seul coup TOUT ce qui passe par Modal - verifie, six
## appelants : les popups de batiment (building_popup.gd couvre ses quatre
## etats dans une seule scene), la confirmation d'amelioration, le popup de
## missions, le popup de serie, l'aide de la bataille et la vitrine du kit.
const ENTRY_DELAY := 0.15
const ENTRY_DURATION := 0.45
const ENTRY_SCALE := 0.92
## Le voile est plus rapide que la modale : il assombrit d'abord, la modale
## arrive dessus. 20 % de la timeline de la maquette.
const DIM_SECONDS := 0.12

signal closed

## L entree a deja joue : plusieurs appelants rappellent open() pour se
## reconstruire, pas pour se rouvrir.
var _entered: bool = false

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
	_animate_entry()


## ⚠️ PAS DE TRANSLATION ICI, et ce n'est pas un oubli.
##
## La maquette fait aussi monter la modale de 30 px. Mais _panel est
## $Center/Panel, donc enfant d'un CenterContainer : un tween de position s'y
## battrait avec la mise en page, exactement comme sur le bandeau de serie -
## piege deja paye une fois. L'opacite et l'echelle suffisent a lire le
## mouvement, et ce sont les deux autres proprietes que la maquette anime.
func _animate_entry() -> void:
	# ⚠️ UNE FOIS PAR MODALE, jamais deux.
	#
	# Plusieurs appelants rappellent open() pour se RECONSTRUIRE, pas pour se
	# rouvrir : le popup de missions le fait a chaque reclamation, celui de
	# batiment a chaque recrutement. Sans ce garde-fou, la modale rejouerait
	# son entree dans le dos du joueur au moment precis ou il vient d'agir -
	# son geste effacerait l'ecran puis le ferait revenir.
	if _entered:
		return
	_entered = true

	# La taille ne se lit qu'une fois la mise en page faite : relevee a
	# l'ouverture, elle vaut encore zero, et le pivot tomberait dans le coin.
	await get_tree().process_frame
	if not is_inside_tree():
		return

	_panel.pivot_offset = _panel.size * 0.5
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * ENTRY_SCALE

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, DIM_SECONDS)
	tween.tween_property(_panel, "modulate:a", 1.0, ENTRY_DURATION) \
		.set_delay(ENTRY_DELAY)
	tween.tween_property(_panel, "scale", Vector2.ONE, ENTRY_DURATION) \
		.set_delay(ENTRY_DELAY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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


## Recercle la modale sans toucher a la couleur de son titre.
##
## Le popup de batiment VERROUILLE en a besoin : la maquette (410:7488) le
## cercle d'OR alors que son titre et son cadenas restent gris. Un batiment
## verrouille est ce que le joueur VEUT - un cadre sourd le lit comme
## "indisponible pour toujours".
func set_border_color(color: Color) -> void:
	var box := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	var edged := box.duplicate() as StyleBoxFlat
	edged.border_color = color
	_panel.add_theme_stylebox_override("panel", edged)


func close() -> void:
	closed.emit()
	queue_free()


func _on_dim_input(event: InputEvent) -> void:
	if close_on_dim_click and event is InputEventMouseButton and event.pressed:
		close()
