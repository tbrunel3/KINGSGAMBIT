extends Control
##
## CAMPAGNE - la carte du royaume, deroulee sur un parchemin.
##
## Reprise de la maquette V2 (Figma 02_Campagne) : le parchemin fait desormais
## 2300 points de haut pour un ecran de 852, soit pres de trois ecrans. Il est
## pense pour DEFILER, du bas - l'Oree du Bois, la premiere escarmouche - vers
## le haut, ou la Tour de la Dame attend en medaillon.
##
## Le fond est une seule image : parchemin, montagnes, forets et scenes de
## bataille y sont deja peints (les scenes de la maquette sont fondues dedans
## en mode multiply, plutot que reposees en calques - une texture au lieu de
## six, et aucun melange a regler a l'execution). Ne restent en vif que le
## chemin en pointilles et les dix cachets, qui doivent changer d'etat.
##
## Sert autant a progresser qu'a REJOUER : une bataille deja gagnee reste
## accessible pour refaire de l'or, a taux reduit (Balance.REPLAY_REWARD_RATIO).
##

## Cadre de la carte, en unites de la maquette. La carte garde cette largeur
## quel que soit le telephone : elle est centree, et le bois du decor remplit
## ce qui depasse (cf. _layout_map).
const CONTENT_WIDTH := 393.0
const CONTENT_HEIGHT := 2300.0

## Centre de chaque cachet, releve sur les frames level-N-seal de la maquette.
## Le dixieme n'est pas un cachet mais le medaillon du sommet.
const NODE_POS := [
	Vector2(207.3, 2052.0),
	Vector2(168.4, 1817.3),
	Vector2(109.3, 1586.9),
	Vector2(225.1, 1382.2),
	Vector2(275.6, 1153.2),
	Vector2(161.7, 961.7),
	Vector2(134.2, 769.1),
	Vector2(255.6, 583.8),
	Vector2(186.0, 372.2),
	Vector2(182.5, 121.5),
]

## Chemin en pointilles, exporte tel quel de la maquette (node 209:421). Le
## trace serpente d'un cachet a l'autre : il est dessine a la main, pas
## interpole, donc il vient en image plutot qu'en code.
const PATH_RECT := Rect2(88.2, 174.0, 190.0, 2074.5)

## Halo du medaillon de fin de campagne, dessine au degrade additif faute de
## filtre SVG (meme raison qu'au village, cf. CLAUDE.md).
const MEDALLION_GLOW_SIZE := Vector2(300, 300)

## Barre "RETOUR CHATEAU" : hauteur du bouton et marge sous lui, et de combien
## il glisse hors ecran quand on remonte la carte (cf. _set_bottom_bar_visible).
const BOTTOM_BAR_HEIGHT := 60.0
const BOTTOM_BAR_MARGIN := 8.0
const BOTTOM_BAR_SLIDE := 100.0

@onready var _scroll: ScrollContainer = $Scroll
@onready var _content: Control = $Scroll/Content
@onready var _map: Control = $Scroll/Content/Map
@onready var _parchment: TextureRect = $Scroll/Content/Map/Parchment
@onready var _glow_layer: Control = $Scroll/Content/Map/Glow
@onready var _path: TextureRect = $Scroll/Content/Map/Path
@onready var _seals: Control = $Scroll/Content/Map/Seals
@onready var _bottom_bar: Control = $Safe/BottomBar
## ⚠️ PLUS PERSONNE NE S'EN SERT. Le fondu au noir de la carte est passe a
## ScreenVeil (cf. _play_transition). Le noeud FadeOverlay reste dans la scene,
## transparent et en MOUSE_FILTER_IGNORE : il ne coute rien et servira si la
## carte a un jour besoin d'un voile a elle. La variable, elle, n'a plus
## d'usage - la garder ferait croire qu'il en existe un.

var _nodes: Dictionary = {}   # id -> CampaignSeal
var _medallion_glow: TextureRect
var _medallion_glow_tween: Tween
var _village_button: PanelContainer

var _last_scroll_y: float = 0.0
var _bottom_bar_visible: bool = true
var _bottom_bar_tween: Tween
var _transitioning: bool = false

