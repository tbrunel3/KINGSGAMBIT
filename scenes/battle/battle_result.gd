class_name BattleResult
extends Control
##
## ECRAN DE RESULTAT - victoire et defaite, repris des maquettes V2.
##
## Ce n'est plus une modale posee sur le plateau assombri mais un ECRAN PLEIN :
## l'illustration occupe tout le cadre (la taverne pavoisee en victoire, le
## camp sous la pluie en defaite), le mot VICTOIRE / DEFAITE est une image
## gravee, et tout le reste - le bilan, les boutons - tient sur des plaques
## royales ancrees en bas.
##
## Les deux issues partagent exactement la meme construction : seule change la
## "peau" (fond, bordures, degrades, accents), decrite dans _skin. C'est la
## maquette elle-meme qui est batie ainsi - le panneau de defaite est le
## panneau de victoire repeint en rouge.
##
## Le CONTENU du bilan, lui, vient de la bataille jouee : la maquette montre
## trois lignes d'exemple, le jeu en affiche autant qu'il en a (aura des
## Dames, Dames ramenees au Chateau Royal, Dame offerte par la campagne).
##
## Usage :
##   var screen := BattleResult.new()
##   add_child(screen)
##   screen.open(true)
##   screen.add_reward_row("Récompense totale", 450)
##   screen.add_stat_row("Ennemis vaincus", "11")
##   screen.add_primary_button("BATAILLE SUIVANTE", func(): ...)
##

const VICTORY_BG_PATH := "res://assets/results/victory_bg.jpg"
const VICTORY_TITLE_PATH := "res://assets/results/victory_title.png"
const DEFEAT_BG_PATH := "res://assets/results/defeat_bg.jpg"
## Le nul a desormais son propre champ de bataille - gris, sans le ciel chaud
## de la victoire - et son propre mot grave (Figma 348:2). Il empruntait ceux
## de la victoire faute d'avoir jamais ete dessine.
const DRAW_BG_PATH := "res://assets/results/draw_bg.jpg"
const DRAW_TITLE_PATH := "res://assets/results/draw_title.png"
const DEFEAT_TITLE_PATH := "res://assets/results/defeat_title.png"
const COIN_PATH := "res://assets/ui/kg_coin.png"
const SAFE_AREA_SCRIPT := "res://scripts/ui/safe_area.gd"

## Le mot grave est exporte a 340 x 136 dans la maquette (Victoire-PNG).
const TITLE_SIZE := Vector2(340, 136)
## Largeur du filet ornemental sous le titre (Ornament, 260 points).
const ORNAMENT_WIDTH := 260.0

## Confettis de la maquette (Frame 190:7 a 190:18), en coordonnees du cadre de
## reference 393 x 852 : centre x, centre y, largeur, hauteur, rotation en
## degres, teinte, opacite. Ils sont FIXES et non simules - la maquette les a
## poses un par un, et une nappe de particules coute cher sur mobile.
const CONFETTI := [
	[36.4, 85.1, 8.0, 18.0, -35.0, "3b66ff", 0.90],
	[60.2, 147.6, 6.0, 14.0, 22.0, "ffd700", 0.85],
	[337.3, 99.5, 8.0, 18.0, 40.0, "3b66ff", 0.90],
	[315.2, 160.6, 6.0, 14.0, -20.0, "ffd700", 0.80],
	[91.3, 63.6, 7.0, 16.0, 15.0, "5588ff", 0.75],
	[361.0, 62.5, 5.0, 12.0, -45.0, "ffd700", 0.90],
	[14.1, 207.6, 6.0, 14.0, 30.0, "ffd700", 0.70],
	[376.6, 225.8, 7.0, 16.0, -25.0, "3b66ff", 0.80],
	[175.0, 49.7, 8.0, 8.0, 45.0, "ffd700", 0.90],
	[213.5, 43.5, 5.0, 12.0, -10.0, "5588ff", 0.80],
	[131.1, 74.1, 6.0, 6.0, 30.0, "ffd700", 0.85],
	[269.5, 67.7, 8.0, 18.0, -50.0, "3b66ff", 0.75],
]

