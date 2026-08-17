extends MarginContainer
##
## SAFE AREA - garde le contenu hors de l'encoche et de la barre d'accueil.
##
## Sur iPhone, DisplayServer expose la zone sure en pixels ecran. On la convertit
## en marges de conteneur. Sur PC, la zone sure vaut tout l'ecran : on retombe
## alors sur les marges minimales ci-dessous.
##

@export var min_margin_h: int = 16
@export var min_margin_top: int = 12
@export var min_margin_bottom: int = 16


func _ready() -> void:
	_apply()
	get_tree().get_root().size_changed.connect(_apply)


func _apply() -> void:
	var margins := Vector4i(min_margin_h, min_margin_top, min_margin_h, min_margin_bottom)

	var window_size := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0:
		# Ratio ecran -> unites de l'interface (viewport 393 x 852).
		var scale := Vector2(
			float(size.x) / float(window_size.x),
			float(size.y) / float(window_size.y)
		)
		margins.x = maxi(margins.x, int(safe.position.x * scale.x))
		margins.y = maxi(margins.y, int(safe.position.y * scale.y))
		margins.z = maxi(margins.z, int((window_size.x - safe.end.x) * scale.x))
		margins.w = maxi(margins.w, int((window_size.y - safe.end.y) * scale.y))

	add_theme_constant_override("margin_left", margins.x)
	add_theme_constant_override("margin_top", margins.y)
	add_theme_constant_override("margin_right", margins.z)
	add_theme_constant_override("margin_bottom", margins.w)
