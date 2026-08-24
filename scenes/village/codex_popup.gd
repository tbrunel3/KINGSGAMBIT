extends Control
##
## CODEX DU ROYAUME - l'encyclopedie du jeu, en plein ecran defilant.
##
## Repris de la maquette V2 (Figma codex-popup-v3) : plaque de titre, puces de
## filtre, une carte par piece, un tableau par niveau, puis les batiments et
## les regles.
##
## POURQUOI CE FICHIER NE CONTIENT AUCUN CHIFFRE.
##
## La premiere version de cet ecran, cote maquette, decrivait un autre jeu :
## des colonnes PV et ATK, un soin de 10 PV par tour, un plateau 8x11, des
## vitesses x1/x2/x4, une defaite si le Roi tombe, huit batiments. Rien de
## tout cela n'existe. Ce n'etait pas une faute de dessin - c'etait une
## TRANSCRIPTION, et une transcription se decale des que le jeu bouge.
##
## Ici, chaque nombre et chaque phrase de regle sont RECALCULES a l'ouverture
## depuis Balance : mobilite par niveau, capacite de caserne, cout de
## recrutement, prix d'amelioration, poids de deploiement, taille des
## plateaux, longueur des series. Le codex ne peut donc plus mentir : s'il
## affiche une valeur fausse, c'est que le jeu la joue.
##
## Les seules chaines ecrites en dur sont de la PROSE - un sous-titre, une
## tournure de phrase. Tout nombre qu'elles contiennent est interpole depuis
## Balance, jamais tape.
##

## Degrades de la maquette, communs a la preparation de bataille. En
## `static var` et non en `const` : GDScript n'accepte pas un
## PackedColorArray de Color("...") comme expression constante.
static var PLATE_FILL := PackedColorArray([
	Color("1e3278"), Color("0a1230"), Color("0e1a40")])
static var CHIP_ON_FILL := PackedColorArray([Color("ffd700")])
static var CHIP_OFF_FILL := PackedColorArray([Color("12213e")])
static var NOTE_FILL := PackedColorArray([Color("2a1230")])

const CornerButton := preload("res://scenes/ui/components/corner_button.gd")
const GOLD_EDGE := Color("ffe680")
const GOLD := Color("ffd700")
const GREEN := Color("4cd964")
const PINK := Color("d8a0d0")
const RED := Color("c65f5f")
const TEXT_BRIGHT := Color("f0f3f8")
const TEXT_DIM := Color("a0aabf")
const ROW_ODD := Color("12213e")
const ROW_EVEN := Color("0a1230")
const ROW_HEAD := Color("0e1a40")

## Largeurs des colonnes du tableau, en unites de la maquette. La mobilite
## prend ce qui reste : c'est de loin la plus longue - "saut diagonal" au
## niveau 1, sept figures enumerees au niveau 10.
##
## MESURE, pas choisi : a la premiere capture, ces largeurs ne laissaient que
## 115 unites a la mobilite et chaque ligne du pion se repliait sur QUATRE
## lignes, pour un tableau plus haut que l'ecran. Les trois colonnes chiffrees
## sont donc au plus juste de leur en-tete, et le corps descend a 10.
const TABLE_FONT := 10
const COL_LEVEL := 34
const COL_CAPACITY := 48
const COL_PRICE := 50
## Marge laterale d'une ligne. A 12 de chaque cote, 24 unites partaient en
## blanc alors que la colonne la plus longue en manquait.
const ROW_MARGIN := 8
const ROW_GAP := 6

const PIECE_SIZE := Vector2(72, 72)

## Prose par piece. Aucun nombre ici : ceux des phrases sont interpoles depuis
## Balance au moment de la construction (cf. _piece_lines).
const FLAVOUR := {
	Balance.PION: "Fantassin du royaume",
	Balance.CAVALIER: "Chevalier agile",
	Balance.FOU: "Stratège des diagonales",
	Balance.TOUR: "Forteresse mobile",
	Balance.DAME: "Reine des batailles",
}

@onready var _background: TextureRect = $Background
@onready var _header: HBoxContainer = $Safe/Root/HeaderMargin/Header
@onready var _filter_row: HBoxContainer = $Safe/Root/Filters/FilterRow
@onready var _body: VBoxContainer = $Safe/Root/Scroll/Body