## Etincelles (spark-1 a spark-4) : de simples disques d'or.
const SPARKS := [
	[155.0, 88.0, 2.5], [236.0, 72.0, 2.0], [78.0, 180.0, 2.0], [320.0, 185.0, 2.5],
]

const REFERENCE_WIDTH := 393.0

var _skin: Dictionary = {}
var _title_text: String = ""
var _stats: VBoxContainer
var _buttons: VBoxContainer
var _actions_row: HBoxContainer
## Cibles de l'animation d'entree (cf. _animate_entry).
var _bg_image: TextureRect
var _title_block: Control
var _stats_block: Control
var _vignettes: Array[Control] = []


static func victory_skin() -> Dictionary:
	return {
		"bg": VICTORY_BG_PATH,
		"title": VICTORY_TITLE_PATH,
		"tint": Color("0b1225", 0.28),
		"vignette_top": Color("0b1225", 0.69),
		"vignette_bottom": Color("05060a", 0.94),
		"glow": Color("ffd700", 0.56),
		"edge": Color("ffe680"),
		"plate": PackedColorArray([Color("1e3278"), Color("0a1230"), Color("0e1a40")]),
		"inner_outline": Color("ffd700", 0.31),
		"diamond": Color("3a7fe8"),
		"diamond_edge": Color("c8960c"),
		"shell": PackedColorArray([
			Color("ffe680"), Color("c8960c"), Color("8b6200"), Color("c8960c")]),
		"shell_inner_edge": Color("ffd700", 0.25),
		"action": PackedColorArray([Color("12213e"), Color("0a1230")]),
		"label": Color("c8a84b"),
		"text": Color("ffd700"),
		"separator": Color(1, 1, 1, 0.06),
		"bullets": [Color("3b66ff"), Color("5588ff")],
		"highlight_row": Color(0, 0, 0, 0),
		"ornament_line": Color("d4af37", 0.7),
		"ornament_jewel": Color("ffd700"),
		"cta_inner": PackedColorArray([
			Color("1e3278"), Color("0a1230"), Color("0e1a40")]),
		"confetti": true,
		"entry": "win",
	}


static func defeat_skin() -> Dictionary:
	return {
		"bg": DEFEAT_BG_PATH,
		"title": DEFEAT_TITLE_PATH,
		"tint": Color("0b0608", 0.22),
		"vignette_top": Color("1a0508", 0.75),
		"vignette_bottom": Color("060204", 0.94),
		"glow": Color("ff3b30", 0.56),
		"edge": Color("ff6b6b"),
		"plate": PackedColorArray([Color("2a0a0a"), Color("150305"), Color("1a0508")]),
		"inner_outline": Color("ff3b30", 0.25),
		"diamond": Color("8b1a1a"),
		"diamond_edge": Color("c0392b"),
		"shell": PackedColorArray([
			Color("ff6b6b"), Color("c0392b"), Color("8b1a1a"), Color("c0392b")]),
		"shell_inner_edge": Color("ff3b30", 0.25),
		"action": PackedColorArray([Color("1a0a0a"), Color("100305")]),
		"label": Color("c0392b"),
		"text": Color("ff6b6b"),
		"separator": Color("ff3b30", 0.15),
		"bullets": [Color("c0392b"), Color("8b6060")],
		"highlight_row": Color("ff3b30", 0.06),
		"ornament_line": Color("c0392b", 0.7),
		"ornament_jewel": Color("ff3b30"),
		"cta_inner": PackedColorArray([
			Color("3d0a0a"), Color("1a0305"), Color("2a0608")]),
		"confetti": false,
		"entry": "loss",
	}


