extends Control
class_name RoyalLetter
##
## LES MISSIVES DU ROI - chantier I.
##
## Le jeu ne disait jamais POURQUOI. Le joueur reçoit quatre pions, un cavalier
## et 300 or, et rien ne lui explique que c'est ce qui a survécu à l'enlèvement
## plutôt qu'un cadeau de départ. Le Roi parle une fois, sur son trône, puis
## disparaît pendant dix batailles.
##
## Quatre lettres scellées lui rendent une voix qui revient, aux quatre moments
## où le jeu bascule (cf. `Letters` pour les textes, `_DECLENCHEURS` pour les
## jalons).
##
## ⚠️ UNE LETTRE N'ENTRE JAMAIS EN COMBAT. Elle porte le POURQUOI - le sens,
## l'enjeu, l'héritage - là où `GuidePopup` porte le COMMENT (le pat, la
## charge, l'aura) à l'instant où la règle mord. Une missive qui se déplierait
## pour expliquer le pat en fin de partie serait fausse de ton. C'est pour ça
## que la livraison ne se fait qu'à UN endroit : l'entrée du village.
##
## ⚠️ UN CALQUE, PAS UN ÉCRAN. La maquette (510:2 et 510:7) montre le village
## derrière, assombri : la lettre se pose PAR-DESSUS l'écran courant, comme
## `GuidePopup`. C'est ce qui donne le fond gratuitement, et ce qui évite
## d'ajouter une route et un décor à charger. Le gabarit est celui de
## `GuidePopup.show_once` : une fabrique statique, un parent, et l'écran
## appelant n'a rien d'autre à savoir.
##
## LES DEUX TEMPS, relevés sur les timelines de la maquette :
##
##   1. FERMÉE (510:2, 2,5 s) - le voile passe de 1 à 0,6 ; l'enveloppe surgit
##      de l'échelle 0,3 avec un ressort ; l'invite « Appuyez pour ouvrir »
##      arrive en dernier. L'écran entier attend le doigt.
##   2. OUVERTE (510:7, 4 s) - le parchemin arrive de 0,7 ; le texte monte en
##      opacité lentement ; le bouton CONTINUER monte de 20 points en dernier.
##

const ENVELOPE_PATH := "res://assets/story/letter_envelope.png"
const PARCHMENT_PATH := "res://assets/story/letter_parchment.png"

signal closed

## Géométrie relevée sur les deux frames, en points de la référence 393 x 852.
##
## ⚠️ TOUT EST ANCRÉ AU CENTRE, jamais posé en absolu. La maquette donne des
## coordonnées depuis le coin haut-gauche (enveloppe en 76,5 / 266) ; les
## reporter telles quelles rejouerait le défaut de l'intro, qui laissait
## 85 points de bande nue sur un viewport élargi. On ne garde donc que les
## TAILLES et les écarts AU CENTRE.
const ENVELOPE_SIZE := 240.0
## Centre de l'enveloppe : 266 + 120 = 386, soit 40 points au-dessus du milieu.
const ENVELOPE_OFFSET_Y := -40.0
## L'invite est à 526 du haut, la hauteur du libellé vaut ~17 : centre à 534,5.
const HINT_OFFSET_Y := 108.5

const PARCHMENT_SIZE := Vector2(340.0, 420.0)
## Centre du parchemin : 160 + 210 = 370, soit 56 points au-dessus du milieu.
const PARCHMENT_OFFSET_Y := -56.0
## Le cadre doré est peint DANS l'image : le texte se pose à l'intérieur.
## 30 points de marge latérale (280 de large pour 340), 80 sous le haut pour
## laisser l'ornement à couronne, 40 au-dessus du bas.
const TEXT_INSET_X := 30.0
const TEXT_INSET_TOP := 80.0
const TEXT_INSET_BOTTOM := 40.0
const TEXT_SIZE := 20

const BUTTON_SIZE := Vector2(303.0, 48.0)
## Le bouton est à 640 du haut : centre à 664, soit 238 sous le milieu.
const BUTTON_OFFSET_Y := 238.0

const VEIL_COLOR := Color(0, 0, 0)
const VEIL_CLOSED := 0.60
const VEIL_OPEN := 0.65
const HINT_COLOR := Color("ffd933")
const INK := Color("33261a")
const BUTTON_COLOR := Color("ffd700")
const BUTTON_INK := Color("1a0d00")

var _key: String = ""
var _veil: ColorRect = null
var _envelope: TextureRect = null
var _hint: Label = null
var _parchment: TextureRect = null
var _text: Label = null
var _button: Button = null
var _opened: bool = false
var _catcher: Control = null