## Type filtre, ou "" pour tout afficher.
var _filter: String = ""
## type (ou "") -> plaque de la puce, pour la repeindre au changement de filtre.
var _chips: Dictionary = {}


## L'ENTREE DU CODEX. Il n'en avait AUCUNE - pas un tween dans tout le fichier.
## L'ecran apparaissait d'un bloc, et le joueur l'a resume par "il s'ouvre sans
## animation, et trop agressivement".
##
## ⚠️ ON N'ANIME QUE L'OPACITE ET L'ECHELLE, jamais la position : tout ce qui
## est ici est enfant d'un conteneur, qui reecrit sa position a chaque trame.
## Un tween dessus se bat avec la mise en page - c'est le piege qui avait colle
## le bandeau de serie en haut de l'ecran (cf. CLAUDE.md).
const ENTRY_BLOCK_SCALE := 0.96
const ENTRY_CARD_SCALE := 0.94
## Au-dela, les cartes qui entrent sont sous la ligne de flottaison : les faire
## attendre allonge l'ouverture sans que personne ne le voie.
const ENTRY_MAX_STEPS := 8.0

var _entree_jouee: bool = false


func _ready() -> void:
	_build_background()
	_build_header()
	_build_filters()
	_rebuild()
	_animer_entree()


func _animer_entree() -> void:
	# Les pivots ne se lisent qu'une fois la mise en page faite : releves a la
	# construction, ils valent zero et l'echelle partirait du coin.
	await get_tree().process_frame
	if not is_inside_tree() or _entree_jouee:
		return
	_entree_jouee = true

	var tween := create_tween().set_parallel(true)
	var pas := Balance.motion("card_stagger")
	_paraitre(tween, _header, 0.0, ENTRY_BLOCK_SCALE, Balance.motion("panel_entry"))
	_paraitre(tween, _filter_row, pas, ENTRY_BLOCK_SCALE, Balance.motion("panel_entry"))

	var rang := 0
	for carte in _body.get_children():
		if not (carte is Control):
			continue
		_paraitre(tween, carte as Control,
			minf(pas * float(rang + 2), pas * ENTRY_MAX_STEPS),
			ENTRY_CARD_SCALE, Balance.motion("card_entry"))
		rang += 1