## Peau du MATCH NUL : celle de la victoire, sans les confettis et sans le
## grand lettrage. Rien a feter, rien a pleurer - le decor reste le meme,
## c'est le ton qui change.
static func draw_skin() -> Dictionary:
	var skin := victory_skin()
	skin["confetti"] = false
	skin["entry"] = "draw"
	skin["bg"] = DRAW_BG_PATH
	skin["title"] = DRAW_TITLE_PATH
	skin["glow"] = Color("c9d3e6", 0.34)
	skin["tint"] = Color("0b1225", 0.30)
	# Teintes RELEVEES sur la frame, pas approchees a l'oeil : la plaque du nul
	# n'est pas un bleu desature, c'est un gris franc (#1f242e cercle de
	# #8b9097), et les boutons sont en acier plutot qu'en or.
	skin["edge"] = Color("8b9097")
	skin["plate"] = PackedColorArray([
		Color("1f242e"), Color("1f242e"), Color("1f242e")])
	skin["inner_outline"] = Color("59616b", 0.5)
	skin["diamond"] = Color("59616b")
	skin["diamond_edge"] = Color("666e78")
	skin["text"] = Color("c9d3e6")
	skin["label"] = Color("8b9097")
	skin["separator"] = Color("c9d3e6", 0.08)
	skin["bullets"] = [Color("808791"), Color("59616b")]
	skin["highlight_row"] = Color("808791", 0.15)
	skin["shell"] = PackedColorArray([Color("afaeb3")])
	skin["shell_inner_edge"] = Color("24242a")
	skin["action"] = PackedColorArray([Color("52535c"), Color("3c3d45")])
	skin["cta_inner"] = PackedColorArray([Color("52535c"), Color("3c3d45")])
	skin["ornament_line"] = Color("c9d3e6", 0.6)
	skin["ornament_jewel"] = Color("c9d3e6")
	return skin


# ------------------------------- CONSTRUCTION --------------------------------

## Monte l'ecran : fond, vignettes, confettis, titre grave, plaque de bilan
## vide et pile de boutons vide. Les lignes et les boutons s'ajoutent ensuite.
## `title_text` remplace le mot grave par une plaque de titre ecrite. Sert aux
## combats intermediaires d'une serie ("COMBAT 2 SUR 3") : ceux-la ne meritent
## pas le grand lettrage de la victoire, qui doit rester pour la fin.
func open(victory: bool, title_text: String = "") -> void:
	_open(victory_skin() if victory else defeat_skin(), title_text)


## Match nul : ni victoire ni defaite, et donc jamais le grand lettrage.
func open_draw(title_text: String) -> void:
	_open(draw_skin(), title_text)


func _open(skin: Dictionary, title_text: String) -> void:
	_skin = skin
	_title_text = title_text
	_entry_key = String(skin.get("entry", "draw"))

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# L'ecran de resultat avale les clics : le plateau reste visible au-dessus
	# du fond mais ne doit plus repondre.
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_background()
	if _skin["confetti"]:
		_build_confetti()

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.set_script(load(SAFE_AREA_SCRIPT))
	safe.set("min_margin_h", 16)
	safe.set("min_margin_bottom", 20)
	add_child(safe)

	# Tout est ancre EN BAS : le bilan et les boutons gardent leur place quel
	# que soit l'allongement de l'ecran, et c'est l'illustration qui respire.
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)

	_title_block = _build_title_block()
	column.add_child(_title_block)
	_stats_block = _build_stats_plate()
	column.add_child(_stats_block)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_buttons)

	_animate_entry.call_deferred()


