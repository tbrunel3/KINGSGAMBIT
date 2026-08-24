extends Control
##
## L'ECRAN DE LA MISSIVE - l'enveloppe scellee du Roi, et son parchemin.
##
## Le support est une decision du joueur (cf. chantier_i_missives.md) : le Roi
## n'a pas de corps dans ce jeu - il est sur son trone a l'intro et plus jamais.
## Une lettre dit exactement la bonne chose : il n'est pas la, mais il te suit.
##
## Sequence : le village s'assombrit, l'enveloppe se pose au centre avec son
## invite -> le doigt la touche -> le parchemin arrive en grandissant -> le
## texte se revele -> le bouton CONTINUER monte et se debloque.
##
## ⚠️ L'ECRAN NE FLOTTE PAS DANS LE VIDE : LE VILLAGE RESTE DERRIERE.
## Les deux frames du graphiste (510:2 lettre-roi-fermee, 510:7
## lettre-roi-ouverte) posent le fond du village sous un voile noir - 60 % sur
## l'enveloppe, 65 % sur le parchemin. C'est ce qui rattache la lettre au lieu
## ou on la recoit ; un fond plein aurait fait un ecran de systeme.
##
## ⚠️ CE N'EST PLUS LE DEPLI EN TROIS TRANCHES DE LA SPEC, ET C'EST VOULU.
## La spec decrivait un parchemin plie en trois, mesure sur deux PNG generes
## hors Figma (plissures a 39,5 % et 65,4 %) qui ne sont jamais entres dans le
## depot. Le graphiste a depuis dessine l'ecran : son parchemin est d'une SEULE
## piece, et il arrive en grandissant plutot qu'en se depliant. La maquette
## apporte l'apparence (regle 2) - le depli en trois temps est donc retire, et
## avec lui les mesures de plissure qui n'ont plus d'objet.
##
## ⚠️ LES DEUX PNG NE SONT PAS DANS LE DEPOT, et l'ecran tient sans eux : le
## parchemin et l'enveloppe se DESSINENT alors, aux memes dimensions et avec la
## meme animation. Ce n'est pas un placeholder qu'on oubliera dans `assets/` -
## c'est un repli qui vit dans le code, et poser les fichiers suffit a le
## remplacer sans toucher une ligne.
##

const PARCHMENT_PATH := "res://assets/story/letter_parchment.png"
const ENVELOPE_PATH := "res://assets/story/letter_envelope.png"
const VILLAGE_PATH := "res://assets/backgrounds/village_background.png"

# ------------------------------- LES MESURES ---------------------------------
#
#  Relevees sur 510:2 et 510:7, cadre de reference 393 x 852.
#
#  ⚠️ TOUTES EN PART DU CADRE, JAMAIS EN POINTS. Un `393` ou un `852` litteral
#  dans du code de mise en page est presque toujours un bug qui attend un
#  navigateur : en `expand`, c'est la HAUTEUR qui varie d'un appareil a l'autre,
#  et sur le Web la largeur MONTE jusqu'a 495 (regle 4).

const REF := Vector2(393.0, 852.0)

## Le voile : 60 % sur l'enveloppe, 65 % une fois la lettre ouverte.
const VEIL_CLOSED := 0.60
const VEIL_OPEN := 0.65

## L'enveloppe : 240 x 240, centree, haut a 266 / 852.
const ENVELOPE_SIZE := 240.0 / 393.0
const ENVELOPE_TOP := 266.0 / 852.0
## L'invite "Appuyez pour ouvrir" : Inter Bold 14, or clair, haut a 526.
const PROMPT_TOP := 526.0 / 852.0
const PROMPT_COLOR := Color("ffd933")
const PROMPT_SIZE := 14

## Le parchemin : 340 x 420, centre, haut a 160 / 852, rayon 8.
const SHEET_W := 340.0 / 393.0
const SHEET_H := 420.0 / 852.0
const SHEET_TOP := 160.0 / 852.0
const SHEET_RADIUS := 8.0

## Le texte : 280 de large, haut a 240, Poppins Medium 20, encre brune.
const TEXT_W := 280.0 / 393.0
const TEXT_TOP := 240.0 / 852.0
const TEXT_SIZE := 20
const TEXT_COLOR := Color("33261a")

## CONTINUER : 303 x 48, haut a 640, rayon 12, or plein, encre presque noire.
const BUTTON_W := 303.0 / 393.0
const BUTTON_H := 48.0 / 852.0
const BUTTON_TOP := 640.0 / 852.0
const BUTTON_RADIUS := 12.0
const BUTTON_FILL := Color("ffd700")
const BUTTON_INK := Color("1a0d00")
const BUTTON_SIZE := 16

# ------------------------------- LES TEMPS -----------------------------------
#
#  Timeline relevee sur 510:7 (get_motion_context, 4 s). La boucle est un
#  artefact d'apercu - Figma rejoue l'entree en rond faute de savoir qu'elle ne
#  se joue qu'une fois. Ce qui compte, ce sont les decalages et les courbes.