## Facteur d'echelle de la carte : largeur reelle / largeur de maquette. Pose
## par _layout_map, lu partout ou une coordonnee de la CARTE doit devenir une
## coordonnee d'ECRAN (defilement, transition).
var _map_scale: float = 1.0


# ------------------------- LE GESTE, PRIS A LA MAIN --------------------------
#
#  ⚠️ LE DEFILEMENT TACTILE DE GODOT NE SUIT PAS LE DOIGT. Le joueur, apres
#  test : "ca defile mais ca devrait suivre le doigt, la ca va tres vite".
#
#  Deux causes, et aucune ne se regle par un reglage :
#
#    - le ScrollContainer ajoute une INERTIE au relachement (fling), donc la
#      carte continue toute seule apres que le doigt s'est leve ;
#    - sur le Web, un glissement tactile arrive DEUX FOIS. Godot emule la
#      souris a partir du tactile (emulate_mouse_from_touch, actif par
#      defaut) tout en delivrant l'evenement d'origine : le geste peut etre
#      compte deux fois, et la carte va deux fois trop vite.
#
#  On prend donc le geste nous-memes : un attrapeur plein ecran pose AU-DESSUS
#  du ScrollContainer fixe `scroll_vertical` a la difference exacte parcourue
#  par le doigt. Un pixel de doigt = un pixel de carte, sans inertie.
#
#  Il est au-dessus, donc les cachets ne recoivent plus rien : c'est lui qui
#  decide si le geste etait un APPUI, et qui trouve alors le cachet vise. Leur
#  propre _gui_input reste en place - il est teste par ui_test [12] et sert de
#  filet si l'attrapeur venait a disparaitre.

## Au-dela de ce deplacement, c'est un geste et non un appui. Meme valeur que
## CampaignSeal.TAP_SLOP : un pouce ne se pose pas au pixel.
const DRAG_TAP_SLOP := 12.0

var _drag_catcher: Control
var _drag_from: Vector2 = Vector2.INF
var _drag_scroll: int = 0
var _drag_travel: float = 0.0


func _ready() -> void:
	_content.resized.connect(_layout_map)
	# Le SCROLL aussi : c'est lui qui suit la fenetre, et c'est sa largeur que
	# la mise en page mesure desormais.
	_scroll.resized.connect(_layout_map)
	_layout_map()

	_build_seals()
	# APRES les cachets, AVANT le bouton du village : l'attrapeur doit couvrir
	# la carte sans recouvrir le bandeau du bas.
	_build_drag_catcher()
	_build_village_button()
	_refresh()

	# Ouvre la carte sur la bataille en cours plutot que sur un bout de
	# parchemin au hasard. On attend que la barre de defilement ait fini de
	# mesurer sa plage complete avant de fixer la position : un compte de
	# frames fixe n'est pas fiable partout (le Web peut prendre plusieurs
	# images pour stabiliser ce layout).
	var vbar := _scroll.get_v_scroll_bar()
	var guard := 0
	while vbar.max_value < _scrolled_height() - 1.0 and guard < 20:
		await get_tree().process_frame
		guard += 1
	_scroll_to_battle(Game.unlocked_battle())


func _process(_delta: float) -> void:
	var current_y := float(_scroll.scroll_vertical)
	var delta_y := current_y - _last_scroll_y
	# Un seuil evite que le moindre tremblement (rebond en butee, molette a
	# cran) ne fasse clignoter la barre.
	if absf(delta_y) > 1.5:
		_set_bottom_bar_visible(delta_y > 0.0)
	_last_scroll_y = current_y


# ------------------------------- MISE EN PAGE --------------------------------