## LES TROIS ENTREES, une par peau.
##
## ⚠️ ELLES N'EN FAISAIENT QU'UNE, et c'etait une erreur - la mienne, pas celle
## du designer. Le commentaire d'origine disait : "le designer ne l'a dessinee
## qu'une fois". C'etait vrai quand il a ete ecrit, et faux depuis : le releve
## complet du 23/08/2026 a trouve 24 noeuds de mouvement sur la victoire
## (410:5121) et 8 sur la defaite (410:5430), la ou la passation les declarait
## sans aucune donnee. Le jeu leur jouait la timeline du MATCH NUL.
##
## Ce que chacune raconte, et c'est tout le sujet :
##
##   VICTOIRE - le titre JAILLIT du bas, d'une echelle de 0,3, avec un ressort
##              qui depasse a 1,36. Plus rapide que les deux autres (2,5 s).
##   DEFAITE  - le titre TOMBE de 80 points au-dessus, d'une echelle de 1,15,
##              SANS rebond, et tout est plus lent (3,5 s).
##   NUL      - le titre S'ABAT de 1,8, comme un tampon (3 s).
##
## Trois issues, trois lectures. Les aplatir sur une seule faisait lire la meme
## chose a trois fins de bataille differentes.
const ENTRY := {
	"win": {
		"title_scale": 0.3, "title_rise": 60.0, "title_delay": 0.40,
		"title_time": 0.70, "title_trans": Tween.TRANS_ELASTIC,
		"stats_rise": 40.0, "stats_delay": 1.00,
		"buttons_rise": 50.0, "buttons_delay": 1.30,
	},
	"loss": {
		# TRANS_CUBIC et non BACK : la defaite descend et s'arrete. Un rebond
		# lui donnerait de l'entrain.
		"title_scale": 1.15, "title_rise": -80.0, "title_delay": 0.60,
		"title_time": 1.00, "title_trans": Tween.TRANS_CUBIC,
		"stats_rise": 30.0, "stats_delay": 1.60,
		"buttons_rise": 25.0, "buttons_delay": 2.20,
	},
	"draw": {
		"title_scale": 1.8, "title_rise": 0.0, "title_delay": 0.30,
		"title_time": 0.60, "title_trans": Tween.TRANS_BACK,
		"stats_rise": 40.0, "stats_delay": 1.00,
		"buttons_rise": 30.0, "buttons_delay": 1.30,
	},
}

## Quelle peau joue en ce moment. Posee par _open, lue par _animate_entry.
var _entry_key: String = "draw"


## Ce qui est repris : les DECALAGES et les DUREES. La boucle de Figma est un
## artefact d'apercu - l'entree ne se joue qu'une fois (cf. CLAUDE.md).
func _animate_entry() -> void:
	if not is_inside_tree():
		return
	# Le fond arrive de 1,1 : sans pivot centre, il grandirait par le coin.
	for node in [_bg_image, _title_block]:
		if node != null:
			node.pivot_offset = node.size / 2.0

	var tween := create_tween()
	tween.set_parallel(true)

	if _bg_image != null:
		_bg_image.modulate.a = 0.0
		_bg_image.scale = Vector2(1.1, 1.1)
		tween.tween_property(_bg_image, "modulate:a", 1.0, 0.8) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(_bg_image, "scale", Vector2.ONE, 3.0) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	for vignette in _vignettes:
		vignette.modulate.a = 0.0
		tween.tween_property(vignette, "modulate:a", 1.0, 1.0) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var entry: Dictionary = ENTRY.get(_entry_key, ENTRY["draw"])

	if _title_block != null:
		var delay: float = float(entry["title_delay"])
		var seconds: float = float(entry["title_time"])
		var curve: int = int(entry["title_trans"])

		_title_block.modulate.a = 0.0
		_title_block.scale = Vector2.ONE * float(entry["title_scale"])
		tween.tween_property(_title_block, "modulate:a", 1.0, 0.4).set_delay(delay)
		tween.tween_property(_title_block, "scale", Vector2.ONE, seconds).set_delay(delay) \
			.set_ease(Tween.EASE_OUT).set_trans(curve)

		# La victoire monte, la defaite tombe, le nul ne bouge pas : seules les
		# deux premieres ont une translation.
		var rise: float = float(entry["title_rise"])
		if not is_zero_approx(rise):
			_title_block.position.y += rise
			tween.tween_property(_title_block, "position:y",
					_title_block.position.y - rise, seconds).set_delay(delay) \
				.set_ease(Tween.EASE_OUT).set_trans(curve)

	_slide_in(tween, _stats_block, float(entry["stats_rise"]), float(entry["stats_delay"]))
	_slide_in(tween, _buttons, float(entry["buttons_rise"]), float(entry["buttons_delay"]))

	# La pluie ne tombe QUE sur la victoire : c'est la seule peau qui la porte
	# (cf. _skin["confetti"]), et la seule des trois dont la maquette en a.
	if is_instance_valid(_confetti_layer):
		_confetti_progress = 0.0
		var total := float(CONFETTI.size() + SPARKS.size()) * CONFETTI_STAGGER \
			+ CONFETTI_SPAN
		tween.tween_method(_set_confetti_progress, 0.0, 1.0 + total, total)