## Le parchemin : opacite 0 -> 1 et echelle 0,7 -> 1 sur les 20 premiers %.
const SHEET_TIME := 0.8
const SHEET_FROM := 0.7
## Le texte : rien jusqu'a 15 %, puis fondu jusqu'a 62,5 %.
const TEXT_DELAY := 0.6
const TEXT_TIME := 1.9
## Le bouton : rien jusqu'a 75 %, puis il monte de 20 points sur 15 %.
const BUTTON_DELAY := 3.0
const BUTTON_TIME := 0.6
const BUTTON_RISE := 20.0

var key: String = ""
var _stage: Control
var _veil: ColorRect
var _envelope: Control
var _prompt: Label
var _sheet: Control
var _text: Label
var _button: Control
var _button_label: Label
var _opened := false


func _ready() -> void:
	_stage = get_node("Safe/Root/Stage")
	_veil = get_node("Veil")
	key = Router.current_letter if Router.current_letter != "" else Letters.HERITAGE

	_build_background()
	_build_envelope()
	_build_sheet()
	# ⚠️ APRES la mise en page, jamais a la construction : un pivot pose avant
	# que le conteneur ait donne sa taille reste a (0,0), et le parchemin
	# grandirait depuis le coin de l'ecran. Piege deja paye sur le bandeau de
	# serie.
	await get_tree().process_frame
	_place()
	get_tree().get_root().size_changed.connect(_place)
	_animate_envelope()


# ------------------------------- CONSTRUCTION --------------------------------

## Le village, puis le voile. Le fond est celui du JEU, pas un export de la
## maquette : c'est le meme lieu, et un export aurait emporte le fond de la
## frame avec lui (piege deja paye sur `parchment_map.jpg`).
func _build_background() -> void:
	var village := TextureRect.new()
	village.texture = UiTheme.texture_or_null(VILLAGE_PATH)
	village.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	village.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	village.mouse_filter = Control.MOUSE_FILTER_IGNORE
	village.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(village)
	move_child(village, 0)
	_veil.color = Color(0, 0, 0, VEIL_CLOSED)


func _build_envelope() -> void:
	_envelope = Control.new()
	_envelope.mouse_filter = Control.MOUSE_FILTER_PASS
	_stage.add_child(_envelope)

	var art := UiTheme.texture_or_null(ENVELOPE_PATH)
	if art != null:
		var rect := TextureRect.new()
		rect.texture = art
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_envelope.add_child(rect)
	else:
		var drawn := _Envelope.new()
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_envelope.add_child(drawn)

	# ⚠️ ON DECIDE AU RELACHEMENT. L'ecran n'a rien a faire defiler, mais un
	# doigt pose par erreur doit pouvoir glisser a cote pour annuler - c'est la
	# meme regle que partout ailleurs depuis les cachets (cf. UiTheme.on_tap).
	UiTheme.on_tap(_envelope, _open)

	_prompt = UiTheme.make_label("Appuyez pour ouvrir", PROMPT_SIZE, PROMPT_COLOR)
	_prompt.add_theme_font_override("font", UiTheme.font_bold())
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_prompt)


func _build_sheet() -> void:
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	_stage.add_child(_sheet)

	var art := UiTheme.texture_or_null(PARCHMENT_PATH)
	if art != null:
		var rect := TextureRect.new()
		rect.texture = art
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sheet.add_child(rect)
	else:
		var drawn := _Sheet.new()
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sheet.add_child(drawn)

	# Les trois blocs de `Letters` empiles : l'adresse, le corps, la signature.
	# La maquette n'en montre qu'un - c'est le contenu d'exemple du designer -,
	# mais les trois se lisent comme les paragraphes qu'elle separe.
	_text = UiTheme.make_label("\n\n".join(Letters.blocks(key)), TEXT_SIZE, TEXT_COLOR)
	_text.add_theme_font_override("font", UiTheme.font_display_medium())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.modulate.a = 0.0
	_text.visible = false
	_stage.add_child(_text)

	_button = _Plaque.new()
	_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_button.modulate.a = 0.0
	_button.visible = false
	_stage.add_child(_button)
	UiTheme.on_tap(_button, _close)

	_button_label = UiTheme.make_label("CONTINUER", BUTTON_SIZE, BUTTON_INK)
	_button_label.add_theme_font_override("font", UiTheme.font_bold())
	_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_button.add_child(_button_label)


# ------------------------------- LA GEOMETRIE --------------------------------