## La carte est MISE A L'ECHELLE de la largeur de l'ecran, pas centree dans une
## largeur fixe.
##
## Elle gardait sa largeur de maquette (393) et se centrait : sur un telephone
## plus large, il restait une bande de decor brun de chaque cote. Le joueur l'a
## signalee comme un defaut, et il avait raison - rien ne peint ce "bois", ce
## n'est qu'un aplat.
##
## Ce qu'il ne faut PAS faire, et la raison d'etre de la version d'avant :
## ETIRER la carte deplacerait les cachets sans deplacer les lieux peints
## dessous, et le cachet 3 ne serait plus sur sa forteresse. Mettre a l'echelle
## le noeud PARENT n'a pas ce defaut - parchemin, sentier et cachets grandissent
## du meme facteur, donc rien ne se desaligne. Les cachets restent touchables :
## a 430 points de large le facteur vaut 1,09, a 360 il vaut 0,92.
func _layout_map() -> void:
	# La largeur se lit sur le SCROLL, pas sur le contenu.
	#
	# `Content` est un Control ordinaire : il garde la largeur minimale qu'on
	# lui donne et ne s'etire PAS dans son conteneur. Mesurer sur lui rendait
	# donc toujours 393, quelle que soit la fenetre, et la carte ne s'elargissait
	# jamais - c'est ce qui a fait croire pendant un moment que la mise a
	# l'echelle ne servait a rien.
	#
	# Rappel utile : en etirement "expand", la largeur en UNITES DE JEU n'est
	# jamais inferieure a 393. Une fenetre de 360 x 800 donne un viewport de
	# 393 x 873 - c'est la HAUTEUR qui varie, pas la largeur.
	var available := maxf(CONTENT_WIDTH, _scroll.size.x)
	_map_scale = available / CONTENT_WIDTH

	_map.position = Vector2.ZERO
	_map.size = Vector2(CONTENT_WIDTH, CONTENT_HEIGHT)
	_map.scale = Vector2(_map_scale, _map_scale)

	# La hauteur a defiler suit l'echelle, sinon la carte agrandie se retrouve
	# coupee en bas. Le test d'egalite evite de relancer `resized`, qui
	# rappellerait cette fonction.
	var scrolled := Vector2(available, _scrolled_height())
	if not _content.custom_minimum_size.is_equal_approx(scrolled):
		_content.custom_minimum_size = scrolled

	_parchment.position = Vector2.ZERO
	_parchment.size = _map.size

	_path.position = PATH_RECT.position
	_path.size = PATH_RECT.size


## Hauteur du parchemin A L'ECRAN, une fois la mise a l'echelle appliquee.
func _scrolled_height() -> float:
	return CONTENT_HEIGHT * _map_scale


## Amene la bataille demandee un peu au-dessus du milieu de l'ecran : assez
## haut pour qu'on la voie, assez bas pour qu'on devine la suite du chemin.
func _scroll_to_battle(id: int) -> void:
	var index := clampi(id - 1, 0, NODE_POS.size() - 1)
	var target: float = NODE_POS[index].y * _map_scale - _scroll.size.y * 0.62
	_scroll.scroll_vertical = int(clampf(
		target, 0.0, maxf(0.0, _scrolled_height() - _scroll.size.y)))
	_last_scroll_y = _scroll.scroll_vertical


# ------------------------- LE GESTE, PRIS A LA MAIN --------------------------

func _build_drag_catcher() -> void:
	_drag_catcher = Control.new()
	_drag_catcher.name = "DragCatcher"
	_drag_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	# Signal explicite plutot que la methode virtuelle : c'est la seule forme
	# que ui_test._press() sait declencher (cf. CLAUDE.md, le piege du banc).
	_drag_catcher.gui_input.connect(_on_drag_input)
	add_child(_drag_catcher)
	# Juste au-dessus du ScrollContainer, et donc SOUS le bandeau du bas et le
	# bouton du village, qui viennent apres lui dans la scene.
	move_child(_drag_catcher, _scroll.get_index() + 1)


func _on_drag_input(event: InputEvent) -> void:
	if _transitioning:
		return

	var click := event as InputEventMouseButton
	if click != null:
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_drag_from = click.position
			_drag_scroll = _scroll.scroll_vertical
			_drag_travel = 0.0
		elif _drag_from != Vector2.INF:
			var point := click.position
			var travelled := _drag_travel
			_drag_from = Vector2.INF
			if travelled <= DRAG_TAP_SLOP:
				_tap_at(point)
		return

	var motion := event as InputEventMouseMotion
	if motion == null or _drag_from == Vector2.INF:
		return
	_drag_travel = maxf(_drag_travel, motion.position.distance_to(_drag_from))
	# La carte suit le doigt a l'unite pres. Le ScrollContainer borne lui-meme
	# la valeur a sa plage, inutile de la clamper ici.
	_scroll.scroll_vertical = _drag_scroll - int(motion.position.y - _drag_from.y)