## Un bloc qui monte a sa place en s'allumant, apres `delay` secondes.
func _slide_in(tween: Tween, node: Control, rise: float, delay: float) -> void:
	if node == null:
		return
	node.modulate.a = 0.0
	node.position.y += rise
	var target := node.position.y - rise
	tween.tween_property(node, "modulate:a", 1.0, 0.5).set_delay(delay)
	tween.tween_property(node, "position:y", target, 0.6).set_delay(delay) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _build_background() -> void:
	var image := TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(_skin["bg"]):
		image.texture = load(_skin["bg"])
	add_child(image)
	_bg_image = image

	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = _skin["tint"]
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	# Vignettes haute et basse de la maquette : le titre se detache du plafond
	# de la taverne, et les plaques du bas reposent sur du noir franc.
	_vignettes.clear()
	for band in [_vignette(_skin["vignette_top"], true, 260.0),
			_vignette(_skin["vignette_bottom"], false, 432.0)]:
		add_child(band)
		_vignettes.append(band)


## Bandeau degrade ancre en haut (`from_top`) ou en bas, opaque du cote de
## l'ancrage et transparent de l'autre.
func _vignette(color: Color, from_top: bool, height: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, color if from_top else Color(color, 0.0))
	gradient.set_color(1, Color(color, 0.0) if from_top else color)

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 128

	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_WIDE if from_top else Control.PRESET_BOTTOM_WIDE)
	if from_top:
		rect.offset_bottom = height
	else:
		rect.offset_top = -height
	return rect


## LES CONFETTIS TOMBENT, ils ne sont plus poses.
##
## Ils existaient deja, mais peints d'un coup a leur position finale : la
## victoire s'ouvrait sur une pluie DEJA tombee. Le releve du 23/08 donne 12
## confettis qui chutent de 135 a 200 points en tournant de ~8 radians a ~0,
## decales de 80 ms, plus 4 etincelles qui eclosent en depassant a 1,8.
##
## Un seul Control qui se redessine, et non douze noeuds : ils sont deja
## dessines au polygone, et douze TextureRect couteraient douze fois plus pour
## le meme resultat.
const CONFETTI_FALL := 190.0
const CONFETTI_STAGGER := 0.08
const CONFETTI_SPAN := 0.85
const CONFETTI_SPIN := 8.0

var _confetti_layer: Control = null
## 0 au depart, 1 quand tout est tombe. Le dessin lit cette seule valeur.
var _confetti_progress: float = 0.0


func _build_confetti() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(_draw_confetti.bind(layer))
	add_child(layer)
	_confetti_layer = layer


## Avancement d'une piece, entre 0 et 1, une fois son decalage passe.
func _confetti_phase(index: int) -> float:
	var start := float(index) * CONFETTI_STAGGER
	return clampf((_confetti_progress - start) / CONFETTI_SPAN, 0.0, 1.0)


func _set_confetti_progress(value: float) -> void:
	_confetti_progress = value
	if is_instance_valid(_confetti_layer):
		_confetti_layer.queue_redraw()


