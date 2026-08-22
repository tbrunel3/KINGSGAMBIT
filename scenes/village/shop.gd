extends Control
##
## BOUTIQUE - en plein ecran defilant (Figma shop-screen, node-id 410:7061).
##
## Trois sections : COFFRES, GEMMES, OR.
##
## CE QUE LA BOUTIQUE VEND, ET CE QU'ELLE NE VEND PAS.
##
## Un coffre donne du TEMPS D'AMELIORATION. Pas d'or, pas de pieces, pas de
## niveau. C'est le seul contenu qui ne touche aucun chiffre mesure - ni les
## couts, ni les recompenses, ni les 10/10 de smoke_test - et c'est la vraie
## friction du jeu : 47,5 heures d'attente cumulees pour tout monter au niveau
## 10, dont 11,1 h rien que pour le Chateau Royal.
##
## IL N'Y A AUCUN TIRAGE AU SORT. La maquette affichait un tableau de
## probabilites (45/30/18/7) sur le coffre Legendaire ; le combat de ce jeu
## n'a pas une seule source d'alea, et un coffre a butin en aurait ete la
## premiere. Le panneau garde sa mise en page et devient la LEGENDE des quatre
## coffres - meme traitement que le codex : on garde la peau, on refait les
## donnees.
##
## AUCUN CHIFFRE N'EST ECRIT ICI. Prix, durees, gains, montants d'or : tout est
## relu dans Balance.SHOP a chaque ouverture. Une transcription se decale des
## que le jeu bouge, et c'est exactement ce qui avait produit le codex faux.
##
## Les regles completes sont dans chantier_h_boutique.md.
##

const RoyalPlateScript := preload("res://scenes/ui/components/royal_plate.gd")
const ModalScene := preload("res://scenes/ui/components/modal.tscn")

## Degrades de la maquette, communs a la preparation et au codex. En
## `static var` et non en `const` : GDScript n'accepte pas un PackedColorArray
## de Color("...") comme expression constante.
static var PLATE_FILL := PackedColorArray([
	Color("1e3278"), Color("0a1230"), Color("0e1a40")])
static var PANEL_FILL := PackedColorArray([Color("0a1230"), Color("0a1230")])
static var CARD_FILL := PackedColorArray([Color("12213e"), Color("0d1730")])
static var BANNER_FILL := PackedColorArray([Color("12213e")])

const GOLD_EDGE := Color("ffe680")
const GOLD := Color("ffd700")
const GEM := Color("4f9ff0")
const TEXT_BRIGHT := Color("f0f3f8")
const TEXT_DIM := Color("a0aabf")
const DISABLED_FILL := Color("2b3140")
const DISABLED_EDGE := Color("4d5568")

const CARD_MIN := Vector2(96, 0)

@onready var _background: TextureRect = $Background
@onready var _header: HBoxContainer = $Safe/Root/HeaderMargin/Header
@onready var _body: VBoxContainer = $Safe/Root/Scroll/Body

## Libelles des comptes a rebours des coffres gratuits, rafraichis chaque
## seconde. Piste -> Label.
var _countdowns: Dictionary = {}
var _tick: float = 0.0
## Etat de disponibilite au dernier rendu, pour ne reconstruire l'ecran QUE
## lorsqu'un coffre devient pret - pas a chaque seconde.
var _ready_state: Dictionary = {}


func _ready() -> void:
	_build_background()
	_build_header()
	_refresh()
	Game.gems_changed.connect(func(_a: int): _refresh())
	Game.gold_changed.connect(func(_a: int): _refresh())


## Les comptes a rebours descendent a la seconde ; l'ecran ne se reconstruit
## que quand un coffre bascule de "en attente" a "pret".
func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0:
		return
	_tick = 0.0
	var rebuild := false
	for id in _countdowns.keys():
		var was: bool = _ready_state.get(id, false)
		var now := Game.free_chest_ready(id)
		if now != was:
			rebuild = true
			break
		var label: Label = _countdowns[id]
		if is_instance_valid(label):
			label.text = UiTheme.format_span(Game.free_chest_remaining(id))
	if rebuild:
		_refresh()


