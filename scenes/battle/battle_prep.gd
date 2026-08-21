extends Control
##
## PREPARATION DE BATAILLE - le briefing affiche avant le placement.
##
## Repris de la maquette V2 (Figma preparation-bataille-v2), qui change la
## PEAU sans changer le propos : trois plaques bleu nuit cerclees d'or - armee
## ennemie, ton armee, l'enjeu - et un bouton d'action serti. Toute la matiere
## vient toujours de Balance.CAMPAIGN et de GameState : rien n'est ecrit en
## dur ici.
##
## Deux libelles de la maquette ne sont PAS repris tels quels, parce qu'ils
## decrivent un autre jeu que celui du code (cf. CLAUDE.md) :
##   - "Deploiement: 12/15" compte des unites ; le jeu compte une CHARGE
##     (Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5) contre la capacite du
##     chateau. Le libelle dit donc "Charge".
##   - "Plateau 8x11 cases" est fixe ; la taille du terrain vient de la
##     bataille jouee, et va de 5x6 a 8x9.
##

## Degrades de la maquette. En `static var` et non en `const` : GDScript
## n'accepte pas un PackedColorArray de Color("...") comme expression
## constante - un constructeur n'est pas une constante.
static var PLATE_FILL := PackedColorArray([
	Color("1e3278"), Color("0a1230"), Color("0e1a40")])
static var CARD_FILL := PackedColorArray([Color("12213e"), Color("0a1230")])
static var CARD_FILL_OFF := PackedColorArray([Color("10192e"), Color("080e1e")])
static var BANNER_FILL := PackedColorArray([
	Color("3a1010"), Color("5a1a1a"), Color("3a1010")])
static var READY_FILL := PackedColorArray([Color("2e5bff"), Color("1a3daa")])
static var CTA_FILL := PackedColorArray([
	Color("ffe680"), Color("c8960c"), Color("8b6200"), Color("c8960c")])

const GOLD_EDGE := Color("ffe680")
const OFF_EDGE := Color("4a5068")
const TEXT_BRIGHT := Color("f0f3f8")
const TEXT_DIM := Color("a0aabf")

const COIN_TEXTURE := preload("res://assets/ui/kg_coin.png")

@onready var _background: TextureRect = $Background
@onready var _header: HBoxContainer = $Safe/Root/HeaderMargin/Header
@onready var _body: VBoxContainer = $Safe/Root/Scroll/Body
@onready var _cta_row: HBoxContainer = $Safe/Root/CtaRow

var _battle: Dictionary = {}
var _cta: RoyalPlate
var _cta_enabled: bool = true


func _ready() -> void:
	_battle = Router.current_battle()
	_build_background()
	_build_header()
	if _battle.is_empty():
		_body.add_child(UiTheme.make_label("Bataille introuvable", 16, UiTheme.DANGER))
		return
	_build_enemy_panel()
	_build_player_panel()
	_build_info_panel()
	_build_cta()


## Fond de la maquette : un degrade radial tres sombre, plus clair au centre,
## qui fait ressortir les plaques posees dessus.
func _build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("0c0e17"))
	gradient.set_color(1, Color("05060a"))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_background.texture = texture


# ------------------------------- EN-TETE -------------------------------------