## Les confettis sont poses en coordonnees du cadre de reference : on les
## etale horizontalement avec la largeur reelle (un ecran plus large ne doit
## pas les tasser a gauche), mais on garde leur hauteur telle quelle - ils
## tombent du haut de l'ecran, pas du milieu.
func _draw_confetti(layer: Control) -> void:
	var scale_x := layer.size.x / REFERENCE_WIDTH
	for index in range(CONFETTI.size()):
		var piece: Array = CONFETTI[index]
		var phase := _confetti_phase(index)
		if phase <= 0.0:
			continue
		# Ralenti en fin de course : la courbe Figma est un "ease", pas une
		# chute libre - un confetti qui arrive a pleine vitesse a l'air de
		# tomber au sol plutot que de se poser.
		var eased := 1.0 - pow(1.0 - phase, 3.0)
		var center := Vector2(float(piece[0]) * scale_x,
			float(piece[1]) - CONFETTI_FALL * (1.0 - eased))
		var half := Vector2(float(piece[2]), float(piece[3])) / 2.0
		var color := Color(piece[5])
		color.a = float(piece[6]) * minf(phase * 4.0, 1.0)
		var spin := CONFETTI_SPIN * (1.0 - eased)
		layer.draw_set_transform(center, deg_to_rad(float(piece[4])) + spin, Vector2.ONE)
		layer.draw_colored_polygon(
			RoyalPlate.rounded_rect(Rect2(-half, half * 2.0), 2.0), color)
	layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for index in range(SPARKS.size()):
		var spark: Array = SPARKS[index]
		# Les etincelles partent APRES les confettis, et elles depassent a 1,8
		# avant de revenir - c'est ce qui les fait scintiller plutot que grandir.
		var phase := _confetti_phase(CONFETTI.size() + index)
		if phase <= 0.0:
			continue
		var pop := 1.8 * sin(phase * PI) + phase
		layer.draw_circle(
			Vector2(float(spark[0]) * scale_x, float(spark[1])),
			float(spark[2]) * minf(pop, 1.8), Color("ffd700", 0.9 * phase))


## Le mot grave (une image : c'est un lettrage dessine, pas du texte) pose sur
## son halo, et le filet ornemental de la maquette juste dessous.
func _build_title_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not _title_text.is_empty():
		block.add_child(_written_title())
		block.add_child(_ornament())
		return block

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, TITLE_SIZE.y)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(frame)

	# Halo : la maquette pose une ombre portee lumineuse autour du mot. Un
	# flou n'existe pas en 2D dans Godot - on le refait en degrade radial
	# additif, comme les halos du village (cf. CLAUDE.md).
	var glow := TextureRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -60
	glow.offset_right = 60
	glow.offset_top = -34
	glow.offset_bottom = 34
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture = _radial_glow(_skin["glow"])
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	frame.add_child(glow)

	var word := TextureRect.new()
	word.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	word.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(_skin["title"]):
		word.texture = load(_skin["title"])
	frame.add_child(word)

	block.add_child(_ornament())
	return block


func _ornament() -> Control:
	var ornament := Control.new()
	ornament.custom_minimum_size = Vector2(0, 12)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.draw.connect(_draw_ornament.bind(ornament))
	return ornament