# ------------------------------- LA LIVRAISON --------------------------------
#
#  UN SEUL ENDROIT DÉCIDE, et c'est ce qui garantit qu'une lettre ne peut pas
#  arriver au mauvais moment - par-dessus l'écran de défaite, ou en pleine
#  série. `deliver_pending` est appelée à l'entrée du village, dérive les
#  quatre réceptions de l'état courant, et n'en IMPOSE qu'une.
#
#  Livraison hybride, décision du joueur : la première s'impose (sans elle, le
#  chantier ne répond pas à la demande - « pourquoi il hérite des troupes »),
#  les trois autres attendent au Château Royal.


## Les jalons, lus sur `GameState` et nulle part ailleurs.
static func _est_atteint(key: String) -> bool:
	match key:
		Letters.HERITAGE:
			return Game.has_seen_intro()
		Letters.PREMIERE_DAME:
			return Game.units_owned(Balance.DAME) > 0
		Letters.PREMIERE_DEFAITE:
			return Game.stat("defeats") >= 1
		Letters.ELLE_EST_LA:
			return Game.unlocked_battle() >= Balance.CAMPAIGN.size()
	return false


## Enregistre les lettres dont le jalon est franchi, et ouvre celle qui
## s'impose. Rend `true` si un écran s'est ouvert.
##
## ⚠️ LE COURRIER SE REÇOIT MÊME QUAND ON NE L'OUVRE PAS. Une lettre dont le
## jalon est passé pendant que le joueur était ailleurs doit se retrouver dans
## la pile du château, pas être perdue.
static func deliver_pending(parent: Node) -> bool:
	if parent == null or not parent.is_inside_tree():
		return false

	var a_ouvrir := ""
	for key in Letters.ORDRE:
		if not _est_atteint(key):
			continue
		var neuve := Game.receive_letter(key)
		# Seule la première s'impose, et seulement à son arrivée : la rouvrir
		# à chaque retour au village serait une punition.
		if neuve and key == Letters.HERITAGE:
			a_ouvrir = key

	if a_ouvrir.is_empty():
		return false
	open(parent, a_ouvrir)
	return true


## Ouvre une lettre par-dessus `parent`. Utilisée par la livraison et par la
## pile de courrier du Château Royal.
static func open(parent: Node, key: String) -> RoyalLetter:
	if parent == null or not parent.is_inside_tree() or not Letters.exists(key):
		return null
	var letter := RoyalLetter.new()
	parent.add_child(letter)
	letter._build(key)
	return letter


# ------------------------------- CONSTRUCTION --------------------------------

func _build(key: String) -> void:
	_key = key
	name = "RoyalLetter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Au-dessus de tout ce que l'écran d'accueil a déjà posé.
	z_index = 100

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = VEIL_COLOR
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.color.a = 1.0
	add_child(_veil)

	_build_envelope()
	_build_hint()
	_animate_closed()


func _build_envelope() -> void:
	_envelope = TextureRect.new()
	_envelope.name = "Envelope"
	_envelope.texture = UiTheme.texture_or_null(ENVELOPE_PATH)
	_envelope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_envelope.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre(_envelope, Vector2(ENVELOPE_SIZE, ENVELOPE_SIZE), ENVELOPE_OFFSET_Y)
	add_child(_envelope)

	# ⚠️ TOUT L'ÉCRAN OUVRE, PAS SEULEMENT LE CACHET. Le cachet de cire est
	# large et centré, mais viser une cible de 60 points au pouce quand rien
	# d'autre ne réagit fait croire à un écran mort. La maquette rend d'ailleurs
	# la frame entière cliquable - même doctrine que l'intro.
	_catcher = Control.new()
	_catcher.name = "TapCatcher"
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_on_opened())
	add_child(_catcher)


func _build_hint() -> void:
	_hint = UiTheme.make_label("Appuyez pour ouvrir", 14, HINT_COLOR)
	_hint.name = "Hint"
	_hint.add_theme_font_override("font", UiTheme.font_bold())
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hint.offset_left = -160.0
	_hint.offset_right = 160.0
	_hint.offset_top = HINT_OFFSET_Y - 10.0
	_hint.offset_bottom = HINT_OFFSET_Y + 10.0
	_hint.modulate.a = 0.0
	add_child(_hint)


## Pose un contrôle au centre de l'écran, à `decalage_y` du milieu.
##
## Ancres et non coordonnées : c'est la règle 4 du manuel, et c'est ce que
## l'intro avait oublié - la largeur en unités de jeu ne descend jamais sous
## 393, mais elle MONTE, jusqu'à 495 sur un écran court.
func _centre(control: Control, taille: Vector2, decalage_y: float) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER)
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH
	control.offset_left = -taille.x * 0.5
	control.offset_right = taille.x * 0.5
	control.offset_top = decalage_y - taille.y * 0.5
	control.offset_bottom = decalage_y + taille.y * 0.5


# ------------------------------- LE PREMIER TEMPS ----------------------------