func _build_header() -> void:
	var back := _plate(GOLD_EDGE, 3.5, 12.0, PLATE_FILL)
	back.set_padding_all(6)
	back.inner_outline_color = Color("ffd700", 0.25)
	back.inner_radius = 8.0
	back.custom_minimum_size = Vector2(52, 52)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Router.goto_campaign())
	_header.add_child(back)

	var arrow := Icon.new()
	arrow.icon_name = "arrow_left"
	arrow.color = TEXT_BRIGHT
	arrow.custom_minimum_size = Vector2(14, 14)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(arrow)

	var title_plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	title_plate.set_padding(16, 12, 16, 12)
	title_plate.ornament_color = Color("3a7fe8")
	title_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title_plate)

	var title_pad := _inner_padding()
	title_plate.add_child(title_pad)

	var name := String(_battle["name"]).to_upper()
	var title := UiTheme.gold_label("BATAILLE %d — %s" % [int(_battle["id"]), name], 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	# "BATAILLE 10 — LA TOUR DE LA DAME" fait 32 signes : on reduit le corps
	# plutot que de laisser le nom se faire couper.
	if title.text.length() > 28:
		title.add_theme_font_size_override("font_size", 13)
	elif title.text.length() > 22:
		title.add_theme_font_size_override("font_size", 14)
	title_pad.add_child(title)


# ------------------------------- ARMEE ENNEMIE -------------------------------

func _build_enemy_panel() -> void:
	var column := _panel()

	var banner := _plate(GOLD_EDGE, 2.0, 8.0, BANNER_FILL)
	banner.gradient_horizontal = true
	banner.set_padding(20, 6, 20, 6)
	banner.inner_outline_color = Color(0, 0, 0, 0)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(banner)
	banner.add_child(UiTheme.gold_label("ARMÉE ENNEMIE", 13))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var enemies: Dictionary = _battle["enemies"]
	var level := int(_battle["level"])
	for type in Balance.UNIT_TYPES:
		if not enemies.has(type):
			continue
		row.add_child(_unit_card(type, "rouge", "%s ×%d" % [
			Balance.unit_name(type), int(enemies[type])], "Nv.%d" % level, 13, "", true))


# ------------------------------- TON ARMEE -----------------------------------

func _build_player_panel() -> void:
	var column := _panel()

	var header := HBoxContainer.new()
	column.add_child(header)

	var title := UiTheme.gold_label("TON ARMÉE", 13)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	# "Charge" et non "Deploiement" : ce rapport compare des POIDS, pas des
	# effectifs (cf. Balance > CASTLE_DATA.deploy_capacity).
	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 4)
	load_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(load_row)
	var load_label := UiTheme.make_label("Charge :", 12, TEXT_DIM)
	load_label.add_theme_font_override("font", UiTheme.font_bold())
	load_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	load_row.add_child(load_label)
	load_row.add_child(UiTheme.gold_label(
		"%d/%d" % [_player_weight(), Game.deploy_capacity()], 12))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	var owned_total := 0
	for type in Balance.ARMY_TYPES:
		var owned := Game.units_owned(type)
		owned_total += owned
		# La Dame ne figure sur le briefing que si le Roi en a retrouve une :
		# elle ne se recrute pas, une case vide n'apprendrait rien.
		if type == Balance.DAME and owned <= 0:
			continue
		# Son niveau est celui que la bataille lui donnera vraiment (cf.
		# GameState.dame_level), pas celui de la caserne des pions.
		var level := Game.dame_level() if type == Balance.DAME else Game.building_level(type)
		# Un batiment pas encore apparu au village n'a pas de niveau : la carte
		# n'ecrit alors rien plutot qu'un "Nv.0" faux. La condition exacte
		# d'ouverture est donnee au village, sur le batiment verrouille.
		var level_text := "Nv.%d" % level if level > 0 else ""
		row.add_child(_unit_card(type, "bleu", Balance.unit_name(type), level_text, 12,
			"PRÊT" if owned > 0 else "RÉSERVE", owned > 0))

	if owned_total == 0:
		column.add_child(UiTheme.make_label(
			"Aucune unité — recrute au village.", 13, UiTheme.DANGER))
	_cta_enabled = owned_total > 0


## Poids total de l'armee possedee - cf. CASTLE_DATA.deploy_capacity dans
## balance.gd : la ligne "Charge" du briefing compare des poids.
func _player_weight() -> int:
	var weight := 0
	for type in Balance.ARMY_TYPES:
		weight += Game.units_owned(type) * Balance.deploy_weight(type)
	return weight


# ------------------------------- L'ENJEU -------------------------------------

func _build_info_panel() -> void:
	var column := _panel()

	var reward := Game.reward_for(int(_battle["id"]))
	var fights := Balance.battle_fights(_battle)

	# La serie d'abord : c'est elle l'engagement que le joueur prend en
	# appuyant sur le bouton. L'or annonce est celui de la serie ENTIERE - il
	# n'est verse qu'au dernier combat gagne, et un seul combat perdu le fait
	# tomber (cf. CampaignRun).
	var run := Game.current_run(int(_battle["id"]))
	var fights_label := UiTheme.make_label(
		"%d combats d'affilée" % fights if fights > 1 else "un seul combat",
		14, TEXT_BRIGHT)
	fights_label.add_theme_font_override("font", UiTheme.font_black())
	fights_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_info_row(
		"Série en cours (%d/%d)" % [run.fight, fights] if run != null else "Série",
		fights_label))

	var gold_value := HBoxContainer.new()
	gold_value.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.texture = COIN_TEXTURE
	coin.custom_minimum_size = Vector2(20, 20)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_value.add_child(coin)
	gold_value.add_child(UiTheme.gold_label("%d Or" % (reward * fights), 15))
	column.add_child(_info_row("Récompense de la série", gold_value))

	# Ce que rapporteraient les Dames si elles restaient toutes au village :
	# c'est ici, avant le placement, que le choix se prepare.
	var dame_bonus := Game.dame_gold_bonus(reward)
	if dame_bonus > 0:
		var dames := Game.dames_owned()
		var bonus := UiTheme.make_label("+%d Or" % dame_bonus, 14, Color("d8a0d0"))
		bonus.add_theme_font_override("font", UiTheme.font_bold())
		bonus.autowrap_mode = TextServer.AUTOWRAP_OFF
		column.add_child(_info_row(
			"Aura de %d Dame%s au repos" % [dames, "" if dames <= 1 else "s"], bonus))

	var line := ColorRect.new()
	line.color = Color("ffd700", 0.2)
	line.custom_minimum_size = Vector2(0, 1.5)
	column.add_child(line)

	var terrain := UiTheme.make_label(
		"Plateau %d×%d cases" % [int(_battle["cols"]), int(_battle["rows"])], 14, TEXT_BRIGHT)
	terrain.add_theme_font_override("font", UiTheme.font_black())
	terrain.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(_info_row("Terrain de bataille", terrain))

	if Game.is_battle_won(int(_battle["id"])):
		column.add_child(UiTheme.make_label(
			"(bataille déjà gagnée — récompense réduite)", 12, TEXT_DIM))