## Un bloc qui parait : opacite de 0 a 1, echelle de `depuis` a 1.
##
## ⚠️ IL NE FAUT PAS REJOUER CA A CHAQUE FILTRE. `_rebuild` remplace les cartes
## du corps quand le joueur touche une puce ; les neuves naissent opaques, et
## `_entree_jouee` empeche l'ecran de se rejouer entier. Une entree qui se
## redeclenche a chaque geste, c'est precisement "trop agressif" dans l'autre
## sens.
func _paraitre(tween: Tween, node: Control, retard: float, depuis: float,
		duree: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	node.modulate.a = 0.0
	node.scale = Vector2.ONE * depuis
	tween.tween_property(node, "modulate:a", 1.0, duree).set_delay(retard)
	tween.tween_property(node, "scale", Vector2.ONE, duree).set_delay(retard) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fond de la maquette : un degrade radial tres sombre, plus clair au centre,
## repris tel quel de la preparation de bataille.
func _build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("141d3a"))
	gradient.set_color(1, Color("05070f"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.4)
	texture.fill_to = Vector2(1.0, 0.4)
	texture.width = 128
	texture.height = 128
	_background.texture = texture


func _build_header() -> void:
	# Le retour vient du composant partage. Ces vingt lignes etaient copiees a
	# l'identique ici et dans l'autre ecran plein defilant - meme plaque, meme
	# padding, meme fleche.
	var back: Control = CornerButton.back(Router.goto_village)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(back)

	var plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	plate.set_padding(16, 12, 16, 12)
	plate.ornament_color = Color("3a7fe8")
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(plate)

	var pad := _inner_padding()
	plate.add_child(pad)
	var title := UiTheme.gold_label("CODEX DU ROYAUME", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	pad.add_child(title)


# ------------------------------- FILTRES -------------------------------------

## Une puce par piece, plus TOUS. La rangee defile horizontalement : six puces
## ne tiennent pas dans les 361 unites utiles, et les tronquer reviendrait a
## cacher la Dame - justement celle qu'on cherche.
func _build_filters() -> void:
	_add_chip("", "TOUS")
	for type in Balance.ARMY_TYPES:
		_add_chip(type, String(Balance.unit_name(type)).to_upper())
	_repaint_chips()


func _add_chip(type: String, text: String) -> void:
	var chip := _plate(GOLD, 1.5, 15.0, CHIP_OFF_FILL)
	chip.set_padding(10, 8, 10, 8)
	chip.inner_outline_color = Color(0, 0, 0, 0)
	chip.highlight_alpha = 0.0
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_filter(type))

	var label := UiTheme.make_label(text, 11, TEXT_BRIGHT)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.name = "Label"
	chip.add_child(label)

	_filter_row.add_child(chip)
	_chips[type] = chip


func _on_filter(type: String) -> void:
	if _filter == type:
		return
	_filter = type
	_repaint_chips()
	_rebuild()


func _repaint_chips() -> void:
	for type in _chips:
		var chip: RoyalPlate = _chips[type]
		var on: bool = type == _filter
		chip.fill_colors = CHIP_ON_FILL if on else CHIP_OFF_FILL
		chip.queue_redraw()
		var label: Label = chip.get_node("Label")
		label.add_theme_color_override(
			"font_color", Color("05060a") if on else TEXT_BRIGHT)


# ------------------------------- CORPS ---------------------------------------

func _rebuild() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.free()

	for type in Balance.ARMY_TYPES:
		if _filter.is_empty() or _filter == type:
			_body.add_child(_piece_card(type))

	# Les batiments et les regles n'appartiennent a aucune piece : ils ne
	# s'affichent que sans filtre.
	if _filter.is_empty():
		_body.add_child(_buildings_section())
		_body.add_child(_rules_section())


# ------------------------------- CARTE DE PIECE ------------------------------

func _piece_card(type: String) -> RoyalPlate:
	var plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	plate.set_padding(14, 24, 14, 18)

	var pad := _inner_padding()
	plate.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	pad.add_child(column)

	column.add_child(_card_header(type))
	column.add_child(preload("res://scenes/ui/components/ornate_divider.tscn").instantiate())
	column.add_child(_card_body(type))
	var note := _card_note(type)
	if note != null:
		column.add_child(note)
	column.add_child(_card_table(type))
	column.add_child(_card_footer(type))
	return plate


## Titre, sous-titre, et les deux puces qui disent l'essentiel d'un coup
## d'oeil : comment la piece se debloque, et ce qu'elle coute a poser.
func _card_header(type: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)

	var title := UiTheme.gold_label("%s %s" % [
		String(Balance.unit_article(type)).to_upper(),
		String(Balance.unit_name(type)).to_upper()], 24)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	names.add_child(title)

	var subtitle := UiTheme.make_label(String(FLAVOUR.get(type, "")), 12, TEXT_DIM)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	names.add_child(subtitle)

	var chips := VBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(chips)
	chips.add_child(_badge(_unlock_text(type), _unlock_color(type)))
	chips.add_child(_badge("POIDS %d" % Balance.deploy_weight(type), GOLD))
	return row


## Comment cette piece entre dans l'armee. Trois cas, et ils sortent tous de
## Balance : la Dame ne s'achete pas, deux casernes attendent un palier de
## chateau, les autres sont la des le depart.
func _unlock_text(type: String) -> String:
	if type == Balance.DAME:
		return "PAR PROMOTION"
	if Balance.is_unlockable(type):
		return "CHÂTEAU Nv.%d" % Balance.unlock_castle_level(type)
	return "DÈS LE DÉPART"


func _unlock_color(type: String) -> Color:
	if type == Balance.DAME:
		return PINK
	return GOLD if Balance.is_unlockable(type) else GREEN


## Illustration a gauche, trois lignes a droite : deplacement, capture, special.
func _card_body(type: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var frame := _plate(GOLD, 1.5, 12.0, PackedColorArray([Color("0a1230")]))
	frame.set_padding_all(6)
	frame.inner_outline_color = Color(0, 0, 0, 0)
	frame.custom_minimum_size = PIECE_SIZE
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)

	var sprite := TextureRect.new()
	var path := "res://assets/pieces/bleu/%s.png" % type
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(sprite)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lines)
	for pair in _piece_lines(type):
		lines.add_child(_labelled(String(pair[0]), String(pair[1])))
	UiTheme.ignore_mouse_recursive(frame)
	return row