## Relevé sur la timeline de 510:2 : le voile s'éclaircit de 1 à 0,6 sur 1,2 s,
## l'enveloppe surgit de l'échelle 0,3 entre 0,8 et 1,6 s avec un ressort
## (cubic-bezier 0.34, 1.56, 0.64, 1), l'invite arrive entre 1,6 et 2,2 s.
func _animate_closed() -> void:
	_envelope.modulate.a = 0.0
	_envelope.scale = Vector2(0.3, 0.3)
	# ⚠️ Le pivot se pose APRÈS la mise en page, jamais à la construction :
	# piège déjà payé sur le bandeau de série et sur le zoom de l'intro.
	_envelope.resized.connect(_center_envelope_pivot)
	_center_envelope_pivot.call_deferred()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_veil, "color:a", VEIL_CLOSED,
		Balance.motion("letter_veil")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var pose := Balance.motion("letter_envelope")
	var apparition := tween.tween_property(_envelope, "modulate:a", 1.0, pose)
	apparition.set_delay(Balance.motion("letter_envelope_delay"))
	var ressort := tween.tween_property(_envelope, "scale", Vector2.ONE, pose)
	ressort.set_delay(Balance.motion("letter_envelope_delay"))
	ressort.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var invite := tween.tween_property(_hint, "modulate:a", 1.0,
		Balance.motion("letter_hint"))
	invite.set_delay(Balance.motion("letter_envelope_delay") + pose)
	invite.set_trans(Tween.TRANS_SINE)


func _center_envelope_pivot() -> void:
	if is_instance_valid(_envelope):
		_envelope.pivot_offset = _envelope.size * 0.5


# ------------------------------- LE SECOND TEMPS -----------------------------

func _on_opened() -> void:
	if _opened:
		return
	_opened = true
	Game.mark_letter_read(_key)

	if is_instance_valid(_catcher):
		_catcher.queue_free()
		_catcher = null

	var sortie := create_tween()
	sortie.set_parallel(true)
	sortie.tween_property(_envelope, "modulate:a", 0.0,
		Balance.motion("letter_seal")).set_trans(Tween.TRANS_SINE)
	sortie.tween_property(_envelope, "scale", Vector2(1.15, 1.15),
		Balance.motion("letter_seal")).set_trans(Tween.TRANS_SINE)
	sortie.tween_property(_hint, "modulate:a", 0.0,
		Balance.motion("letter_seal")).set_trans(Tween.TRANS_SINE)
	sortie.tween_property(_veil, "color:a", VEIL_OPEN,
		Balance.motion("letter_seal")).set_trans(Tween.TRANS_SINE)
	await sortie.finished
	if not is_instance_valid(self):
		return

	_build_parchment()
	_animate_open()


func _build_parchment() -> void:
	_parchment = TextureRect.new()
	_parchment.name = "Parchment"
	_parchment.texture = UiTheme.texture_or_null(PARCHMENT_PATH)
	_parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# La maquette pose l'image en `object-cover` : elle remplit les 340 x 420
	# et déborde en haut et en bas plutôt que de se déformer. Le parchemin a
	# déjà ses coins transparents, donc rien ne dépasse visiblement.
	_parchment.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_parchment.clip_contents = true
	_parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre(_parchment, PARCHMENT_SIZE, PARCHMENT_OFFSET_Y)
	add_child(_parchment)

	_text = UiTheme.make_label(Letters.body(_key), TEXT_SIZE, INK)
	_text.name = "Body"
	# La voix du Roi a sa propre écriture dans ce jeu - c'est déjà elle qui
	# parle dans la bulle de l'intro. La maquette demande ici Poppins Medium,
	# une graisse que le jeu n'embarque pas et qu'il faudrait ajouter pour un
	# seul écran ; Comic Relief dit la même chose et elle est déjà là.
	_text.add_theme_font_override("font", UiTheme.font_dialogue())
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = TEXT_INSET_X
	_text.offset_right = -TEXT_INSET_X
	_text.offset_top = TEXT_INSET_TOP
	_text.offset_bottom = -TEXT_INSET_BOTTOM
	_text.modulate.a = 0.0
	# Enfant du parchemin : le texte suit le cadre doré, quoi qu'il arrive à
	# la mise en page.
	_parchment.add_child(_text)
	_text.resized.connect(_ajuster_au_cadre)
	_ajuster_au_cadre.call_deferred()

	_build_button()


## GARDE-FOU : une lettre trop longue ne sort pas du parchemin, elle rapetisse.
##
## Le parchemin ne défile pas - c'est ce qui lui permet d'être une image et non
## une boîte. Une lettre retouchée d'une phrase de trop passerait donc par
## dessus le cadre doré sans que rien ne le signale. On réduit la police
## jusqu'à ce que le texte rentre, en s'arrêtant à 13 : en dessous, le vrai
## problème est le texte, et le banc doit le dire plutôt que de le cacher.
const TEXT_SIZE_MIN := 13