## Titre ecrit des etapes intermediaires : une plaque royale sertie de son
## losange, comme les bandeaux de la preparation.
func _written_title() -> RoyalPlate:
	var plate := _plate(_skin["edge"], 3.0, 14.0, _skin["plate"])
	plate.set_padding(20, 14, 20, 14)
	plate.inner_outline_color = _skin["inner_outline"]
	plate.inner_radius = 9.0
	plate.ornament_color = _skin["diamond"]
	plate.ornament_border = _skin["diamond_edge"]
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var label := _engraved(_title_text, 22, _skin["text"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(label)
	return plate


## Filet du titre : deux traits de 60 points aux extremites d'une largeur de
## 260, chacun ponctue d'un petit losange vers l'interieur (Ornament, 193:5).
func _draw_ornament(node: Control) -> void:
	var width := minf(ORNAMENT_WIDTH, node.size.x)
	var left := (node.size.x - width) / 2.0
	var y := node.size.y / 2.0
	var line: Color = _skin["ornament_line"]

	node.draw_line(Vector2(left, y), Vector2(left + 60.0, y), line, 1.5)
	node.draw_line(Vector2(left + width - 60.0, y), Vector2(left + width, y), line, 1.5)

	var jewel: Color = _skin["ornament_jewel"]
	var half := 2.83
	for x in [left + 71.7, left + width - 71.7]:
		node.draw_rect(Rect2(x - half, y - half, half * 2.0, half * 2.0), jewel)


func _radial_glow(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


## Plaque du bilan, sertie de son losange a cheval sur la tranche haute.
func _build_stats_plate() -> RoyalPlate:
	var plate := _plate(_skin["edge"], 4.0, 16.0, _skin["plate"])
	plate.set_padding(14, 28, 14, 18)
	plate.inner_outline_color = _skin["inner_outline"]
	plate.inner_radius = 10.0
	plate.ornament_color = _skin["diamond"]
	plate.ornament_border = _skin["diamond_edge"]

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pad)

	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 0)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_stats)

	return plate


# ------------------------------- LIGNES DE BILAN -----------------------------

## Ligne de tete : le montant gagne, piece a l'appui. En defaite la maquette
## la pose sur un fond rouge tres pale (Consolation-Row).
func add_reward_row(label_text: String, amount: int) -> void:
	_separate()

	var value := HBoxContainer.new()
	value.add_theme_constant_override("separation", 8)

	var coin := TextureRect.new()
	coin.custom_minimum_size = Vector2(22, 22)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(COIN_PATH):
		coin.texture = load(COIN_PATH)
	value.add_child(coin)
	value.add_child(_engraved("+%d Or" % amount, 16, Color("ffd700")))

	var row := _row(_label(label_text, 17, _skin["label"], UiTheme.font_bold()), value, 12)
	var highlight: Color = _skin["highlight_row"]
	if highlight.a <= 0.0:
		_stats.add_child(row)
		return

	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = highlight
	box.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	_stats.add_child(panel)


## Puce de bilan : un ROND, comme la maquette. Un ColorRect ne sait faire qu'un
## carre, et six pixels carres au bout d'une ligne de texte se lisent comme une
## coquille, pas comme une puce.
func _bullet(color: Color) -> Icon:
	var dot := Icon.new()
	dot.icon_name = "dot"
	dot.color = color
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return dot


## Ligne de bilan ordinaire, pointee d'une puce comme dans la maquette.
func add_stat_row(label_text: String, value_text: String, bullet: int = 0,
		value_color: Color = Color("f0f3f8")) -> void:
	_separate()

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.add_child(_bullet(
		_skin["bullets"][clampi(bullet, 0, _skin["bullets"].size() - 1)]))
	left.add_child(_label(label_text, 14, Color("9baac0"), UiTheme.font()))

	var value := _label(value_text, 15, value_color, UiTheme.font_black())
	_stats.add_child(_row(left, value, 14))


## Valeur accompagnee d'une icone (couronne des Dames) plutot que d'une puce.
func add_icon_row(label_text: String, icon_name: String, value_text: String,
		accent: Color) -> void:
	_separate()

	var value := HBoxContainer.new()
	value.add_theme_constant_override("separation", 6)
	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = accent
	icon.custom_minimum_size = Vector2(14, 14)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_child(icon)
	value.add_child(_label(value_text, 14, accent, UiTheme.font_bold()))

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.add_child(_bullet(accent))
	left.add_child(_label(label_text, 14, Color("9baac0"), UiTheme.font()))

	_stats.add_child(_row(left, value, 13))


## Filet de separation entre deux lignes (border-b de la maquette). Pose AVANT
## la ligne suivante plutot qu'apres la precedente : la derniere ligne ne doit
## pas trainer un trait sous elle.
func _separate() -> void:
	if _stats.get_child_count() == 0:
		return
	var line := ColorRect.new()
	line.color = _skin["separator"]
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_child(line)


