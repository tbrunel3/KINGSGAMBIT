extends Control
##
## L'ECRAN DE LA MISSIVE - une enveloppe scellee qui se deplie en parchemin.
##
## Le support est une decision du joueur (cf. chantier_i_missives.md) : le Roi
## n'a pas de corps dans ce jeu - il est sur son trone a l'intro et plus jamais.
## Une lettre dit exactement la bonne chose : il n'est pas la, mais il te suit.
##
## Sequence : l'enveloppe se pose -> le doigt touche le cachet -> le sceau se
## brise -> le parchemin se deplie en TROIS TEMPS -> le texte s'ecrit bloc par
## bloc -> le bouton de sortie se debloque.
##
## ⚠️ POURQUOI TROIS TRANCHES ET PAS UNE IMAGE QUI GRANDIT. Le pli est deja
## PEINT dans l'illustration : deux plissures horizontales avec leur ombre, a
## 39,5 % et 65,4 % de la hauteur (mesurees a la pixel, pas estimees). Chaque
## tranche se deroule depuis le creux peint au-dessus d'elle, et les ombres
## deviennent les charnieres. Une image qui grandit d'un bloc ecraserait les
## plis en meme temps que le texte.
##
## ⚠️ ET LE TEXTE NE COULE PAS D'UNE TRANCHE A L'AUTRE. S'il traversait les
## plissures, les ombres de pli tomberaient en plein milieu des lignes. D'ou
## trois blocs - adresse, corps, signature - un par panneau (cf. Letters).
##
## ⚠️ LES DEUX PNG PEUVENT MANQUER, ET L'ECRAN DOIT TENIR QUAND MEME. Ils sont
## fournis par le graphiste et n'etaient pas encore dans le depot quand cet
## ecran a ete ecrit. Sans eux, le parchemin et l'enveloppe se DESSINENT - meme
## geometrie, meme decoupe, meme animation. Ce n'est pas un placeholder qu'on
## oubliera dans `assets/` : c'est un repli qui vit dans le code, et poser les
## PNG suffit a le remplacer.
##

const PARCHMENT_PATH := "res://assets/story/letter_parchment.png"
const ENVELOPE_PATH := "res://assets/story/letter_envelope.png"

# ------------------------------- LES MESURES ---------------------------------
#
#  Toutes relevees sur les fichiers du graphiste avec PIL, pas a l'oeil (cf.
#  chantier_i_missives.md, "Les deux assets, mesures").

## Rapport largeur/hauteur de la ZONE OPAQUE du parchemin (1040 x 1418).
const PARCHMENT_RATIO := 0.733

## Les deux plissures peintes, en part de la hauteur. Ce sont elles qui
## decoupent les trois tranches.
const FOLD_HIGH := 0.395
const FOLD_LOW := 0.654

## Marge laterale a l'INTERIEUR du filet d'or, en part de la largeur.
##
## ⚠️ NE PAS LA REMESURER SUR LE PREMIER PIXEL NON DORE. Le parchemin a un
## lisere creme AVANT le filet d'or : un scan naif rend 3,1 % au lieu de 8,5 %,
## et le texte irait mordre l'ornement. Le relevé se fait sur le DERNIER pixel
## dore du premier quart de la ligne.
const SIDE_MARGIN := 0.085

## Le texte ne peut pas commencer plus haut : l'ornement a couronne occupe le
## sommet du premier panneau.
const TOP_ORNAMENT := 0.133

## L'enveloppe est en PAYSAGE (1159 x 977 de zone opaque), et son cachet de cire
## est centre a 53,5 % / 53,5 % - large, donc cible au pouce sans discussion.
const ENVELOPE_RATIO := 1.19
const SEAL_X := 0.535
const SEAL_Y := 0.535
const SEAL_SHARE := 0.22   ## diametre du cachet, en part de la largeur

## Part de la largeur utile que prend la lettre. Elle ne colle pas les bords :
## une lettre posee sur une table a de l'air autour.
const WIDTH_SHARE := 0.92

# ------------------------------- LES TEMPS -----------------------------------

const SEAL_BREAK := 0.35
const PANEL_TIME := 0.42
const PANEL_STAGGER := 0.22
const TEXT_TIME := 0.5

const CREAM := Color("f4e8cf")
const INK := Color("2f2113")
const INK_SOFT := Color("6b533a")
const GOLD := Color("c9a227")
const WAX := Color("8e2b20")