## Quel cachet se trouve sous ce point de l'ecran ? Rien si le doigt est tombe
## a cote.
##
## L'attrapeur est plein ecran, donc le point est en unites d'ECRAN : il faut
## le ramener dans le repere de la carte, qui defile et qui est mise a
## l'echelle de la largeur disponible.
func _tap_at(point: Vector2) -> void:
	var in_content := point + Vector2(0.0, float(_scroll.scroll_vertical)) - _map.position
	if is_zero_approx(_map_scale):
		return
	var in_map := in_content / _map_scale

	for key in _nodes.keys():
		var seal: CampaignSeal = _nodes[key]
		if not is_instance_valid(seal):
			continue
		if in_map.distance_to(_seal_center(int(key))) <= seal.radius():
			_on_node_pressed(int(key))
			return


# ------------------------------- CACHETS -------------------------------------

func _build_seals() -> void:
	var final_id := Balance.battle_count()
	for data in Balance.CAMPAIGN:
		var id := int(data["id"])
		var is_final := id == final_id
		if is_final:
			_build_medallion_glow(id)

		var seal := CampaignSeal.new()
		seal.setup(id, is_final)
		seal.position = _seal_center(id) - seal.custom_minimum_size / 2.0
		seal.pressed.connect(_on_node_pressed)
		_seals.add_child(seal)
		_nodes[id] = seal


## Centre du cachet. Les batailles au-dela de la dixieme - s'il en arrive un
## jour - se poseraient hors des reperes de la maquette : on les empile alors
## au sommet plutot que de planter.
func _seal_center(id: int) -> Vector2:
	return NODE_POS[clampi(id - 1, 0, NODE_POS.size() - 1)]


func _build_medallion_glow(id: int) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("ffd94d", 0.30))
	gradient.set_color(1, Color("ffd94d", 0.0))
	gradient.add_point(0.4, Color("ffd94d", 0.13))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_medallion_glow = TextureRect.new()
	_medallion_glow.texture = texture
	_medallion_glow.material = material
	_medallion_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medallion_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_medallion_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medallion_glow.size = MEDALLION_GLOW_SIZE
	_medallion_glow.position = _seal_center(id) - MEDALLION_GLOW_SIZE / 2.0
	_glow_layer.add_child(_medallion_glow)


## Le medaillon respire tant que la Tour de la Dame est jouable. Verrouille,
## il garde une lueur faible et fixe : la tour existe, elle ne s'ouvre pas.
func _refresh_medallion_glow(state: CampaignSeal.State) -> void:
	if _medallion_glow == null:
		return

	if state == CampaignSeal.State.LOCKED:
		if _medallion_glow_tween != null and _medallion_glow_tween.is_valid():
			_medallion_glow_tween.kill()
		_medallion_glow_tween = null
		_medallion_glow.modulate.a = 0.35
		return

	if _medallion_glow_tween != null and _medallion_glow_tween.is_valid():
		return
	_medallion_glow.modulate.a = 0.6
	_medallion_glow_tween = create_tween().set_loops()
	_medallion_glow_tween.tween_property(_medallion_glow, "modulate:a", 1.0, 1.7) \
		.set_trans(Tween.TRANS_SINE)
	_medallion_glow_tween.tween_property(_medallion_glow, "modulate:a", 0.6, 1.7) \
		.set_trans(Tween.TRANS_SINE)


# ------------------------------- BOUTON DU BAS -------------------------------

