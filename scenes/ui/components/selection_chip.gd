class_name SelectionChip
extends PanelContainer
##
## CHIP DE SELECTION - piece a placer, avec icone + nom + compteur.
##
## Cf. CLAUDE.md > "Chips de selection (placement)" : fond #161926, radius 8,
## stroke quand selectionne. Utilise en ecran 04 pour choisir quel type de
## piece poser ; la selection elle-meme (un seul type actif a la fois) reste
## decidee par l'ecran appelant, qui appelle set_selected() sur chaque chip.
##

signal pressed

@export var selected: bool = false:
	set(value):
		selected = value
		_restyle()

## Le type de piece que la chip represente, et ce qu'il en reste. La chip s'en
## sert pour se laisser SAISIR : sans le type, elle ne saurait pas quoi donner
## au plateau, et sans le compte elle proposerait de poser une piece epuisee.
var piece_type: String = ""
var _count_value: int = 0

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %NameLabel
@onready var _count: Label = %CountLabel


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	UiTheme.ignore_mouse_recursive($Column)
	_restyle()


func set_piece(icon: Texture2D, piece_name: String, count: int) -> void:
	_icon.texture = icon
	_name.text = piece_name
	set_count(count)


## Change la seule silhouette, sans toucher au nom ni au compteur : l'ecran de
## placement bascule entre la piece coloree et sa version grisee selon qu'il
## reste ou non des exemplaires a poser.
func set_icon(icon: Texture2D) -> void:
	_icon.texture = icon


func set_count(count: int) -> void:
	_count_value = count
	_count.text = "×%d" % count
	modulate.a = 1.0 if count > 0 else 0.5


## LE GLISSER-DEPOSER VERS LE PLATEAU (chantier C).
##
## ⚠️ Le tap n'est pas remplace. Godot ne demande `_get_drag_data` qu'une fois
## le bouton enfonce ET la souris deplacee ; un appui immobile part encore dans
## `gui_input`, donc "je touche la chip puis je touche la case" continue de
## marcher exactement comme avant. Le glissement s'ajoute, il ne remplace pas.
##
## La chip epuisee ne se saisit pas : faire miroiter un placement que le
## plateau refusera au lacher est pire que ne rien proposer.
func _get_drag_data(_position: Vector2) -> Variant:
	if piece_type.is_empty() or _count_value <= 0:
		return null
	UiTheme.drag_preview_for(self, _icon.texture if _icon != null else null, 48.0)
	return {"ou": "inventaire", "type": piece_type}



func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


## Cf. capture Figma 04 (Chips-Row) : fond blanc translucide au repos, fond
## bleu translucide quand selectionne - jamais UiTheme.PANEL/GOLD, qui ne
## correspondent plus a la maquette Phase 2.
func _restyle() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 8
	box.content_margin_bottom = 6
	box.set_border_width_all(1)
	if selected:
		box.bg_color = Color(UiTheme.ACCENT, 0.3)
		box.border_color = Color(0.302, 0.6, 1.0, 0.6)
	else:
		box.bg_color = Color(1, 1, 1, 0.06)
		box.border_color = Color(1, 1, 1, 0.1)
	add_theme_stylebox_override("panel", box)
	# _count n'existe pas encore lors de l'assignation initiale de `selected`
	# (avant _ready) : le defaut @export declenche ce setter des la construction.
	if _count != null:
		_count.add_theme_color_override("font_color", Color("66bfff") if selected else Color("9999b2"))