## Pose tout en PART du cadre : ancrer, ne pas positionner (regle 4).
func _place() -> void:
	if _stage == null or not is_instance_valid(_stage):
		return
	var space := _stage.size
	if space.x <= 0.0 or space.y <= 0.0:
		return

	var env := space.x * ENVELOPE_SIZE
	_envelope.size = Vector2(env, env)
	_envelope.position = Vector2((space.x - env) * 0.5, space.y * ENVELOPE_TOP)
	_envelope.pivot_offset = _envelope.size * 0.5

	_prompt.size = Vector2(space.x, 0.0)
	_prompt.position = Vector2(0.0, space.y * PROMPT_TOP)

	var sheet := Vector2(space.x * SHEET_W, space.y * SHEET_H)
	_sheet.size = sheet
	_sheet.position = Vector2((space.x - sheet.x) * 0.5, space.y * SHEET_TOP)
	# Le parchemin grandit depuis son CENTRE : il arrive, il ne se deplie plus.
	_sheet.pivot_offset = sheet * 0.5

	var text_w := space.x * TEXT_W
	_text.size = Vector2(text_w, 0.0)
	_text.position = Vector2((space.x - text_w) * 0.5, space.y * TEXT_TOP)

	var button := Vector2(space.x * BUTTON_W, space.y * BUTTON_H)
	_button.size = button
	_button.position = Vector2((space.x - button.x) * 0.5, space.y * BUTTON_TOP)


# ------------------------------- LES TEMPS -----------------------------------

func _animate_envelope() -> void:
	_envelope.modulate.a = 0.0
	_envelope.scale = Vector2(0.92, 0.92)
	_prompt.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_envelope, "modulate:a", 1.0, 0.35)
	tween.tween_property(_envelope, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_prompt, "modulate:a", 1.0, 0.4).set_delay(0.35)


## Le parchemin arrive, le texte se revele, le bouton monte.
func _open() -> void:
	if _opened:
		return
	_opened = true
	Game.mark_letter_read(key)

	_sheet.visible = true
	_sheet.modulate.a = 0.0
	_sheet.scale = Vector2(SHEET_FROM, SHEET_FROM)
	_text.visible = true
	_button.visible = true
	var rest := _button.position

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_envelope, "modulate:a", 0.0, 0.25)
	tween.tween_property(_prompt, "modulate:a", 0.0, 0.25)
	tween.tween_property(_veil, "color:a", VEIL_OPEN, SHEET_TIME)

	tween.tween_property(_sheet, "modulate:a", 1.0, SHEET_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sheet, "scale", Vector2.ONE, SHEET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(_text, "modulate:a", 1.0, TEXT_TIME).set_delay(TEXT_DELAY) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ⚠️ LE BOUTON MONTE, IL N'EST PAS DANS UN CONTENEUR. Animer la `position`
	# d'un enfant de conteneur, c'est se battre avec la mise en page - c'est ce
	# qui avait colle le bandeau de serie en haut de l'ecran.
	_button.position = rest + Vector2(0.0, BUTTON_RISE)
	tween.tween_property(_button, "modulate:a", 1.0, BUTTON_TIME).set_delay(BUTTON_DELAY)
	tween.tween_property(_button, "position", rest, BUTTON_TIME).set_delay(BUTTON_DELAY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close() -> void:
	if not _opened:
		return
	Game.mark_letter_read(key)
	if Router.letter_return == Router.RETURN_CASTLE:
		Router.goto_castle()
	else:
		Router.goto_village()


# ------------------------------- LE REPLI DESSINE ----------------------------

## Le parchemin, quand le PNG n'est pas la : creme, double filet d'or, coins
## arrondis. Memes dimensions que l'image, donc meme geometrie a mesurer -
## c'est ce qui permet de verifier l'ecran et les huit formats sans attendre le
## graphiste.
class _Sheet extends Control:
	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("f4e8cf")
		box.border_color = Color("c9a227")
		box.set_border_width_all(3)
		box.set_corner_radius_all(8)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var inset := 8.0
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0),
			Color("c9a227"), false, 1.0)


## Le bouton CONTINUER : une plaque d'or pleine, rayon 12, comme la maquette.
##
## Dessine plutot que `UiTheme.make_button` : le bouton de la maquette est un
## aplat d'or vif sans degrade ni bordure, et il doit se laisser MONTER a
## l'entree - un Button dans le theme du jeu apporte une peau qui n'est pas
## celle-la.
class _Plaque extends Control:
	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ffd700")
		box.set_corner_radius_all(12)
		draw_style_box(box, Rect2(Vector2.ZERO, size))


## L'enveloppe fermee : le rabat, et le sceau de cire au centre.
class _Envelope extends Control:
	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("f4e8cf")
		box.border_color = Color("c9a227")
		box.set_border_width_all(2)
		box.set_corner_radius_all(6)
		# L'enveloppe de la maquette est en PAYSAGE dans son carre de 240.
		var body := Rect2(Vector2(0.0, size.y * 0.2), Vector2(size.x, size.y * 0.6))
		draw_style_box(box, body)
		# Le rabat, deux traits qui descendent vers le centre.
		var top_left := body.position
		var top_right := body.position + Vector2(body.size.x, 0.0)
		var middle := body.position + Vector2(body.size.x * 0.5, body.size.y * 0.55)
		draw_line(top_left, middle, Color("c9a227"), 2.0)
		draw_line(top_right, middle, Color("c9a227"), 2.0)
		# Le sceau.
		draw_circle(body.position + body.size * 0.5, minf(size.x, size.y) * 0.12,
			Color("8e2b20"))