func _ajuster_au_cadre() -> void:
	if not is_instance_valid(_text):
		return
	var largeur: float = _text.size.x
	var hauteur: float = _text.size.y
	if largeur <= 0.0 or hauteur <= 0.0:
		return
	var police: Font = _text.get_theme_font("font")
	for taille in range(TEXT_SIZE, TEXT_SIZE_MIN - 1, -1):
		var mesure := police.get_multiline_string_size(_text.text,
			HORIZONTAL_ALIGNMENT_CENTER, largeur, taille,
			-1, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)
		if mesure.y <= hauteur:
			_text.add_theme_font_size_override("font_size", taille)
			return
	_text.add_theme_font_size_override("font_size", TEXT_SIZE_MIN)
	push_warning("Missive '%s' : le texte deborde du parchemin meme a %d points."
		% [_key, TEXT_SIZE_MIN])


func _build_button() -> void:
	_button = UiTheme.make_button("CONTINUER", BUTTON_COLOR, 16)
	_button.name = "Continue"
	_button.add_theme_font_override("font", UiTheme.font_bold())
	_button.add_theme_color_override("font_color", BUTTON_INK)
	var box := StyleBoxFlat.new()
	box.bg_color = BUTTON_COLOR
	box.set_corner_radius_all(12)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var etat := box.duplicate()
		if state == "hover":
			etat.bg_color = BUTTON_COLOR.lightened(0.12)
		elif state == "pressed":
			etat.bg_color = BUTTON_COLOR.darkened(0.18)
		_button.add_theme_stylebox_override(state, etat)
	_centre(_button, BUTTON_SIZE, BUTTON_OFFSET_Y)
	_button.modulate.a = 0.0
	_button.pressed.connect(_on_continue)
	UiTheme.press_feedback(_button)
	add_child(_button)


## Relevé sur la timeline de 510:7 : le parchemin arrive de l'échelle 0,7 sur
## 0,8 s ; le texte monte en opacité de 0,6 à 2,5 s ; le bouton arrive en
## dernier, de 20 points plus bas, entre 3,0 et 3,6 s.
##
## ⚠️ LE TEXTE NE S'ÉCRIT PAS LETTRE PAR LETTRE, contrairement à l'intro. La
## maquette demande un fondu, et à 0,032 s par caractère la frappe de ces
## deux cents signes prendrait six secondes - le joueur aurait fini de lire
## avant la fin de l'animation.
func _animate_open() -> void:
	_parchment.modulate.a = 0.0
	_parchment.scale = Vector2(0.7, 0.7)
	_parchment.resized.connect(_center_parchment_pivot)
	_center_parchment_pivot.call_deferred()

	var tween := create_tween()
	tween.set_parallel(true)

	var arrivee := Balance.motion("letter_parchment")
	tween.tween_property(_parchment, "modulate:a", 1.0, arrivee) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_parchment, "scale", Vector2.ONE, arrivee) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var lecture := tween.tween_property(_text, "modulate:a", 1.0,
		Balance.motion("letter_text"))
	lecture.set_delay(Balance.motion("letter_text_delay"))
	lecture.set_trans(Tween.TRANS_SINE)

	var attente := Balance.motion("letter_button_delay")
	var monte := tween.tween_property(_button, "modulate:a", 1.0,
		Balance.motion("letter_button"))
	monte.set_delay(attente)
	monte.set_trans(Tween.TRANS_SINE)

	# Le bouton MONTE de 20 points en arrivant. Il n'est dans aucun conteneur,
	# donc animer sa position est licite ici - ce ne l'est pas dans un
	# VBoxContainer, où le tween se bat avec la mise en page.
	var arrivee_y: float = _button.offset_top
	_button.offset_top = arrivee_y + 20.0
	_button.offset_bottom = _button.offset_bottom + 20.0
	var glissement := tween.tween_property(_button, "offset_top", arrivee_y,
		Balance.motion("letter_button"))
	glissement.set_delay(attente)
	glissement.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var glissement2 := tween.tween_property(_button, "offset_bottom",
		arrivee_y + BUTTON_SIZE.y, Balance.motion("letter_button"))
	glissement2.set_delay(attente)
	glissement2.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _center_parchment_pivot() -> void:
	if is_instance_valid(_parchment):
		_parchment.pivot_offset = _parchment.size * 0.5


func _on_continue() -> void:
	closed.emit()
	queue_free()


## Raccourci pour les bancs et les captures : ouvre la lettre sans passer par
## un vrai clic, comme `king_intro_dialogue.skip_approach`.
func open_now() -> void:
	_on_opened()