func _build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("141d3a"))
	gradient.set_color(1, Color("05070f"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.35)
	texture.fill_to = Vector2(1.0, 0.35)
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
			Router.goto_village())
	_header.add_child(back)

	var arrow := Icon.new()
	arrow.icon_name = "arrow_left"
	arrow.color = TEXT_BRIGHT
	arrow.custom_minimum_size = Vector2(14, 14)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(arrow)

	var plate := _plate(GOLD_EDGE, 4.0, 16.0, PLATE_FILL)
	plate.set_padding(16, 12, 16, 12)
	plate.ornament_color = Color("3a7fe8")
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(plate)

	var pad := VBoxContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pad)
	var title := UiTheme.gold_label("BOUTIQUE", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	pad.add_child(title)

	var purses := VBoxContainer.new()
	purses.add_theme_constant_override("separation", 4)
	purses.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(purses)
	purses.add_child(_purse("diamond", GEM, "gems"))
	purses.add_child(_purse("coin", GOLD, "gold"))


## Une pastille de monnaie. `kind` decide de la valeur affichee et du signal
## qui la rafraichit.
func _purse(icon_name: String, color: Color, kind: String) -> Control:
	var plate := _plate(Color("2a3550"), 1.5, 9.0, BANNER_FILL)
	plate.set_padding(7, 3, 8, 3)
	plate.custom_minimum_size = Vector2(66, 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(row)

	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = color
	icon.custom_minimum_size = Vector2(11, 11)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var amount := Game.gems if kind == "gems" else Game.gold
	var label := _text(UiTheme.format_thousands(amount), 11, TEXT_BRIGHT)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(label)
	return plate


# ------------------------------- CORPS ---------------------------------------

func _refresh() -> void:
	_countdowns.clear()
	_ready_state.clear()
	for child in _body.get_children():
		child.queue_free()
	# La reconstruction part souvent d'un signal emis PAR un enfant qu'elle
	# libere : sans le differe, Godot refuse ("Attempted to free a locked
	# object") et l'ecran reste bloque sans qu'aucune erreur ne remonte.
	# Le chantier C a paye ce piege.
	_build_body.call_deferred()

	# L'en-tete porte les deux bourses : elle se refait avec le corps.
	for child in _header.get_children():
		child.queue_free()
	_build_header.call_deferred()


func _build_body() -> void:
	_build_chests()
	_build_gem_packs()
	_build_gold_packs()


## Bandeau de titre de section, la pastille arrondie de la maquette.
func _section(title: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	_body.add_child(wrap)

	var center := CenterContainer.new()
	wrap.add_child(center)
	var banner := _plate(Color("2a3550"), 1.5, 12.0, BANNER_FILL)
	banner.set_padding(20, 6, 20, 6)
	center.add_child(banner)
	banner.add_child(UiTheme.gold_label(title, 12))

	var panel := _plate(Color("0e1a40"), 2.0, 14.0, PANEL_FILL)
	panel.set_padding(10, 12, 10, 10)
	panel.inner_outline_color = Color("ffd700", 0.10)
	wrap.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	panel.add_child(inner)
	return inner


# ------------------------------- COFFRES -------------------------------------

func _build_chests() -> void:
	var inner := _section("COFFRES")

	# Les coffres GRATUITS. Ils ne sont dessines nulle part - la maquette ne
	# montre que les coffres achetes - mais sans eux aucune gemme n'existe :
	# elles ne s'achetent pas, aucun store n'etant branche.
	var free_row := HBoxContainer.new()
	free_row.add_theme_constant_override("separation", 8)
	inner.add_child(free_row)
	for id in Balance.free_chest_ids():
		free_row.add_child(_free_chest_card(id))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(row)
	for chest in Balance.SHOP["chests"]:
		if int(chest["seconds"]) < 0:
			continue
		row.add_child(_chest_card(chest))

	inner.add_child(_legend_panel())


func _free_chest_card(id: String) -> Control:
	var data := Balance.free_chest(id)
	var is_ready := Game.free_chest_ready(id)
	_ready_state[id] = is_ready

	var card := _plate(GOLD_EDGE if is_ready else Color("3d4f6b"), 2.0, 10.0, CARD_FILL)
	card.set_padding(8, 8, 8, 8)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.inner_outline_color = Color(0, 0, 0, 0)
	if not is_ready:
		card.modulate = Color(1, 1, 1, 0.62)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "star" if is_ready else "clock"
	icon.color = GOLD if is_ready else TEXT_DIM
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	var title := _text(_free_chest_name(id), 9, TEXT_DIM)
	col.add_child(title)

	if is_ready:
		col.add_child(_text("+%d gemmes" % int(data["gems"]), 12, GOLD))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_claim(id))
	else:
		var countdown := _text(
			UiTheme.format_span(Game.free_chest_remaining(id)), 12, TEXT_DIM)
		col.add_child(countdown)
		_countdowns[id] = countdown
	return card


## Le nom lisible d'une piste. Deduit de sa duree plutot qu'ecrit : le jour ou
## le robinet passe a deux heures, l'etiquette suit.
func _free_chest_name(id: String) -> String:
	var seconds := int(Balance.free_chest(id).get("seconds", 0))
	return "COFFRE · %s" % UiTheme.format_span(seconds).to_upper()


func _chest_card(chest: Dictionary) -> Control:
	var targets: Array = Game.upgrades_in_progress()
	var affordable := Game.can_afford_gems(int(chest["gems"]))
	var usable := not targets.is_empty()

	var card := _plate(Color("3d4f6b"), 2.0, 10.0, CARD_FILL)
	card.set_padding(6, 6, 6, 6)
	card.custom_minimum_size = CARD_MIN
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.inner_outline_color = Color(0, 0, 0, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var icon := Icon.new()
	icon.icon_name = "star"
	icon.color = GOLD if usable else TEXT_DIM
	icon.custom_minimum_size = Vector2(0, 44)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)

	var name_label := _text(_chest_name(chest), 10, TEXT_BRIGHT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)

	var span := _text(UiTheme.format_span(int(chest["seconds"])), 10, TEXT_DIM)
	span.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(span)

	col.add_child(_buy_button(int(chest["gems"]), usable and affordable,
		func(): _on_buy_chest(chest)))
	return card


func _chest_name(chest: Dictionary) -> String:
	return String(chest.get("name", chest["id"]))


## La legende des quatre coffres. C'est le panneau qui portait les
## probabilites dans la maquette : meme mise en page, quatre lignes, libelle a
## gauche et valeur a droite - mais des durees connues d'avance au lieu d'un
## tirage.
func _legend_panel() -> Control:
	var legendary: Dictionary = {}
	for chest in Balance.SHOP["chests"]:
		if int(chest["seconds"]) < 0:
			legendary = chest

	var panel := _plate(GOLD_EDGE, 2.0, 14.0, PLATE_FILL)
	panel.set_padding(12, 10, 12, 10)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var crown := Icon.new()
	crown.icon_name = "crown"
	crown.color = GOLD
	crown.custom_minimum_size = Vector2(72, 72)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crown)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	col.add_child(UiTheme.gold_label("COFFRE LÉGENDAIRE", 11))

	for chest in Balance.SHOP["chests"]:
		var seconds := int(chest["seconds"])
		var value := "termine tout" if seconds < 0 else UiTheme.format_span(seconds)
		col.add_child(_legend_row(_chest_name(chest), value, seconds < 0))

	if not legendary.is_empty():
		var usable := not Game.upgrades_in_progress().is_empty()
		var buy := _buy_button(int(legendary["gems"]),
			usable and Game.can_afford_gems(int(legendary["gems"])),
			func(): _on_buy_chest(legendary))
		buy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		buy.custom_minimum_size = Vector2(84, 24)
		col.add_child(buy)
	return panel


## Une ligne de la legende. Les deux libelles sont remis en SIZE_FILL : sans
## ca, UiTheme.make_label pose SIZE_EXPAND_FILL sur tout label et les deux
## colonnes se partagent la largeur a parts egales - la valeur se retrouve au
## milieu de la ligne au lieu d'etre alignee a droite.
func _legend_row(name: String, value: String, highlight: bool) -> Control:
	var row := HBoxContainer.new()
	var left := _text(name, 10, GOLD if highlight else TEXT_DIM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := _text(value, 10, GOLD if highlight else TEXT_BRIGHT)
	right.size_flags_horizontal = Control.SIZE_FILL
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)
	return row


# ------------------------------- GEMMES --------------------------------------

## Les packs en euros. Godot n'a pas de facturation native et le build web ne
## peut rien vendre : les cartes restent dessinees, leur bouton dit "Bientot"
## et n'appelle rien. Balance.SHOP.gem_packs_enabled les rallumera le jour
## d'un export mobile signe.
func _build_gem_packs() -> void:
	var inner := _section("GEMMES")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(row)

	var enabled: bool = Balance.SHOP.get("gem_packs_enabled", false)
	for pack in Balance.SHOP["gem_packs"]:
		row.add_child(_pack_card("diamond", GEM,
			"%s Gemmes" % UiTheme.format_thousands(int(pack["gems"])),
			String(pack["price"]) if enabled else "Bientôt",
			enabled, Callable()))


# ------------------------------- OR ------------------------------------------

func _build_gold_packs() -> void:
	var inner := _section("OR")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(row)

	var packs: Array = Balance.SHOP["gold_packs"]
	for i in range(packs.size()):
		var pack: Dictionary = packs[i]
		var index := i
		var card := _plate(Color("3d4f6b"), 2.0, 10.0, CARD_FILL)
		card.set_padding(6, 6, 6, 6)
		card.custom_minimum_size = CARD_MIN
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.inner_outline_color = Color(0, 0, 0, 0)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		card.add_child(col)

		var icon := Icon.new()
		icon.icon_name = "coin"
		icon.color = GOLD
		icon.custom_minimum_size = Vector2(0, 44)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(icon)

		var label := _text(
			"%s Or" % UiTheme.format_thousands(int(pack["gold"])), 10, TEXT_BRIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)

		col.add_child(_buy_button(int(pack["gems"]),
			Game.can_afford_gems(int(pack["gems"])),
			func(): _on_buy_gold(index)))
		row.add_child(card)


func _pack_card(icon_name: String, icon_color: Color, title: String,
		button_text: String, enabled: bool, on_press: Callable) -> Control:
	var card := _plate(Color("3d4f6b"), 2.0, 10.0, CARD_FILL)
	card.set_padding(6, 6, 6, 6)
	card.custom_minimum_size = CARD_MIN
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.inner_outline_color = Color(0, 0, 0, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = icon_color
	icon.custom_minimum_size = Vector2(0, 44)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)

	var label := _text(title, 10, TEXT_BRIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 24)
	button.add_theme_font_override("font", UiTheme.font_bold())
	button.add_theme_font_size_override("font_size", 10)
	if enabled and on_press.is_valid():
		UiTheme.style_button(button, UiTheme.GOLD)
		button.add_theme_color_override("font_color", UiTheme.GOLD_TEXT)
		button.pressed.connect(on_press)
	else:
		UiTheme.style_button(button, DISABLED_FILL)
		button.add_theme_color_override("font_color", TEXT_DIM)
		button.disabled = true
	col.add_child(button)
	return card


## Bouton d'achat en gemmes : le glyphe de la monnaie, puis le prix. Grise des
## que le prix depasse la bourse OU qu'il n'y a rien a accelerer.
##
## Trace en plaque cliquable plutot qu'en Button : le glyphe de gemme est un
## Icon, donc un Control qui se dessine - un Button veut une Texture2D, et la
## rendre demanderait d'attendre une frame au milieu de la construction de
## l'ecran.
func _buy_button(price: int, enabled: bool, on_press: Callable) -> Control:
	var plate := _plate(
		Color("c8960c") if enabled else DISABLED_EDGE, 1.5, 8.0,
		PackedColorArray([UiTheme.GOLD]) if enabled else PackedColorArray([DISABLED_FILL]))
	plate.set_padding(8, 4, 8, 4)
	plate.inner_outline_color = Color(0, 0, 0, 0)
	plate.custom_minimum_size = Vector2(0, 24)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "diamond"
	icon.color = UiTheme.GOLD_TEXT if enabled else TEXT_DIM
	icon.custom_minimum_size = Vector2(11, 11)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := _text(str(price), 11,
		UiTheme.GOLD_TEXT if enabled else TEXT_DIM)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	if enabled:
		plate.mouse_filter = Control.MOUSE_FILTER_STOP
		plate.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				on_press.call())
	return plate