func _info_row(label_text: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := UiTheme.make_label(label_text, 14, Color("c8a84b"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	return row


# ------------------------------- BOUTON D'ACTION -----------------------------

## Le bouton de la maquette est une coque d'or SERTIE autour d'un bouton bleu :
## deux plaques imbriquees, l'or au dehors, la nuit au dedans.
func _build_cta() -> void:
	var shell := _plate(GOLD_EDGE, 3.0, 16.0, CTA_FILL)
	shell.set_padding_all(4)
	shell.inner_outline_color = Color(0, 0, 0, 0)
	shell.highlight_alpha = 0.25
	shell.custom_minimum_size = Vector2(290, 0)
	shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT and _cta_enabled:
			Router.goto_battle(int(_battle["id"])))
	_cta_row.add_child(shell)
	_cta = shell

	var inner := _plate(Color("ffd700", 0.25), 1.5, 12.0, PLATE_FILL)
	inner.set_padding(24, 16, 24, 16)
	inner.inner_outline_color = Color(0, 0, 0, 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(inner)

	var run := Game.current_run(int(_battle["id"]))
	var label := UiTheme.gold_label(
		"REPRENDRE — COMBAT %d" % run.fight if run != null and run.fight > 1
		else "PRÉPARER L'ARMÉE", 19)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(label)

	_cta.modulate.a = 1.0 if _cta_enabled else 0.5


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


## Grande plaque de section, avec son filet d'or et sa colonne interieure deja
## marginee : c'est le gabarit des trois panneaux de l'ecran.
func _panel() -> VBoxContainer:
	var plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	plate.set_padding(14, 28, 14, 18)
	_body.add_child(plate)

	var pad := _inner_padding()
	plate.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	pad.add_child(column)
	return column


## Marge interieure du filet d'or (px-12 py-8 dans la maquette).
func _inner_padding() -> MarginContainer:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	return pad


## Carte d'unite : la piece, son nom, son niveau, et pour le joueur une
## pastille d'etat. Eteinte quand la piece n'est pas de la partie - la
## maquette montre ainsi une Tour en reserve.
func _unit_card(type: String, team: String, title: String, level_text: String,
		name_size: int, status: String, active: bool) -> RoyalPlate:
	var card := _plate(GOLD_EDGE if active else OFF_EDGE, 2.0, 12.0,
		CARD_FILL if active else CARD_FILL_OFF)
	card.inner_outline_color = Color(0, 0, 0, 0)
	card.highlight_alpha = 0.08
	card.set_padding_all(8 if not status.is_empty() else 10)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not active:
		card.modulate.a = 0.6

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)

	var sprite := TextureRect.new()
	var path := "res://assets/pieces/%s/%s.png" % [team, type]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(0, 52)
	column.add_child(sprite)

	var name_label := UiTheme.make_label(title, name_size, TEXT_BRIGHT)
	name_label.add_theme_font_override("font", UiTheme.font_black())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	column.add_child(name_label)

	if not level_text.is_empty():
		var level_label: Label
		if active:
			level_label = UiTheme.gold_label(level_text, 11)
		else:
			level_label = UiTheme.make_label(level_text, 11, TEXT_DIM)
			level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(level_label)

	if not status.is_empty():
		column.add_child(_status_pill(status, active))

	UiTheme.ignore_mouse_recursive(card)
	return card


func _status_pill(text: String, active: bool) -> RoyalPlate:
	var pill := _plate(
		Color("ffd700", 0.38) if active else Color("3a3f50"), 1.0, 6.0,
		READY_FILL if active else PackedColorArray([Color("1e2236")]))
	pill.set_padding(6, 4, 6, 4)
	pill.inner_outline_color = Color(0, 0, 0, 0)
	pill.highlight_alpha = 0.0

	var label := UiTheme.make_label(text, 9, TEXT_BRIGHT if active else TEXT_DIM)
	label.add_theme_font_override("font", UiTheme.font_black())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	pill.add_child(label)
	return pill