var key: String = ""
var _stage: Control
var _foot: MarginContainer
var _envelope: Control
var _seal: Control
var _panels: Array[Control] = []
var _labels: Array[Label] = []
var _exit: Button
var _opened := false


func _ready() -> void:
	_stage = get_node("Safe/Root/Stage")
	_foot = get_node("Safe/Root/Foot")
	key = Router.current_letter if Router.current_letter != "" else Letters.HERITAGE

	_build_envelope()
	_build_parchment()
	_build_exit()
	# ⚠️ APRES la mise en page, jamais a la construction : un pivot pose avant
	# que le conteneur ait donne sa taille reste a (0,0), et la tranche se
	# deroule depuis le coin de l'ecran. C'est ce qui avait colle le bandeau de
	# serie en haut.
	await get_tree().process_frame
	_place()
	get_tree().get_root().size_changed.connect(_place)
	_animate_envelope()


# ------------------------------- L'ENVELOPPE ---------------------------------

func _build_envelope() -> void:
	_envelope = Control.new()
	_envelope.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var drawn := _Sheet.new()
		drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_envelope.add_child(drawn)

	# LE CACHET DE CIRE. C'est lui qu'on touche, et il decide au RELACHEMENT :
	# l'ecran n'a rien a faire defiler, mais un doigt qui glisse hors du cachet
	# doit pouvoir annuler (cf. UiTheme.on_tap).
	_seal = _Seal.new()
	_envelope.add_child(_seal)
	UiTheme.on_tap(_seal, _open)


# ------------------------------- LE PARCHEMIN --------------------------------