## Les trois lignes du corps de carte. La prose est ecrite ici, mais tout ce
## qui est chiffre vient de Balance - le pourcentage de l'aura comme le poids.
func _piece_lines(type: String) -> Array:
	var capture := "en se déplaçant sur la case adverse — ni points de vie, ni dégâts"
	match type:
		Balance.PION:
			return [
				["Déplacement :", "tout droit vers le camp adverse ; sa portée et son ouverture montent avec le niveau"],
				["Capture :", "en diagonale avant, en se déplaçant sur la case adverse"],
				["Spécial :", "Promotion — mené au bout du plateau adverse il devient Dame. Ramenée vivante, elle rejoint le %s." % Balance.building_name(Balance.DAME)],
			]
		Balance.CAVALIER:
			return [
				["Déplacement :", "en sautant : les pièces sur le chemin ne le bloquent jamais"],
				["Capture :", "en se déplaçant sur la case d'arrivée de son saut"],
				["Spécial :", "Chaque niveau lui ouvre une figure de saut de plus — pas de la portée. Les figures des niveaux précédents restent."],
			]
		Balance.FOU:
			return [
				["Déplacement :", "en diagonale, bloqué par la première pièce rencontrée"],
				["Capture :", capture],
				["Spécial :", "Aucun. Sa force est sa portée, qui passe de %d à %d cases du niveau 1 au niveau %d." % [
					Balance.move_range(type, 1), Balance.move_range(type, Balance.MAX_LEVEL), Balance.MAX_LEVEL]],
			]
		Balance.TOUR:
			return [
				["Déplacement :", "en ligne et en colonne, bloquée par la première pièce rencontrée"],
				["Capture :", capture],
				["Spécial :", "Aucun. C'est la pièce la plus lourde à poser : %d de charge, autant que la Dame." % Balance.deploy_weight(type)],
			]
		_:
			return [
				["Déplacement :", "lignes, colonnes et diagonales"],
				["Capture :", capture],
				["Spécial :", "Aura — une Dame restée au village rapporte +%d %% d'or sur chaque bataille. La déployer, c'est renoncer à sa part pour ce combat-là." % roundi(Balance.DAME_GOLD_BONUS * 100.0)],
			]


## Bandeau d'avertissement sous le corps de carte, quand la piece a une
## condition qui ne tient pas dans une puce.
func _card_note(type: String) -> RoyalPlate:
	var text := ""
	if type == Balance.DAME:
		text = ("Elle ne se recrute pas. Un pion mené au bout du plateau adverse devient "
			+ "Dame ; ramenée vivante, elle rejoint le %s. Son niveau est le plus petit "
			+ "du niveau du château et du NOMBRE de Dames abritées.") % Balance.building_name(Balance.DAME)
	elif Balance.is_unlockable(type):
		text = ("%s apparaît gratuitement au village dès que le %s atteint le niveau %d."
			% [Balance.building_name(type), Balance.CASTLE_DATA["name"],
				Balance.unlock_castle_level(type)])
	if text.is_empty():
		return null

	var note := _plate(Color("d8a0d0", 0.5) if type == Balance.DAME else Color("ffd700", 0.4),
		1.5, 8.0, NOTE_FILL if type == Balance.DAME else PackedColorArray([Color("14203c")]))
	note.set_padding(10, 8, 10, 8)
	note.inner_outline_color = Color(0, 0, 0, 0)
	note.highlight_alpha = 0.0
	var label := UiTheme.make_label(text, 11, TEXT_BRIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(label)
	UiTheme.ignore_mouse_recursive(note)
	return note


# ------------------------------- TABLEAU -------------------------------------

## Les dix niveaux de la piece. C'est le coeur du codex, et la seule vue du jeu
## qui montre la COURBE plutot que le palier suivant : le popup de batiment dit
## ce que coute la marche d'apres, le codex dit ou mene l'escalier.
func _card_table(type: String) -> VBoxContainer:
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 2)
	table.add_child(_table_row(
		["NIV.", "MOBILITÉ", "CASERNE", "PRIX"], ROW_HEAD, true))

	for level in range(1, Balance.max_level(type) + 1):
		var cost := Balance.upgrade_cost(type, level)
		table.add_child(_table_row([
			"Nv.%d" % level,
			Balance.move_description(type, level),
			str(Balance.capacity(type, level)),
			"—" if cost < 0 else _gold(cost),
		], ROW_ODD if level % 2 == 1 else ROW_EVEN, false))
	return table