func _row(left: Control, right: Control, padding: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(left)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(right)

	margin.add_child(row)
	UiTheme.ignore_mouse_recursive(margin)
	return margin


# ------------------------------- BOUTONS -------------------------------------

## Bouton d'action principal : une coque doree (ou rouge sang) sertie autour
## d'une plaque - deux plaques imbriquees, comme le bouton de la preparation.
func add_primary_button(text: String, on_press: Callable) -> void:
	var shell := _plate(_skin["edge"], 3.0, 16.0, _skin["shell"])
	shell.set_padding_all(4)
	shell.inner_outline_color = Color(0, 0, 0, 0)
	shell.highlight_alpha = 0.25
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_press(shell, on_press)
	_buttons.add_child(shell)

	var inner := _plate(_skin["shell_inner_edge"], 1.5, 12.0, _inner_fill())
	inner.set_padding(24, 16, 24, 16)
	inner.inner_outline_color = Color(0, 0, 0, 0)
	shell.add_child(inner)

	var label := _engraved(text, 17, _skin["text"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(label)


## Bouton secondaire : une seule plaque, sans coque.
func add_secondary_button(text: String, on_press: Callable) -> void:
	var plate := _plate(_skin["edge"], 2.0, 14.0, _skin["plate"])
	plate.set_padding(16, 14, 16, 14)
	plate.inner_outline_color = Color(0, 0, 0, 0)
	plate.highlight_alpha = 0.08
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_press(plate, on_press)
	_buttons.add_child(plate)

	var label := _engraved(text, 14, _skin["text"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(label)


## Boutons de sortie (ROYAUME, CAMPAGNE) : cote a cote sur la derniere ligne,
## a parts egales.
func add_action_button(text: String, icon_name: String, on_press: Callable) -> void:
	if _actions_row == null:
		_actions_row = HBoxContainer.new()
		_actions_row.add_theme_constant_override("separation", 12)
		_buttons.add_child(_actions_row)

	var plate := _plate(_skin["edge"], 2.0, 12.0, _skin["action"])
	plate.set_padding(20, 13, 20, 13)
	plate.inner_outline_color = Color(0, 0, 0, 0)
	plate.highlight_alpha = 0.08
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_press(plate, on_press)
	_actions_row.add_child(plate)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)

	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = _skin["text"]
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := _engraved(text, 13, _skin["text"])
	label.add_theme_font_override("font", _tracked_font())
	row.add_child(label)

	UiTheme.ignore_mouse_recursive(row)


func _connect_press(node: Control, on_press: Callable) -> void:
	node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			on_press.call())


# ------------------------------- BRIQUES -------------------------------------

func _plate(edge: Color, width: float, radius: float,
		fill: PackedColorArray) -> RoyalPlate:
	var plate := RoyalPlate.new()
	plate.fill_colors = fill
	plate.border_color = edge
	plate.border_width = width
	plate.corner_radius = radius
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate


## Remplissage du bouton principal : bleu nuit en victoire et au nul, braise
## en defaite. Une cle a part et non le drapeau des confettis - c'est en le
## detournant comme "est-ce une victoire" que l'ecran de nul s'etait retrouve
## avec un bouton rouge sang.
func _inner_fill() -> PackedColorArray:
	return _skin["cta_inner"]


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var label := UiTheme.make_label(text, size, color)
	label.add_theme_font_override("font", font)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


## Mot grave : gras noir, ombre portee franche. Meme parti que
## UiTheme.gold_label, mais la teinte change avec l'issue de la bataille.
func _engraved(text: String, size: int, color: Color) -> Label:
	var label := UiTheme.make_label(text, size, color)
	label.add_theme_font_override("font", UiTheme.font_black())
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Inter gras espace d'un point, l'interlettrage des libelles de sortie.
static func _tracked_font() -> Font:
	var variation := FontVariation.new()
	variation.base_font = UiTheme.font_black()
	variation.spacing_glyph = 1
	return variation