## Barre "RETOUR CHATEAU" fixe par dessus la carte. La maquette la pose a la
## fin du parchemin ; on la garde flottante, sinon elle disparait des qu'on
## remonte le chemin. En echange elle s'efface d'elle-meme quand on lit la
## carte, cf. _set_bottom_bar_visible().
func _build_village_button() -> void:
	_village_button = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("261a0d", 0.9)
	box.set_corner_radius_all(14)
	box.border_color = Color("99804d", 0.4)
	box.set_border_width_all(2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	_village_button.add_theme_stylebox_override("panel", box)
	_village_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_village_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Router.goto_village())
	_bottom_bar.add_child(_village_button)

	# Ancre en bas plutot que pose a une ordonnee calculee : la zone de jeu
	# ne fait pas 852 points de haut sur tous les telephones (cf. CLAUDE.md).
	_village_button.anchor_left = 0.0
	_village_button.anchor_right = 1.0
	_village_button.anchor_top = 1.0
	_village_button.anchor_bottom = 1.0
	_slide_bottom_bar(0.0)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	_village_button.add_child(row)
	var icon := Icon.new()
	icon.icon_name = "castle"
	icon.color = Color("d9c88a")
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := UiTheme.make_label("RETOUR CHÂTEAU", 13, Color("d9c78c"))
	text.add_theme_font_override("font", UiTheme.font_bold())
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Le bouton prend toute la largeur : sans ces deux lignes, le libelle
	# s'etale a droite de l'icone au lieu de rester colle a elle, au centre.
	text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)
	UiTheme.ignore_mouse_recursive(row)


## Une seule fonction pour poser le bouton : elle prend le decalage vertical
## de l'animation, pour que la position ancree reste la seule verite.
func _slide_bottom_bar(shift: float) -> void:
	_village_button.offset_left = 0.0
	_village_button.offset_right = 0.0
	_village_button.offset_top = -(BOTTOM_BAR_HEIGHT + BOTTOM_BAR_MARGIN) + shift
	_village_button.offset_bottom = -BOTTOM_BAR_MARGIN + shift


## Glisse la barre du bas hors ecran quand on remonte la carte (on lit, elle
## gene) et la ramene quand on redescend.
func _set_bottom_bar_visible(should_show: bool) -> void:
	if should_show == _bottom_bar_visible:
		return
	_bottom_bar_visible = should_show

	if _bottom_bar_tween != null and _bottom_bar_tween.is_valid():
		_bottom_bar_tween.kill()

	var from := _village_button.offset_bottom + BOTTOM_BAR_MARGIN
	var to := 0.0 if should_show else BOTTOM_BAR_SLIDE
	_bottom_bar_tween = create_tween()
	_bottom_bar_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bottom_bar_tween.tween_method(_slide_bottom_bar, from, to, 0.25)


# ------------------------------- RAFRAICHISSEMENT ----------------------------

func _refresh() -> void:
	var unlocked := Game.unlocked_battle()
	for data in Balance.CAMPAIGN:
		var id := int(data["id"])
		var seal: CampaignSeal = _nodes[id]

		var state := CampaignSeal.State.LOCKED
		if Game.is_battle_won(id):
			state = CampaignSeal.State.WON
		elif id <= unlocked:
			state = CampaignSeal.State.AVAILABLE
		seal.set_state(state)

		if seal.is_final:
			_refresh_medallion_glow(state)


# ------------------------------- ACTIONS -------------------------------------

func _on_node_pressed(id: int) -> void:
	if _transitioning or id > Game.unlocked_battle():
		return
	_play_transition(id)


## Petit zoom sur le cachet tape, fondu au noir, puis changement d'ecran - un
## aller-retour plat vers la preparation manquait de poids.
func _play_transition(id: int) -> void:
	_transitioning = true
	var viewport_pos := _seal_center(id) * _map_scale + _map.position \
		- Vector2(0, _scroll.scroll_vertical)
	_scroll.pivot_offset = viewport_pos

	var tween := create_tween()
	tween.set_parallel(true)
	# ⚠️ LE FONDU AU NOIR A ETE RETIRE D'ICI. Depuis que Router._change passe
	# par ScreenVeil, la carte fondait une premiere fois avec son propre
	# _fade_overlay, puis une seconde avec le voile global : deux noirs a la
	# suite. Le zoom sur le cachet reste - c'est lui qui donne le poids -, le
	# noir appartient desormais au voile.
	tween.tween_property(_scroll, "scale", Vector2(1.22, 1.22),
				Balance.motion("map_zoom")) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished

	Router.goto_prep(id)
