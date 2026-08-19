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


func set_count(count: int) -> void:
	_count.text = "×%d" % count
	modulate.a = 1.0 if count > 0 else 0.5


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