## Les trois tranches, decoupees sur les plissures peintes.
func _build_parchment() -> void:
	var art := UiTheme.texture_or_null(PARCHMENT_PATH)
	var cuts := [0.0, FOLD_HIGH, FOLD_LOW, 1.0]
	var blocks := Letters.blocks(key)

	for i in range(3):
		var panel := Control.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.clip_contents = true
		panel.visible = false
		_stage.add_child(panel)
		_panels.append(panel)

		if art != null:
			var slice := TextureRect.new()
			slice.texture = AtlasTexture.new()
			var atlas: AtlasTexture = slice.texture
			atlas.atlas = art
			var top: float = art.get_height() * float(cuts[i])
			var bottom: float = art.get_height() * float(cuts[i + 1])
			atlas.region = Rect2(0, top, art.get_width(), bottom - top)
			slice.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slice.stretch_mode = TextureRect.STRETCH_SCALE
			slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.add_child(slice)
		else:
			var drawn := _Sheet.new()
			drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel.add_child(drawn)

		var label := UiTheme.make_label(
			String(blocks[i]) if i < blocks.size() else "",
			15 if i == 1 else 14,
			INK if i == 1 else INK_SOFT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i != 1 \
			else HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.modulate.a = 0.0
		panel.add_child(label)
		_labels.append(label)


func _build_exit() -> void:
	_exit = UiTheme.make_button("REPLIER LA LETTRE", UiTheme.GOLD_BUTTON, 14)
	_exit.disabled = true
	_exit.modulate.a = 0.0
	_exit.pressed.connect(_close)
	_foot.add_child(_exit)


# ------------------------------- LA GEOMETRIE --------------------------------

## Pose l'enveloppe et les trois tranches. ANCRE, jamais en absolu : un ecran
## cale sur 852 points se decale des que l'appareil en fait 880 (regle 4).
func _place() -> void:
	if _stage == null or not is_instance_valid(_stage):
		return
	var space := _stage.size
	if space.x <= 0.0 or space.y <= 0.0:
		return

	# LE PARCHEMIN : aussi large que la place le permet, borne par la hauteur.
	var width: float = space.x * WIDTH_SHARE
	var height: float = width / PARCHMENT_RATIO
	if height > space.y:
		height = space.y
		width = height * PARCHMENT_RATIO
	var left: float = (space.x - width) * 0.5
	var top: float = (space.y - height) * 0.5

	var cuts := [0.0, FOLD_HIGH, FOLD_LOW, 1.0]
	for i in range(_panels.size()):
		var panel := _panels[i]
		var y0: float = height * float(cuts[i])
		var y1: float = height * float(cuts[i + 1])
		panel.position = Vector2(left, top + y0)
		panel.size = Vector2(width, y1 - y0)
		# Le pivot en HAUT de la tranche : elle se deroule depuis le creux peint
		# au-dessus d'elle, pas depuis son milieu.
		panel.pivot_offset = Vector2(width * 0.5, 0.0)

		var pad_x: float = width * SIDE_MARGIN
		var pad_top: float = (height * TOP_ORNAMENT) if i == 0 else (panel.size.y * 0.12)
		var label := _labels[i]
		label.position = Vector2(pad_x, pad_top)
		label.size = Vector2(width - pad_x * 2.0,
			maxf(0.0, panel.size.y - pad_top - panel.size.y * 0.10))

	# L'ENVELOPPE : en paysage, centree, un peu plus petite que le parchemin.
	var env_w: float = minf(space.x * WIDTH_SHARE, space.y * ENVELOPE_RATIO * 0.6)
	var env_h: float = env_w / ENVELOPE_RATIO
	_envelope.position = Vector2((space.x - env_w) * 0.5, (space.y - env_h) * 0.5)
	_envelope.size = Vector2(env_w, env_h)
	_envelope.pivot_offset = _envelope.size * 0.5

	var seal_size: float = env_w * SEAL_SHARE
	_seal.size = Vector2(seal_size, seal_size)
	_seal.position = Vector2(env_w * SEAL_X - seal_size * 0.5,
		env_h * SEAL_Y - seal_size * 0.5)
	_seal.pivot_offset = _seal.size * 0.5


# ------------------------------- LES TEMPS -----------------------------------

func _animate_envelope() -> void:
	_envelope.modulate.a = 0.0
	_envelope.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_envelope, "modulate:a", 1.0, 0.35)
	tween.tween_property(_envelope, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Le sceau se brise, puis le parchemin se deroule en trois temps.
func _open() -> void:
	if _opened:
		return
	_opened = true
	Game.mark_letter_read(key)

	var tween := create_tween()
	tween.tween_property(_seal, "scale", Vector2(1.25, 1.25), SEAL_BREAK * 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_seal, "modulate:a", 0.0, SEAL_BREAK)
	tween.tween_property(_envelope, "modulate:a", 0.0, SEAL_BREAK * 0.6)
	tween.tween_callback(_unfold)


func _unfold() -> void:
	_envelope.visible = false
	var tween := create_tween().set_parallel(true)
	for i in range(_panels.size()):
		var panel := _panels[i]
		panel.visible = true
		panel.scale = Vector2(1.0, 0.0)
		var start: float = PANEL_STAGGER * float(i)
		tween.tween_property(panel, "scale", Vector2.ONE, PANEL_TIME) \
			.set_delay(start).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# Le texte n'apparait qu'une fois SON panneau deroule : ecrit plus tot,
		# il se lirait sur une tranche encore ecrasee.
		tween.tween_property(_labels[i], "modulate:a", 1.0, TEXT_TIME) \
			.set_delay(start + PANEL_TIME)
	var last: float = PANEL_STAGGER * float(_panels.size() - 1) + PANEL_TIME + TEXT_TIME
	tween.tween_property(_exit, "modulate:a", 1.0, 0.3).set_delay(last)
	tween.chain().tween_callback(func() -> void: _exit.disabled = false)


func _close() -> void:
	Game.mark_letter_read(key)
	if Router.letter_return == Router.RETURN_CASTLE:
		Router.goto_castle()
	else:
		Router.goto_village()


# ------------------------------- LE REPLI DESSINE ----------------------------

## Le papier, quand le PNG n'est pas la : creme, filet d'or, coins arrondis.
## Meme rectangle, donc meme geometrie a mesurer - c'est ce qui permet de
## verifier le depli et les huit formats sans attendre les images.
class _Sheet extends Control:
	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("f4e8cf")
		box.border_color = Color("c9a227")
		box.set_border_width_all(2)
		draw_style_box(box, Rect2(Vector2.ZERO, size))


## Le cachet de cire : un disque, son liseré, et la couronne brisee au centre.
class _Seal extends Control:
	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		var c := size * 0.5
		draw_circle(c, r, Color("8e2b20"))
		draw_arc(c, r * 0.86, 0.0, TAU, 48, Color("5e1a12"), 2.0)
		# Deux traits croises : une empreinte, pas un glyphe - aucune icone du
		# jeu ne porte de sceau, et un emoji rend en tofu a l'export Web.
		var arm: float = r * 0.42
		draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), Color("d8a08f"), 2.0)
		draw_line(c - Vector2(0, arm), c + Vector2(0, arm), Color("d8a08f"), 2.0)