func _table_row(cells: Array, background: Color, head: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.content_margin_left = ROW_MARGIN
	box.content_margin_right = ROW_MARGIN
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(row)

	var widths := [COL_LEVEL, 0, COL_CAPACITY, COL_PRICE]
	var colors := [TEXT_DIM if head else GOLD, TEXT_BRIGHT, TEXT_BRIGHT, TEXT_BRIGHT]
	for i in cells.size():
		var label := UiTheme.make_label(String(cells[i]), TABLE_FONT,
			TEXT_DIM if head else colors[i])
		if head or i == 0:
			label.add_theme_font_override("font", UiTheme.font_bold())
		if i == 1:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.custom_minimum_size.x = widths[i]
			# SANS CETTE LIGNE, LE TABLEAU EST FAUX. UiTheme.make_label pose
			# SIZE_EXPAND_FILL sur tout libelle : les quatre colonnes se
			# partageaient alors la largeur a parts egales (67 unites chacune,
			# mesure), et la mobilite - seule colonne a en avoir besoin - se
			# repliait sur quatre lignes pendant que "8" occupait 67 unites.
			label.size_flags_horizontal = Control.SIZE_FILL
			# Les colonnes chiffrees s'alignent a droite : c'est ce qui rend
			# une colonne de prix lisible d'un coup d'oeil.
			if i >= 2:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(label)

	UiTheme.ignore_mouse_recursive(panel)
	return panel


# ------------------------------- PIED DE CARTE -------------------------------

## Ou la piece se recrute et a quel prix. Le prix MONTE a chaque recrue : c'est
## le vrai barème, et l'ancien codex n'en disait rien.
func _card_footer(type: String) -> RoyalPlate:
	var plate := _plate(Color("ffd700", 0.5), 1.0, 10.0, PackedColorArray([Color("12213e")]))
	plate.set_padding(12, 10, 12, 10)
	plate.inner_outline_color = Color(0, 0, 0, 0)
	plate.highlight_alpha = 0.0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	plate.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "crown" if type == Balance.DAME else "castle"
	icon.color = GOLD
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var base := Balance.recruit_cost(type, 0)
	var step := Balance.recruit_cost(type, 1) - base
	var text := "%s — ne se recrute pas" % Balance.building_name(type)
	if base > 0:
		text = "%s — %s (+%d par recrue)" % [Balance.building_name(type), _gold(base), step]
	var label := UiTheme.make_label(text, 11, TEXT_BRIGHT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	row.add_child(_badge(
		"CHÂTEAU" if type == Balance.DAME else "CASERNE", GOLD))
	UiTheme.ignore_mouse_recursive(plate)
	return plate


# ------------------------------- BATIMENTS -----------------------------------

## Cinq batiments, et c'est le fichier d'equilibrage qui les compte : le
## chateau, plus une caserne par piece RECRUTABLE. La Dame n'en a pas - elle
## vit au Chateau Royal.
func _buildings_section() -> RoyalPlate:
	var plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	plate.set_padding(14, 24, 14, 18)
	var pad := _inner_padding()
	plate.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	pad.add_child(column)

	column.add_child(_section_title("BÂTIMENTS DU VILLAGE"))
	var slowest := _slowest_upgrade()
	var fastest := _fastest_upgrade()
	var intro := UiTheme.make_label(
		"%d bâtiments, pas un de plus. Une amélioration coûte de l'or ET du temps réel — de %s au premier palier à %s au dernier."
			% [1 + Balance.UNIT_TYPES.size(), _duration(fastest), _duration(slowest)],
		11, TEXT_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	column.add_child(preload("res://scenes/ui/components/ornate_divider.tscn").instantiate())

	column.add_child(_building_row(Balance.CASTLE_DATA["name"],
		"Fixe la charge de déploiement en bataille : %d au niveau 1, %d au niveau %d. Il abrite aussi les Dames, et c'est lui qui fixe leur niveau."
			% [Balance.deploy_capacity(1), Balance.deploy_capacity(Balance.MAX_LEVEL),
				Balance.MAX_LEVEL]))
	for type in Balance.UNIT_TYPES:
		column.add_child(_building_row(Balance.building_name(type), _building_text(type)))
	return plate


func _building_text(type: String) -> String:
	var text := "Recrute et améliore les %ss. Sa capacité va de %d au niveau 1 à %d au niveau %d." % [
		String(Balance.unit_name(type)).to_lower(),
		Balance.capacity(type, 1), Balance.capacity(type, Balance.MAX_LEVEL),
		Balance.MAX_LEVEL]
	if Balance.is_unlockable(type):
		text += " Il apparaît gratuitement dès le %s niveau %d." % [
			Balance.CASTLE_DATA["name"], Balance.unlock_castle_level(type)]
	return text


func _building_row(name_text: String, description: String) -> RoyalPlate:
	var plate := _plate(Color("ffd700", 0.35), 1.0, 10.0,
		PackedColorArray([Color("12213e")]))
	plate.set_padding(10, 10, 10, 10)
	plate.inner_outline_color = Color(0, 0, 0, 0)
	plate.highlight_alpha = 0.0

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	plate.add_child(column)

	var title := UiTheme.gold_label(name_text, 13)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(title)

	var body := UiTheme.make_label(description, 11, TEXT_BRIGHT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	UiTheme.ignore_mouse_recursive(plate)
	return plate


## Le palier d'amelioration le plus court et le plus long du jeu, tous
## batiments confondus. Ecrit nulle part : on les cherche dans Balance.
func _fastest_upgrade() -> int:
	var best := Balance.upgrade_seconds(Balance.CASTLE, 1)
	for type in Balance.UNIT_TYPES:
		var value := Balance.upgrade_seconds(type, 1)
		if value > 0 and (best <= 0 or value < best):
			best = value
	return best


func _slowest_upgrade() -> int:
	var worst := 0
	for type in Balance.UNIT_TYPES + [Balance.CASTLE]:
		for level in range(1, Balance.MAX_LEVEL):
			worst = maxi(worst, Balance.upgrade_seconds(type, level))
	return worst


# ------------------------------- REGLES --------------------------------------

## Six regles, et pas une de plus que ce que le jeu applique. Les tailles de
## plateau, les poids et la longueur des series sont RELUS dans Balance a
## chaque ouverture : l'ancien codex annoncait un plateau 8x11 qui n'a jamais
## existe, faute d'etre branche sur quoi que ce soit.
func _rules_section() -> RoyalPlate:
	var plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	plate.set_padding(14, 24, 14, 18)
	var pad := _inner_padding()
	plate.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	pad.add_child(column)

	column.add_child(_section_title("LES RÈGLES DU COMBAT"))
	column.add_child(preload("res://scenes/ui/components/ornate_divider.tscn").instantiate())

	var boards := _board_range()
	var weights: Array[String] = []
	for type in Balance.ARMY_TYPES:
		weights.append("%s %d" % [Balance.unit_name(type), Balance.deploy_weight(type)])
	var series := _series_range()

	var rules := [
		["1. LE CHAMP DE BATAILLE",
			"Un plateau quadrillé, de %s selon la bataille. Tour par tour, et une seule pièce par camp et par tour." % boards, GOLD],
		["2. LE PLACEMENT",
			"Avant chaque combat vous posez vous-même votre armée sur vos %d rangées du fond, face à une formation ennemie que vous voyez. Ce n'est pas un nombre de pièces mais un budget de charge : %s."
				% [Balance.DEPLOY_ROWS, ", ".join(weights)], GOLD],
		["3. LA CAPTURE",
			"Ni points de vie, ni dégâts. On capture en se déplaçant sur la case adverse, comme aux échecs. Une pièce est sur le plateau, ou elle n'y est plus.", GOLD],
		["4. L'ANNEAU ROUGE",
			"Un cercle rouge entoure en permanence vos pièces prenables au coup suivant. Sans points de vie, voir l'attaque arriver EST la tension du jeu.", RED],
		["5. VICTOIRE, DÉFAITE, MATCH NUL",
			"Un camp gagne quand l'autre n'a plus rien debout. Une bataille enlisée se tranche au matériel restant — et à égalité stricte, personne n'a gagné : les survivants rentrent, le combat ne rapporte rien, mais la série n'est pas rompue.", GOLD],
		["6. LA SÉRIE", series, GOLD],
	]
	for rule in rules:
		column.add_child(_rule_row(String(rule[0]), String(rule[1]), rule[2]))
	return plate


## "5 × 6 à 8 × 9 cases" - releve sur la campagne, jamais tape.
func _board_range() -> String:
	var min_cols := 99
	var min_rows := 99
	var max_cols := 0
	var max_rows := 0
	for battle in Balance.CAMPAIGN:
		min_cols = mini(min_cols, int(battle["cols"]))
		min_rows = mini(min_rows, int(battle["rows"]))
		max_cols = maxi(max_cols, int(battle["cols"]))
		max_rows = maxi(max_rows, int(battle["rows"]))
	if min_cols == max_cols and min_rows == max_rows:
		return "%d × %d cases" % [min_cols, min_rows]
	return "%d × %d à %d × %d cases" % [min_cols, min_rows, max_cols, max_rows]


## La phrase de la serie, batie sur les `fights` reels de la campagne. A
## `fights: 1` partout, toute la machinerie de serie disparait du jeu - et
## cette regle doit disparaitre avec elle plutot que d'annoncer un enchainement
## qui n'a pas lieu.
func _series_range() -> String:
	var most := 1
	for battle in Balance.CAMPAIGN:
		most = maxi(most, Balance.battle_fights(battle))
	if most <= 1:
		return "Chaque bataille se joue en un seul combat, avec retour au village entre deux."

	var first_multi := 0
	for battle in Balance.CAMPAIGN:
		if Balance.battle_fights(battle) > 1:
			first_multi = int(battle["id"])
			break
	return ("À partir de la bataille %d, une bataille ne se gagne plus en un combat mais en une SÉRIE — jusqu'à %d combats d'affilée, sans retour au village. L'ennemi revient au complet, vous revenez avec vos survivants : c'est là qu'est la difficulté."
		% [first_multi, most])


func _rule_row(title_text: String, body_text: String, tint: Color) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)

	var title := UiTheme.make_label(title_text, 12, tint)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var body := UiTheme.make_label(body_text, 11, TEXT_BRIGHT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	return column


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


func _inner_padding() -> MarginContainer:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	return pad


func _badge(text: String, tint: Color) -> RoyalPlate:
	var badge := _plate(tint, 1.0, 6.0, PackedColorArray([Color(tint, 0.18)]))
	badge.set_padding(8, 4, 8, 4)
	badge.inner_outline_color = Color(0, 0, 0, 0)
	badge.highlight_alpha = 0.0
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END

	var label := UiTheme.make_label(text, 9, tint)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	UiTheme.ignore_mouse_recursive(badge)
	return badge


## "Déplacement : ..." - le libelle en or, la valeur en clair, sur une ligne
## qui se replie proprement.
func _labelled(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label := UiTheme.make_label(label_text, 11, GOLD)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Meme piege que dans le tableau : sans SHRINK_BEGIN, le libelle mange la
	# moitie de la ligne et la valeur se replie pour rien.
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	var value := UiTheme.make_label(value_text, 11, TEXT_BRIGHT)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return row


func _section_title(text: String) -> Label:
	var label := UiTheme.gold_label(text, 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## UiTheme.format_duration ecrit "4h 00m" - juste pour un compte a rebours, qui
## ne doit pas changer de largeur en descendant, mais laid dans une phrase.
## Ici la duree est fixe : on peut laisser tomber les minutes nulles.
func _duration(seconds: int) -> String:
	var text := UiTheme.format_duration(seconds)
	return text.trim_suffix(" 00m")


## Un montant en or, avec l'espace des milliers - "3 860 Or" se lit, "3860 Or"
## se dechiffre.
func _gold(amount: int) -> String:
	return "%s Or" % UiTheme.format_thousands(amount)