# ------------------------------- ACTIONS -------------------------------------

func _on_claim(id: String) -> void:
	if Game.claim_free_chest(id) > 0:
		_refresh()


## Un coffre s'applique a UNE amelioration en cours ; le Legendaire les termine
## toutes. Avec plusieurs chantiers ouverts, le joueur choisit lequel - c'est
## sa decision, pas la notre.
func _on_buy_chest(chest: Dictionary) -> void:
	var targets: Array = Game.upgrades_in_progress()
	if targets.is_empty():
		return
	if int(chest["seconds"]) < 0 or targets.size() == 1:
		var target: String = "" if int(chest["seconds"]) < 0 else String(targets[0])
		if Game.buy_chest(String(chest["id"]), target):
			_refresh()
		return
	_ask_target(chest, targets)


func _ask_target(chest: Dictionary, targets: Array) -> void:
	var modal: Modal = ModalScene.instantiate()
	add_child(modal)
	modal.open("ACCÉLÉRER QUOI ?", Modal.Context.GOLD, "clock")

	var intro := _text(
		"Ce coffre retranche %s à un chantier." % UiTheme.format_span(int(chest["seconds"])),
		11, TEXT_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal.body.add_child(intro)

	for type in targets:
		var name := Balance.unit_name(type) if type != Balance.CASTLE else Balance.CASTLE_DATA["name"]
		var button := UiTheme.make_button(
			"%s — %s" % [name, UiTheme.format_span(Game.upgrade_remaining(type))],
			UiTheme.PANEL_LIGHT, 12)
		var target := String(type)
		button.pressed.connect(func():
			if Game.buy_chest(String(chest["id"]), target):
				modal.close()
				_refresh())
		modal.body.add_child(button)


func _on_buy_gold(index: int) -> void:
	if Game.buy_gold_pack(index):
		_refresh()


# ------------------------------- OUTILS --------------------------------------

## Libelle de boutique.
##
## UiTheme.make_label pose AUTOWRAP_WORD_SMART et SIZE_EXPAND_FILL sur TOUT
## libelle. Dans les rangees serrees de cet ecran - une pastille de 66 points,
## une carte de 96 - la largeur disponible tombe sous celle d'un mot et le
## texte se replie A UN CARACTERE PAR LIGNE : "145" devient trois lignes, la
## pastille triple de hauteur et l'en-tete entier s'etire avec elle. C'est le
## meme piege que UiTheme.stat_row documente deja.
##
## Ici, rien ne doit jamais se replier : les seuls textes longs de l'ecran
## sont dans la modale, qui rallume l'autowrap explicitement.
func _text(content: String, size: int = 16, color: Color = Color("e6ecf5")) -> Label:
	var label := UiTheme.make_label(content, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_FILL
	return label


func _plate(border: Color, width: float, radius: float,
		fill: PackedColorArray) -> RoyalPlate:
	var plate := RoyalPlateScript.new() as RoyalPlate
	plate.fill_colors = fill
	plate.border_color = border
	plate.border_width = width
	plate.corner_radius = radius
	plate.inner_outline_color = Color("ffd700", 0.18)
	plate.inner_radius = maxf(radius - 5.0, 4.0)
	return plate
