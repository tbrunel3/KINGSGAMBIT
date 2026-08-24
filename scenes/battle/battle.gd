extends Control
##
## BATAILLE - une seule scene, trois phases : PLACEMENT, COMBAT, RESULTAT.
##
## Une scene unique plutot que trois : l'etat du placement n'a ainsi jamais a
## transiter entre deux scenes, et le moteur de combat est construit une fois.
##
## Ce fichier ne contient aucune regle de combat. Il pose les unites, transmet
## au moteur le coup choisi par le joueur (tape ou glisser-deposer), demande a
## l'IA le coup adverse, et rejoue les evenements retournes.
##
## Le combat se joue coup par coup : une piece du joueur, une piece de l'IA, et
## RIEN ne joue a la place du joueur - ni resolution automatique, ni vitesse
## acceleree. Le plateau attend son coup aussi longtemps qu'il le faut.
##
## Le moteur, lui, sait toujours jouer les deux camps (BattleEngine.auto_mode) :
## c'est ce dont vivent les bancs de tools/, qui simulent des campagnes entieres
## sans personne devant l'ecran.
##

enum Phase { PLACEMENT, COMBAT, RESULT }

const CornerButton := preload("res://scenes/ui/components/corner_button.gd")
const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const SelectionChipScene := preload("res://scenes/ui/components/selection_chip.tscn")

@onready var _tour_badge: RoyalPlate = $Safe/Overlay/TourBadge
@onready var _phase_prefix: Label = $Safe/Overlay/TourBadge/TourRow/PhasePrefixLabel
@onready var _phase_label: Label = $Safe/Overlay/TourBadge/TourRow/PhaseLabel
@onready var _state_separator: Label = $Safe/Overlay/TourBadge/TourRow/StateSeparator
@onready var _state_label: Label = $Safe/Overlay/TourBadge/TourRow/StateLabel
@onready var _quit_button: Button = $Safe/Overlay/QuitButton
@onready var _grid_view: Control = $Safe/Overlay/Grid
@onready var _stats_hud: RoyalPlate = $Safe/Overlay/StatsHud
@onready var _stats_box: HBoxContainer = $Safe/Overlay/StatsHud/StatsBox
@onready var _bottom_panel: PanelContainer = $Safe/Overlay/BottomPanel
@onready var _bottom: VBoxContainer = $Safe/Overlay/BottomPanel/BottomBox

## Chrono de blocage (cf. Balance.COMBAT.stalemate_seconds_cap) : construit et
## detruit avec la phase de combat, jamais present pendant placement/resultat.
var _blockage_badge: PanelContainer = null
var _blockage_label: Label = null

## Fraction du seuil d'enlisement a partir de laquelle le chrono devient
## visible. Reste cache avant ca : ce garde-fou doit rester exceptionnel, pas
## un compte a rebours permanent qui inquieterait le joueur pour rien pendant
## une phase de poursuite tout a fait normale.
const _BLOCKAGE_WARNING_RATIO := 0.5

var _battle: Dictionary = {}
var _engine: BattleEngine = null
var _phase: int = Phase.PLACEMENT

## Serie de combats en cours (cf. CampaignRun). Un niveau de campagne se joue
## en 3 a 5 combats d'affilee : l'armee posable vient de la serie, pas du
## village, et les pertes n'atteignent le village qu'a la toute fin.
var _run: CampaignRun = null

# Placement
var _remaining: Dictionary = {}   # type -> unites encore disponibles
var _selected_type: String = ""
var _placed: Array = []           # BattleUnit du joueur poses sur la grille

# Combat
var _running: bool = false

## Piece du joueur actuellement selectionnee (tape ou saisie au doigt).
var _selected_unit: BattleUnit = null
## Raison rendue par le moteur a la fin du combat ("plus aucun coup possible",
## "plus aucune capture possible"...). Sert a l'ecran de resultat : "NUL" seul
## ne dit pas au joueur CE QUI s'est passe.
var _end_reason: String = ""

## Vrai pendant qu'une animation ou le tour de l'IA se joue : le plateau
## n'accepte alors aucun geste, sinon un joueur rapide jouerait deux coups.
var _busy: bool = false

## Dames emmenees au combat, relevees au moment ou la bataille commence. Une
## Dame partie se battre ne tient plus la cour : elle ne rapporte pas sa part
## d'or (cf. GameState.dame_gold_bonus).
var _dames_deployed: int = 0

## Pions menes au bout du plateau pendant cette bataille, qu'ils en soient
## revenus ou non : la mission "mene un pion jusqu'au bout" recompense
## l'exploit, pas la chance de survivre au coup suivant.
var _promotions_this_battle: int = 0

# Elements rafraichis souvent, gardes sous la main.
var _status_label: Label = null
var _type_buttons: Dictionary = {}
var _fight_button: Button = null
var _reset_button: Button = null


func _ready() -> void:
	_battle = Router.current_battle()
	if _battle.is_empty():
		Router.leave_battle_for_village()
		return

	_style_stats_hud()
	_style_quit_button()
	_build_help_button()

	# Serie : on reprend celle en cours sur cette bataille, sinon on en ouvre
	# une. Quitter en plein combat fait donc RECOMMENCER ce combat-la, avec
	# l'effectif qu'il avait au depart - pas la serie entiere.
	var battle_id := int(_battle["id"])
	_run = Game.current_run(battle_id)
	if _run == null:
		_run = Game.begin_run(battle_id)

	_engine = BattleEngine.new(int(_battle["cols"]), int(_battle["rows"]))
	_engine.enemy_skill = Balance.battle_ai_skill(_battle)
	_spawn_enemies()

	# Ce que le placement propose est la COMPOSITION choisie a la preparation,
	# pas l'armee entiere : la charge s'est deja depensee la-bas. Sans
	# composition - premiere bataille jamais preparee, ou un banc qui saute
	# l'ecran - c'est le roster, comme avant (cf. CampaignRun.deployable).
	var pool := _run.deployable()
	for type in Balance.ARMY_TYPES:
		_remaining[type] = int(pool.get(type, 0))

	_grid_view.setup(_engine)
	_grid_view.cell_clicked.connect(_on_cell_clicked)
	_grid_view.cell_pressed.connect(_on_cell_pressed)
	# Le troisieme geste du placement : porter une piece de l'inventaire
	# directement sur sa case. La vue ne decide rien - elle nous demande.
	_grid_view.accepte_lacher = _peut_poser
	_grid_view.inventaire_lachee.connect(_on_inventaire_lachee)
	_grid_view.piece_dropped.connect(_on_piece_dropped)
	_grid_view.draggable_team = BattleUnit.TEAM_PLAYER

	_enter_placement()
	_animate_entry()
	_warn_about_series()


## Explique la serie, une fois, au moment ou le joueur la decouvre : au
## placement du PREMIER combat d'une bataille qui en compte plusieurs. Pas au
## combat 2, ou il serait deja trop tard pour comprendre ce qui vient de se
## passer.
func _warn_about_series() -> void:
	if Balance.battle_fights(_battle) <= 1:
		return
	if _run != null and _run.fight > 1:
		return
	if Game.has_seen_series_warning():
		return
	Game.mark_series_warning_seen()
	var popup: Control = preload("res://scenes/battle/series_popup.tscn").instantiate()
	add_child(popup)
	popup.setup(Balance.battle_fights(_battle))


## Niveau auquel une piece part au combat : celui de son batiment. La Dame
## n'ayant pas de caserne qui s'ameliore, elle garde le niveau de la Caserne
## des Pions - elle EST un pion promu, sa mobilite suit celle des pions.
func _unit_level(type: String) -> int:
	if type == Balance.DAME:
		# Les Dames vivent au Chateau Royal et montent avec lui, sans jamais
		# depasser le nombre de Dames abritees (cf. GameState.dame_level).
		# Une Dame promue EN COURS de bataille, elle, garde le niveau du pion
		# qu'elle etait.
		return Game.dame_level()
	return Game.building_level(type)


## Numero de la bataille en cours.
func _battle_id() -> int:
	return int(_battle["id"])


## Types que le joueur peut poser sur la grille : ses casernes, plus la Dame
## s'il en a ramene une vivante d'une bataille precedente.
##
## C'est l'effectif de la SERIE qui decide, pas l'armee du village : une Dame
## tombee au premier combat ne se repose pas au deuxieme.
func _deployable_types() -> Array:
	var types: Array = []
	for type in Balance.ARMY_TYPES:
		if type == Balance.DAME and _owned(Balance.DAME) <= 0:
			continue
		types.append(type)
	return types


## Pieces de ce type engagees dans ce COMBAT, posees ou non - la composition
## si le joueur en a valide une, le roster de la serie sinon. `_remaining` ne
## compte que celles qui restent en main pendant le placement.
func _owned(type: String) -> int:
	if _run == null:
		return Game.units_owned(type)
	return int(_run.deployable().get(type, 0))


# ------------------------------- AIDE ----------------------------------------
#
#  Un jeu d'echecs qui n'est pas tout a fait un jeu d'echecs a besoin de dire
#  ses regles quelque part. Le "i" est le seul endroit du jeu ou on les ecrit
#  noir sur blanc : ce qu'est la charge, comment on joue un coup, ce qui
#  arrive a un pion qui traverse le plateau.
#
#  Le contenu suit la phase en cours - pendant le placement on ne parle pas
#  encore de captures, et pendant le combat on ne reparle pas de la zone
#  bleue.

## Les deux ronds du bord droit (Btn-Exit et Btn-Info de la maquette v2) :
## 34 points de diametre, bleu nuit cercle d'or, EMPILES - la sortie en haut,
## l'aide juste dessous.
##
## Ils remplacent le gros bouton rouge "X" et le rond gris qui l'accompagnait.
## Quitter une bataille n'est pas une action dangereuse qu'il faut peindre en
## rouge : c'est une sortie, et le rouge de l'ecran est celui de l'ennemi.
## ⚠️ CES TROIS VALEURS NE SONT PLUS DECLAREES ICI.
##
## La bataille etait la reference - 34 points, ancres a droite - et c'est elle
## qui a donne sa taille au composant partage. Elles viennent donc de lui
## maintenant : six tailles de bouton de coin ramenees a deux ne tiennent que
## s'il n'y a qu'UN endroit qui les ecrit.
const _CORNER_BUTTON := CornerButton.FLOATING_SIZE
const _CORNER_TOP := CornerButton.STACK_MARGIN.y
const _CORNER_GAP := CornerButton.STACK_GAP


## Habillage commun aux deux ronds, cf. Btn-Exit / Btn-Info.
## ⚠️ LA CROIX DE SORTIE RESTE UN Button DE LA SCENE, elle.
##
## battle.tscn la declare ($Safe/Overlay/QuitButton), et un Button sait ce
## qu'un Control ne sait pas : les etats hover et pressed. La sortir de la
## scene pour gagner quelques lignes couterait une chirurgie de .tscn sur
## l'ecran le plus teste du jeu, sans rien changer a ce que le joueur voit.
##
## Ce qui compte est ailleurs : la TAILLE et les COULEURS viennent desormais du
## composant partage. Il n'y a plus qu'un endroit ou les changer.
func _corner_button_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = CornerButton.FILL[CornerButton.Tone.NIGHT]
	box.set_corner_radius_all(int(_CORNER_BUTTON * 0.5))
	box.border_color = CornerButton.EDGE[CornerButton.Tone.NIGHT]
	box.set_border_width_all(1.5)
	box.set_content_margin_all(0)
	return box


## Ancre un rond au bord droit, a `rank` places sous le premier.
##
## Les offsets se calculent ici plutot que de se lire sur le voisin : au
## moment du _ready() la mise en page n'a pas encore tourne, et la position
## d'un frere vaut encore son offset negatif.
func _place_corner_button(node: Control, rank: int) -> void:
	node.anchor_left = 1.0
	node.anchor_right = 1.0
	node.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	node.offset_left = -(_CORNER_BUTTON + 6.0)
	node.offset_right = -6.0
	node.offset_top = _CORNER_TOP + rank * (_CORNER_BUTTON + _CORNER_GAP)
	node.offset_bottom = node.offset_top + _CORNER_BUTTON


## LE MOT QUI OUVRE LE COMBAT - il barre le plateau, puis s'efface.
##
## Releve sur 05_Bataille_Combat (433:3) : il surgit de 1,5 a 1 en 0,25 s avec
## un ressort, tient, puis ENFLE a 2 en s'effacant sur 0,60 s. Ce n'est pas un
## fondu : le mot grandit en partant, comme s'il passait devant la camera.
##
## Il marque le passage du placement au combat. Sans lui, le joueur pose sa
## derniere piece et se retrouve deja en train de jouer, sans transition.
##
## ⚠️ Enfant de Safe/Overlay, un Control NU : c'est ce qui autorise a lui poser
## une echelle et une position sans que la mise en page les reprenne.
const OPENING_WORD_IN := 0.25
const OPENING_WORD_OUT := 0.60


func _show_opening_word() -> void:
	var word := UiTheme.make_label("COMBATTEZ", 40, UiTheme.GOLD)
	word.name = "OpeningWord"
	word.add_theme_font_override("font", UiTheme.font_display())
	# ⚠️ make_label pose SIZE_EXPAND_FILL et l'autowrap sur TOUT libelle : sans
	# ces deux lignes, "COMBATTEZ" se replie sur plusieurs lignes.
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.size_flags_horizontal = Control.SIZE_FILL
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tour_badge.get_parent().add_child(word)
	word.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	await get_tree().process_frame
	if not is_instance_valid(word):
		return
	word.pivot_offset = word.size * 0.5
	word.scale = Vector2(1.5, 1.5)
	word.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(word, "modulate:a", 1.0, OPENING_WORD_IN * 0.8)
	tween.parallel().tween_property(word, "scale", Vector2.ONE, OPENING_WORD_IN) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(float(Balance.COMBAT.get("opening_word_seconds", 0.45)))
	tween.tween_property(word, "modulate:a", 0.0, OPENING_WORD_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(word, "scale", Vector2(2, 2), OPENING_WORD_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(word.queue_free)


## Le point d'aide passe au composant partage. Il perd au passage son glyphe
## trace en LIBELLE ("i" dans un Label, centre a la main) au profit de l'icone
## "info" que icon.gd dessine deja - le meme glyphe que le codex au village.
func _build_help_button() -> void:
	var help: Control = CornerButton.floating("info", _open_help)
	_quit_button.get_parent().add_child(help)
	help.stack_top_right(1, Vector2(6.0, _CORNER_TOP))


## La croix de sortie, premier des deux ronds du bord droit.
func _style_quit_button() -> void:
	_quit_button.text = "✕"
	_quit_button.theme_type_variation = &""
	_quit_button.add_theme_font_size_override("font_size", 16)
	_quit_button.add_theme_color_override("font_color", Color("ffe580"))
	_quit_button.add_theme_color_override("font_hover_color", Color("ffe580"))
	_quit_button.add_theme_color_override("font_pressed_color", Color("fff2c2"))
	for state in ["normal", "hover", "pressed", "focus"]:
		_quit_button.add_theme_stylebox_override(state, _corner_button_style())
	_place_corner_button(_quit_button, 0)
	_quit_button.pressed.connect(_on_quit)


func _open_help() -> void:
	var modal: Modal = ModalScene.instantiate()
	add_child(modal)
	modal.open("COMMENT JOUER", Modal.Context.BLUE, "info")

	if _phase == Phase.PLACEMENT:
		_fill_placement_help(modal.body)
	else:
		_fill_combat_help(modal.body)


func _fill_placement_help(body: VBoxContainer) -> void:
	body.add_child(_help_step("1", "Choisis un type, tape la zone bleue",
		"Chaque tape pose une piece. Tape une piece deja posee pour la reprendre, " +
		"ou fais-la glisser pour la deplacer - deux pieces qui se croisent echangent leur case."))
	body.add_child(_help_step("2", "Surveille la charge",
		"Le chateau ne porte pas un nombre de pieces mais un POIDS total, affiche a " +
		"droite du plateau. Une piece forte pese plus lourd :"))
	body.add_child(_help_weights())
	body.add_child(_help_step("3", "COMBATTRE quand tu es pret",
		"Tes pieces partent exactement d'ou tu les as posees. L'ennemi, lui, est " +
		"deja en place dans la zone rouge."))


func _fill_combat_help(body: VBoxContainer) -> void:
	body.add_child(_help_step("1", "Une piece par tour, chacun son tour",
		"Tu joues un coup, l'ennemi repond. Rien ne tourne pendant que tu reflechis."))
	body.add_child(_help_step("2", "Tape une piece, puis sa case",
		"Une pastille bleue marque une case libre, un anneau dore une piece a prendre. " +
		"Tu peux aussi faire glisser la piece directement jusqu'a sa case."))
	body.add_child(_help_step("3", "On capture en se deplacant",
		"Il n'y a ni degats ni points de vie : aller sur la case d'un adversaire le " +
		"capture. Une piece capturee est perdue pour de bon, des deux cotes."))
	body.add_child(_help_step("4", "Mene un pion au bout du plateau",
		"Il devient Dame sur-le-champ. Ramene-la vivante et elle s'installe a la Tour " +
		"de la Dame, au village."))
	body.add_child(_help_note(
		"AUTO confie les deux camps a l'IA jusqu'a la fin du combat - pratique pour " +
		"rejouer vite une bataille deja gagnee."))


## Une etape numerotee : pastille ronde a gauche, titre + explication a droite.
func _help_step(number: String, title: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var badge := PanelContainer.new()
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = Color(UiTheme.ACCENT, 0.22)
	badge_box.border_color = Color(UiTheme.ACCENT, 0.7)
	badge_box.set_border_width_all(1)
	badge_box.set_corner_radius_all(11)
	badge.add_theme_stylebox_override("panel", badge_box)
	badge.custom_minimum_size = Vector2(22, 22)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var badge_label := UiTheme.make_label(number, 11, Color("cce4ff"))
	badge_label.add_theme_font_override("font", UiTheme.font_bold())
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	row.add_child(badge)

	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UiTheme.make_label(title, 12, Color("f0f3f8"))
	head.add_theme_font_override("font", UiTheme.font_bold())
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(head)
	var detail := UiTheme.make_label(text, 11, Color("a0aabf"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail)
	row.add_child(texts)

	return row


## Le bareme des poids, lu directement dans Balance : c'est LA chose que le
## joueur ne peut deviner nulle part ailleurs dans le jeu.
func _help_weights() -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1c1f2e")
	box.set_corner_radius_all(8)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	for type in Balance.ARMY_TYPES:
		if type == Balance.DAME and _owned(Balance.DAME) <= 0:
			continue
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)

		var path := "res://assets/pieces/bleu/%s.png" % type
		if ResourceLoader.exists(path):
			var sprite := TextureRect.new()
			sprite.texture = load(path)
			sprite.custom_minimum_size = Vector2(26, 26)
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			column.add_child(sprite)

		var weight := UiTheme.make_label(str(Balance.deploy_weight(type)), 13, UiTheme.GOLD)
		weight.add_theme_font_override("font", UiTheme.font_bold())
		weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weight.autowrap_mode = TextServer.AUTOWRAP_OFF
		column.add_child(weight)
		row.add_child(column)

	return panel


func _help_note(text: String) -> Label:
	var label := UiTheme.make_label(text, 11, Color("8fa0b8"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Badge de tour (haut-gauche), ecrans 04 et 05 de la maquette v2.
##
## C'est une PLAQUE ROYALE, comme la preparation, la victoire et la defaite :
## bleu nuit en degrade, cercle d'or. Les deux ecrans de bataille etaient les
## derniers a parler un autre dialecte - une pastille bleue au placement, une
## pastille or au combat - alors qu'ils sont l'ecran ou le joueur passe le plus
## clair de son temps.
##
## Le badge porte aussi L'ETAT DU TOUR pendant le combat, et c'est ce qui a
## permis de supprimer le bandeau du bas : cf. _build_combat_ui.
func _style_tour_badge(prefix_color: Color, prefix_size: int,
		main_color: Color, main_size: int) -> void:
	_tour_badge.fill_colors = PackedColorArray([
		Color("1e3278"), Color("0a1230"), Color("0e1a40")])
	_tour_badge.gradient_horizontal = true
	_tour_badge.border_color = Color("ffe580")
	_tour_badge.border_width = 2.0
	_tour_badge.corner_radius = 10.0
	_tour_badge.inner_outline_color = Color(0, 0, 0, 0)
	_tour_badge.set_padding(14, 9, 14, 9)
	_tour_badge.queue_redraw()

	_phase_prefix.add_theme_color_override("font_color", prefix_color)
	_phase_prefix.add_theme_font_size_override("font_size", prefix_size)
	_phase_prefix.add_theme_font_override("font", UiTheme.font_bold())
	_phase_label.add_theme_color_override("font_color", main_color)
	_phase_label.add_theme_font_size_override("font_size", main_size)
	_phase_label.add_theme_font_override("font", UiTheme.font_bold())

	# Le badge se retaille sur son contenu : "PHASE DE PLACEMENT" et
	# "TOUR 12 - L'ENNEMI JOUE..." n'ont pas la meme longueur, et une largeur
	# figee coupait l'un ou laissait l'autre flotter dans le vide.
	_tour_badge.reset_size()


func _style_placement_badge() -> void:
	_style_tour_badge(Color("ffe580", 0.7), 11, Color("ffe580"), 15)
	# Le badge dit ou l'on en est dans la SERIE : c'est le seul endroit de
	# l'ecran de placement qui le rappelle, et c'est ce qui change la facon de
	# poser son armee - on ne place pas pareil au premier combat sur trois et
	# au dernier.
	if _run != null and _run.total > 1:
		_phase_prefix.text = "COMBAT %d/%d —" % [_run.fight, _run.total]
	else:
		_phase_prefix.text = "PHASE DE"
	_phase_label.text = "PLACEMENT"
	_set_badge_state("")


func _style_combat_badge() -> void:
	_style_tour_badge(Color("ffe580", 0.7), 11, Color("ffe580"), 18)
	_phase_prefix.text = "TOUR"


## Troisieme ligne du badge : l'etat du tour, apres un point mediant. Vide, le
## point disparait avec elle plutot que de flotter tout seul en fin de badge.
func _set_badge_state(text: String) -> void:
	_state_label.text = text
	_state_label.visible = not text.is_empty()
	_state_separator.visible = not text.is_empty()
	_state_separator.text = "·"
	_state_separator.add_theme_color_override("font_color", Color("ffe580", 0.5))
	_state_separator.add_theme_font_size_override("font_size", 16)
	_state_separator.add_theme_font_override("font", UiTheme.font_bold())
	_state_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_state_label.add_theme_font_size_override("font_size", 10)
	# La maquette demande Inter Semi Bold ; a 10 points, le Bold que le theme
	# charge deja ne s'en distingue pas - une graisse de plus a embarquer pour rien.
	_state_label.add_theme_font_override("font", UiTheme.font_bold())

	# Le badge se retaille sur son texte : un message trop long le ferait passer
	# SOUS les ronds du bord droit. On borne la place laissee a l'etat plutot
	# que de compter sur la retenue des messages a venir - le jour ou l'un
	# depasse, il se coupe proprement au lieu de disparaitre sous la croix.
	_tour_badge.reset_size()
	var libre: float = _tour_badge.get_parent().size.x - _tour_badge.position.x 		- (_CORNER_BUTTON + 14.0)
	if libre > 0.0 and _tour_badge.size.x > libre:
		_state_label.clip_text = true
		_state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_state_label.custom_minimum_size.x = maxf(
			0.0, libre - (_tour_badge.size.x - _state_label.size.x))
		_state_label.size_flags_horizontal = Control.SIZE_FILL
		_tour_badge.reset_size()


## HUD d'effectifs (Stats-HUD, ecrans 04 et 05) : une PLAQUE ROYALE comme le
## badge de tour, en plus petit et en plus discret - bleu nuit a 90 %, filet
## d'or a 70 %. Meme habillage dans les deux phases, seul le contenu change.
func _style_stats_hud() -> void:
	_stats_hud.fill_colors = PackedColorArray([
		Color("1e3278", 0.9), Color("0a1230", 0.9)])
	_stats_hud.gradient_horizontal = true
	_stats_hud.border_color = Color("ffe580", 0.7)
	_stats_hud.border_width = 1.5
	_stats_hud.corner_radius = 8.0
	_stats_hud.inner_outline_color = Color(0, 0, 0, 0)
	_stats_hud.set_padding_all(10)
	_stats_hud.queue_redraw()

	# Le HUD flotte AU-DESSUS du plateau (cf. maquettes 04/05) : sur un
	# plateau reduit il recouvre la colonne de droite. Il doit donc laisser
	# passer le doigt, sinon les pieces qu'il survole deviennent injouables.
	UiTheme.ignore_mouse_recursive(_stats_hud)


func _exit_tree() -> void:
	_running = false


# ------------------------------- MISE EN PLACE -------------------------------

func _spawn_enemies() -> void:
	var level := int(_battle["level"])
	var enemies: Dictionary = _battle["enemies"]
	var cells: Array = _engine.grid.free_enemy_cells()

	# L'armee ennemie revient AU COMPLET a chaque combat de la serie - c'est
	# l'usure du joueur qui fait la difficulte, pas une armee qui grossit.
	# Mais elle ne se range pas deux fois pareil : sans ca, rejouer le meme
	# plateau trois a cinq fois d'affilee, ce serait rejouer la meme partie.
	#
	# Le premier combat garde le rangement de reference (masse au centre, cf.
	# GridModel.free_enemy_cells), qui est celui pense pour decouvrir le
	# plateau. Le tirage des suivants est SEME sur le numero du combat : la
	# meme serie redonne toujours la meme disposition, donc reprendre apres
	# avoir ferme le jeu ne rebat pas les cartes.
	var fight: int = _run.fight if _run != null else 1
	if fight > 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(_battle["id"]), fight])
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap = cells[i]
			cells[i] = cells[j]
			cells[j] = swap

	var index := 0
	for type in Balance.UNIT_TYPES:
		if not enemies.has(type):
			continue
		for i in range(int(enemies[type])):
			if index >= cells.size():
				push_warning("Zone ennemie trop petite pour la bataille %d" % int(_battle["id"]))
				return
			_engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, cells[index])
			index += 1


## ENTREE DU PLACEMENT - relevee sur Figma 04_Bataille_Placement (410:667),
## 3 s et 17 noeuds, la timeline la plus riche du fichier.
##
## L'ecran se monte en cascade : le decor, puis le plateau qui se pose en
## reculant d'un huitieme, puis le badge de tour qui tombe du haut, le HUD qui
## glisse de la droite, le bandeau qui monte du bas, et enfin les puces qui
## eclosent l'une apres l'autre. C'est l'ecran ou le joueur passe le plus de
## temps ; il merite d'arriver, pas d'apparaitre.
##
## POURQUOI ON PEUT ANIMER LA POSITION ICI, ET PAS DANS battle_prep.
##
## La regle du projet est de ne JAMAIS animer la position d'un enfant de
## conteneur : le tween se bat avec la mise en page, et c'est ce qui avait
## colle le bandeau de serie en haut de l'ecran. Mais "Safe/Overlay" est un
## Control NU, pas un conteneur : ses enfants sont places par ancres et
## personne ne les repositionne pendant le tween. Les translations de la
## maquette sont donc jouables telles quelles.
##
## Les PUCES, elles, vivent dans un VBoxContainer : elles n'ont droit qu'a
## l'opacite et a l'echelle - ce que la maquette leur donne de toute facon.
func _animate_entry() -> void:
	var overlay := $BackgroundOverlay as ColorRect
	var fades := $EdgeFades as Control

	# On eteint TOUT des maintenant : rien ne doit apparaitre, pas meme une
	# image, avant que la cascade commence.
	var animated: Array = [overlay, fades, _grid_view, _tour_badge, _stats_hud, _bottom_panel]
	for node in animated:
		if is_instance_valid(node):
			node.modulate.a = 0.0

	var chips: Array = []
	for type in Balance.ARMY_TYPES:
		if _type_buttons.has(type):
			var chip: Control = _type_buttons[type]
			chip.modulate.a = 0.0
			chip.scale = Vector2.ZERO
			chips.append(chip)
	for button in [_reset_button, _fight_button]:
		if is_instance_valid(button):
			button.modulate.a = 0.0
			button.scale = Vector2(0.85, 0.85)

	# ⚠️ ON ATTEND LA MISE EN PAGE AVANT DE LIRE LA MOINDRE POSITION.
	#
	# Ces controles sont places par ANCRES : tant que Godot n'a pas fait sa
	# passe de mise en page, leur `position` ne vaut rien. Les relever a la
	# construction et tweener vers ces valeurs, c'est ramener le HUD et le
	# bandeau vers des coordonnees fausses - mesure sur resolutions.tscn : le
	# bandeau de deploiement restait INVISIBLE hors de l'ecran et le HUD de
	# charge a demi sorti par la droite, sur TOUS les formats.
	#
	# Meme raison pour les pivots : a la construction, size vaut encore zero
	# et tout grandirait depuis le coin superieur gauche.
	await get_tree().process_frame
	if not is_inside_tree():
		return

	var badge_home := _tour_badge.position
	var hud_home := _stats_hud.position
	var panel_home := _bottom_panel.position

	_tour_badge.position = badge_home + Vector2(0, -80)
	_stats_hud.position = hud_home + Vector2(70, 0)
	_bottom_panel.position = panel_home + Vector2(0, 200)

	for node in [_grid_view, _tour_badge]:
		node.pivot_offset = node.size / 2.0
	for chip in chips:
		chip.pivot_offset = chip.size / 2.0
	for button in [_reset_button, _fight_button]:
		if is_instance_valid(button):
			button.pivot_offset = button.size / 2.0

	_grid_view.scale = Vector2(1.08, 1.08)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(overlay, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(fades, "modulate:a", 1.0, 0.35).set_delay(0.2).set_ease(Tween.EASE_OUT)

	tween.tween_property(_grid_view, "modulate:a", 1.0, 0.4).set_delay(0.15)
	tween.tween_property(_grid_view, "scale", Vector2.ONE, 0.45).set_delay(0.15) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	tween.tween_property(_tour_badge, "modulate:a", 1.0, 0.2).set_delay(0.25)
	tween.tween_property(_tour_badge, "position", badge_home, 0.4).set_delay(0.25) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_tour_badge, "scale", Vector2.ONE, 0.4).set_delay(0.25) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	tween.tween_property(_bottom_panel, "modulate:a", 1.0, 0.3).set_delay(0.4)
	tween.tween_property(_bottom_panel, "position", panel_home, 0.5).set_delay(0.4) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	tween.tween_property(_stats_hud, "modulate:a", 1.0, 0.25).set_delay(0.5)
	tween.tween_property(_stats_hud, "position", hud_home, 0.45).set_delay(0.5) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Les quatre puces eclosent en cascade, 80 ms d'ecart - le meme decalage
	# que la maquette entre Chip-PION et Chip-CAVALIER.
	for i in range(chips.size()):
		var delay := 0.7 + i * 0.08
		tween.tween_property(chips[i], "modulate:a", 1.0, 0.15).set_delay(delay)
		tween.tween_property(chips[i], "scale", Vector2.ONE, 0.35).set_delay(delay) 			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

	var button_delay := 1.05
	for button in [_reset_button, _fight_button]:
		if not is_instance_valid(button):
			continue
		tween.tween_property(button, "modulate:a", 1.0, 0.3).set_delay(button_delay)
		tween.tween_property(button, "scale", Vector2.ONE, 0.3).set_delay(button_delay) 			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		button_delay += 0.1


# ------------------------------- PHASE PLACEMENT -----------------------------

func _enter_placement() -> void:
	_phase = Phase.PLACEMENT
	_style_placement_badge()
	_style_bottom_panel(Color("0f121f", 0.92), 16, 0)
	_place_bottom_panel(189)
	_grid_view.show_zones = true
	_grid_view.queue_redraw()
	_build_placement_ui()
	_refresh_placement()
	_refresh_stats_hud()


## Le panneau du bas est colle au bord inferieur de l'ecran et occupe toute
## la largeur : on ne lui donne que sa HAUTEUR. Le poser en coordonnees
## absolues (les 635 / 747 de la maquette) le decollait du bas des que
## l'appareil n'avait pas exactement le format 393 x 852.
##
## La grille recupere tout ce qui reste entre les badges du haut et ce
## panneau : sur un ecran plus grand, les cases grandissent au lieu de
## laisser une bande vide.
func _place_bottom_panel(height: float) -> void:
	_bottom_panel.offset_top = -height
	_bottom_panel.offset_bottom = 0.0
	_grid_view.offset_bottom = -(height + 10.0)


## Panneau bas (Control-Panel, ecrans 04 et 05) : coins arrondis en haut
## pendant le placement, plat pendant le combat - cf. maquettes Figma.
func _style_bottom_panel(bg: Color, radius_top: int, radius_bottom: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = radius_top
	box.corner_radius_top_right = radius_top
	box.corner_radius_bottom_left = radius_bottom
	box.corner_radius_bottom_right = radius_bottom
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 16
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 16
	box.shadow_offset = Vector2(0, -4)
	_bottom_panel.add_theme_stylebox_override("panel", box)


func _build_placement_ui() -> void:
	_clear_bottom()

	var header := HBoxContainer.new()
	_bottom.add_child(header)

	var header_label := UiTheme.make_label("DÉPLOIEMENT", 11, Color("ccccd9"))
	header_label.add_theme_font_override("font", UiTheme.font_bold())
	header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(header_label)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_status_label = UiTheme.make_label("", 10, Color("e5bf4d"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Sans clip_text, un message un peu long pousse hors du panneau (393 pt de
	# large, marges comprises) et se fait couper par le bord de l'ecran.
	_status_label.clip_text = true
	# clip_text ramene la largeur minimale a zero : sans ce plancher, l'espaceur
	# de l'en-tete prend toute la place et le message n'a plus rien pour
	# s'afficher.
	_status_label.custom_minimum_size = Vector2(120, 0)
	header.add_child(_status_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_bottom.add_child(row)

	# Tous les types de l'armee ont leur chip, y compris ceux qu'on ne possede
	# pas encore : la Dame doit se voir AVANT d'en avoir une, sinon le jour ou
	# elle apparait personne ne comprend d'ou sort ce bouton. Un type absent
	# porte la silhouette grisee (assets/pieces/absent) et un compteur a zero.
	_type_buttons.clear()
	for type in Balance.ARMY_TYPES:
		var chip: SelectionChip = SelectionChipScene.instantiate()
		var folder := "bleu" if int(_remaining[type]) > 0 else "absent"
		var texture := UiTheme.piece_texture(folder, type)
		row.add_child(chip)
		# Le type descend DANS la chip : c'est ce qu'elle donnera au plateau
		# quand on la fera glisser (cf. SelectionChip._get_drag_data).
		chip.piece_type = type
		chip.set_piece.call_deferred(texture, Balance.unit_name(type).to_upper(), int(_remaining[type]))
		chip.pressed.connect(_on_type_selected.bind(type))
		_type_buttons[type] = chip

	var actions := HBoxContainer.new()
	# 6 plutot que 8 : a trois boutons, chaque point compte. Le bandeau doit
	# tenir dans les 329 points utiles d'un ecran de 393, marges comprises.
	actions.add_theme_constant_override("separation", 6)
	_bottom.add_child(actions)

	# DERNIERE FORMATION remplace l'ancien bouton AUTO, qui rangeait l'armee a
	# la place du joueur. Masque tant qu'il n'y a rien en memoire : a la toute
	# premiere bataille on pose a la main, et c'est la qu'on apprend le placement.
	#
	# SUR DEUX LIGNES, comme la maquette. Ecrit d'un seul tenant, le libelle est
	# si large qu'il poussait COMBATTRE hors de l'ecran : le bandeau existe en
	# deux etats, a deux boutons et a trois, et c'est le second qui deborde.
	if Game.has_remembered_formation(_battle_id()):
		var last := UiTheme.make_button("DERNIÈRE
FORMATION", Color(1, 1, 1, 0.08), 10)
		last.add_theme_font_override("font", UiTheme.font_bold())
		last.add_theme_color_override("font_color", Color("ccccd9"))
		last.pressed.connect(_on_last_formation)
		actions.add_child(last)

	var reset := UiTheme.make_button("RÉINITIALISER", Color(1, 1, 1, 0.08), 12)
	reset.add_theme_font_override("font", UiTheme.font_bold())
	reset.add_theme_color_override("font_color", Color("ccccd9"))
	reset.pressed.connect(_on_reset_placement)
	actions.add_child(reset)
	_reset_button = reset

	# Pas d'espaceur ici : sur 393 points de large, pousser COMBATTRE contre le
	# bord droit le fait sortir du panneau. C'est REINITIALISER, le bouton le
	# plus large, qui absorbe la place restante.
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_fight_button = UiTheme.make_button("COMBATTRE", UiTheme.GOLD, 12)
	_fight_button.add_theme_font_override("font", UiTheme.font_bold())
	_style_fight_button()
	_fight_button.pressed.connect(_start_combat)
	actions.add_child(_fight_button)

	# Selectionne d'office le premier type disponible.
	for type in _deployable_types():
		if int(_remaining[type]) > 0:
			_selected_type = type
			break


## Le bouton COMBATTRE de la maquette n'est pas un bouton or ordinaire : il
## est SERTI - un liseré d'or brun autour de l'or vif, un coin plus rond que
## les autres boutons, et une ombre portee qui le decolle du panneau.
func _style_fight_button() -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var tint := UiTheme.GOLD
		match state:
			"hover":
				tint = UiTheme.GOLD.lightened(0.12)
			"pressed":
				tint = UiTheme.GOLD.darkened(0.18)
			"disabled":
				tint = UiTheme.GOLD.darkened(0.45)
		var box := StyleBoxFlat.new()
		box.bg_color = tint
		box.set_corner_radius_all(12)
		box.border_color = Color("b8860b")
		box.set_border_width_all(2)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		box.shadow_color = Color(0, 0, 0, 0.35)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 4)
		_fight_button.add_theme_stylebox_override(state, box)
	_fight_button.add_theme_color_override("font_color", Color("261a00"))


## LA CHARGE DE CE COMBAT, et le seul endroit qui la lit.
##
## Elle vient de la SERIE, qui la gele a son ouverture (cf.
## CampaignRun.capacity), pas du village : ameliorer le Chateau entre deux
## combats - une serie survit a la fermeture du jeu, donc rien ne l'empeche -
## agrandissait sinon le deploiement du combat suivant, alors que la
## composition avait ete arretee sous l'ancienne charge.
func _capacity() -> int:
	return _run.charge(Game.deploy_capacity()) if _run != null \
		else Game.deploy_capacity()


## Poids total (cf. Balance.deploy_weight) des pieces deja posees - c'est ce
## qu'on compare a _capacity(), pas un nombre de pieces : voir
## CASTLE_DATA.deploy_capacity dans balance.gd.
func _placed_weight() -> int:
	var weight := 0
	for unit in _placed:
		weight += Balance.deploy_weight(unit.type)
	return weight


func _refresh_placement() -> void:
	var capacity := _capacity()
	# A droite de l'en-tete du bandeau, la maquette v2 ecrit la CHARGE, en or.
	# Elle etait deja au HUD lateral, mais le joueur a les yeux sur ses puces
	# quand il pose : c'est la qu'il faut lui dire ce qu'il lui reste de budget.
	_status_label.text = "Charge : %d/%d" % [_placed_weight(), capacity]

	_refresh_threats()

	for type in _type_buttons.keys():
		var chip: SelectionChip = _type_buttons[type]
		chip.set_count(int(_remaining[type]))
		chip.selected = (type == _selected_type)
		var folder := "bleu" if int(_remaining[type]) > 0 else "absent"
		var path := "res://assets/pieces/%s/%s.png" % [folder, type]
		if ResourceLoader.exists(path):
			chip.set_icon(load(path))

	_fight_button.disabled = _placed.is_empty()
	_update_preview()
	_refresh_stats_hud()


## HUD lateral (cf. CLAUDE.md > Stats-HUD) : effectif pose pendant le
## placement, forces en vie de chaque camp pendant le combat.
func _refresh_stats_hud() -> void:
	# free() immediat plutot que queue_free() : un enfant libere en differe
	# compte ENCORE dans la taille minimale du conteneur pendant l'image en
	# cours. Le HUD se retrouvait large de la somme de son ancien et de son
	# nouveau contenu, et debordait sur le plateau.
	for child in _stats_box.get_children():
		_stats_box.remove_child(child)
		child.free()

	if _phase == Phase.PLACEMENT:
		var label := UiTheme.make_label("CHARGE", 10, Color("b2b2cc"))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(label)
		_stats_box.add_child(_hud_separator())
		var count := UiTheme.make_label("%d/%d" % [_placed_weight(), _capacity()], 13, Color("99ccff"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(count)
	else:
		_stats_box.add_child(_hud_row(UiTheme.ENEMY, Color("ffb299"), _engine.living(BattleUnit.TEAM_ENEMY).size()))
		_stats_box.add_child(_hud_separator())
		_stats_box.add_child(_hud_row(UiTheme.ACCENT, Color("99ccff"), _engine.living(BattleUnit.TEAM_PLAYER).size()))

	UiTheme.ignore_mouse_recursive(_stats_hud)
	_keep_hud_on_screen.call_deferred()


## Le HUD se pose SOUS les deux ronds du bord droit, qui occupent la meme
## colonne : sortie, aide, puis effectifs. Calcule plutot qu'ecrit en dur -
## changer la taille des ronds ne doit pas faire reapparaitre le recouvrement
## qui masquait la moitie du HUD.
const _HUD_TOP := _CORNER_TOP + 2.0 * (_CORNER_BUTTON + _CORNER_GAP)


## Le HUD se recale a droite apres chaque changement de contenu : sa largeur
## depend de ce qu'il affiche, et la zone sure retire 16 points de chaque
## cote. Sans ce calcul sur la largeur REELLE du parent, "Charge 12/16" sort
## de l'ecran par la droite.
func _keep_hud_on_screen() -> void:
	if not is_instance_valid(_stats_hud):
		return
	_stats_hud.reset_size()
	var available: float = _stats_hud.get_parent().size.x
	_stats_hud.position = Vector2(available - _stats_hud.size.x - 8.0, _HUD_TOP)


## Trait vertical : le HUD est une LIGNE posee au-dessus du plateau, pas une
## colonne posee dessus - sur les petits plateaux de la campagne, la grille
## occupe toute la largeur et un HUD lateral finissait par cacher une piece.
func _hud_separator() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(1, 18)
	return line


func _hud_row(dot_color: Color, text_color: Color, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	var dot := Icon.new()
	dot.icon_name = "dot"
	dot.color = dot_color
	dot.custom_minimum_size = Vector2(10, 10)
	row.add_child(dot)
	var label := UiTheme.make_label(str(count), 14, text_color)
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	return row


## Le plateau ne montre plus de fleches d'intention : depuis que chaque camp
## ne joue qu'UNE piece par tour, un faisceau de fleches "si tout le monde
## bougeait en meme temps" annoncerait un combat qui n'aura pas lieu.
func _update_preview() -> void:
	_grid_view.preview_moves = []
	_grid_view.queue_redraw()


func _on_type_selected(type: String) -> void:
	if int(_remaining[type]) <= 0:
		return
	_selected_type = type
	_refresh_placement()


# ------------------------------- GESTES SUR LE PLATEAU -----------------------
#
#  Trois entrees, deux gestes : on tape une piece puis sa case d'arrivee, ou
#  on la fait glisser directement. cell_pressed sert a allumer les cases
#  possibles des que le doigt se pose, avant meme de savoir lequel des deux
#  gestes le joueur est en train de faire.

func _on_cell_pressed(cell: Vector2i) -> void:
	var unit: BattleUnit = _engine.grid.unit_at(cell)
	if unit == null or unit.team != BattleUnit.TEAM_PLAYER:
		return

	if _phase == Phase.PLACEMENT:
		# Pendant le placement, une piece posee peut aller sur n'importe quelle
		# case de la zone de deploiement : libre, ou occupee par une autre de
		# nos pieces - les deux echangent alors leur place.
		_grid_view.legal_targets = _placement_targets()
		_grid_view.selected_cell = cell
		_grid_view.queue_redraw()
	elif _phase == Phase.COMBAT:
		_select_unit(unit)


## Toute la zone de deploiement, sauf les cases occupees par l'ennemi (il n'y
## en a pas, mais rien ne l'interdit dans une bataille future).
func _placement_targets() -> Array:
	var cells: Array = []
	for y in range(_engine.grid.player_zone_first_row(), _engine.grid.rows):
		for x in range(_engine.grid.cols):
			var cell := Vector2i(x, y)
			var occupant: BattleUnit = _engine.grid.unit_at(cell)
			if occupant == null or occupant.team == BattleUnit.TEAM_PLAYER:
				cells.append(cell)
	return cells


func _on_cell_clicked(cell: Vector2i) -> void:
	match _phase:
		Phase.PLACEMENT:
			_on_placement_tap(cell)
		Phase.COMBAT:
			_on_combat_tap(cell)
		_:
			pass


func _on_piece_dropped(from: Vector2i, to: Vector2i) -> void:
	match _phase:
		Phase.PLACEMENT:
			_move_placed_unit(from, to)
		Phase.COMBAT:
			var unit: BattleUnit = _engine.grid.unit_at(from)
			if unit != null and unit.team == BattleUnit.TEAM_PLAYER:
				_try_player_move(unit, to)
		_:
			pass


# ------------------------------- PLACEMENT : GESTES --------------------------

## LE LACHER EST-IL LEGAL ? Les memes conditions que `_on_placement_tap`, mais
## rendues AVANT le geste, pour que la case refuse visiblement au lieu
## d'accepter puis de ne rien faire.
##
## ⚠️ On ne remplace pas une piece deja posee : au tap, toucher une case
## occupee la RETIRE, et un glissement qui viderait la case tout en croyant la
## remplir serait un piege. Pour deplacer, on glisse la piece elle-meme.
func _peut_poser(type: String, cell: Vector2i) -> bool:
	if _phase != Phase.PLACEMENT or type.is_empty():
		return false
	if not _engine.grid.in_bounds(cell) or not _engine.grid.is_player_zone(cell):
		return false
	if _engine.grid.unit_at(cell) != null:
		return false
	if int(_remaining.get(type, 0)) <= 0:
		return false
	return _placed_weight() + Balance.deploy_weight(type) <= _capacity()


## La piece portee depuis l'inventaire arrive sur sa case. On repasse par le
## chemin du tap plutot que d'en ecrire un second : c'est le meme placement,
## avec ses memes garde-fous, et deux chemins finiraient par diverger.
func _on_inventaire_lachee(type: String, cell: Vector2i) -> void:
	if not _peut_poser(type, cell):
		return
	_on_type_selected(type)
	_on_placement_tap(cell)


func _on_placement_tap(cell: Vector2i) -> void:
	_clear_selection()

	# Une unite deja posee : on la retire (elle retourne dans la reserve).
	var existing: BattleUnit = _engine.grid.unit_at(cell)
	if existing != null:
		if existing.team == BattleUnit.TEAM_PLAYER:
			_remaining[existing.type] = int(_remaining[existing.type]) + 1
			_placed.erase(existing)
			_engine.remove_unit(existing)
			_grid_view.queue_redraw()
			_refresh_placement()
		return

	if not _engine.grid.is_player_zone(cell):
		return
	if _selected_type.is_empty() or int(_remaining[_selected_type]) <= 0:
		return
	var capacity := _capacity()
	if _placed_weight() + Balance.deploy_weight(_selected_type) > capacity:
		_status_label.text = "Charge max : %d" % capacity
		return

	var unit := _engine.add_unit(_selected_type, _unit_level(_selected_type),
		BattleUnit.TEAM_PLAYER, cell)
	_placed.append(unit)
	_remaining[_selected_type] = int(_remaining[_selected_type]) - 1
	_grid_view.queue_redraw()
	_refresh_placement()


## Repositionnement au doigt : une piece deja posee glisse vers une autre case
## de la zone de deploiement. Si la case est occupee par une autre de nos
## pieces, les deux echangent leur place - c'est ce qu'on attend en reordonnant
## une formation, plutot qu'un geste refuse.
func _move_placed_unit(from: Vector2i, to: Vector2i) -> void:
	_clear_selection()
	var unit: BattleUnit = _engine.grid.unit_at(from)
	if unit == null or unit.team != BattleUnit.TEAM_PLAYER:
		return
	if not _engine.grid.is_player_zone(to):
		_status_label.text = "Zone bleue uniquement"
		return

	var occupant: BattleUnit = _engine.grid.unit_at(to)
	if occupant == null:
		_engine.grid.move_unit(unit, to)
	elif occupant.team == BattleUnit.TEAM_PLAYER:
		_engine.grid.remove_unit(unit)
		_engine.grid.remove_unit(occupant)
		_engine.grid.place(unit, to)
		_engine.grid.place(occupant, from)
	else:
		return

	_grid_view.queue_redraw()
	_refresh_placement()


func _on_reset_placement() -> void:
	for unit in _placed.duplicate():
		_remaining[unit.type] = int(_remaining[unit.type]) + 1
		_engine.remove_unit(unit)
	_placed.clear()
	_grid_view.queue_redraw()
	_refresh_placement()


## Repose la formation que le JOUEUR avait validee la fois precedente (cf.
## GameState.remember_formation).
##
## Ce n'est pas l'ancien bouton AUTO sous un autre nom : AUTO composait une
## armee a la place du joueur, celui-ci lui rend sa propre decision. Les pieces
## qu'il n'a plus - l'usure d'une serie - sont simplement sautees.
func _on_last_formation() -> void:
	_on_reset_placement()

	var capacity := _capacity()
	for piece in Game.playable_formation(_battle_id(), _remaining):
		var type := String(piece[0])
		var cell := Vector2i(int(piece[1]), int(piece[2]))
		if int(_remaining.get(type, 0)) <= 0:
			continue
		if not _engine.grid.is_player_zone(cell) or _engine.grid.unit_at(cell) != null:
			continue
		# La charge a pu retrecir depuis : on s'arrete a ce qui rentre encore.
		if _placed_weight() + Balance.deploy_weight(type) > capacity:
			continue
		var unit := _engine.add_unit(type, _unit_level(type), BattleUnit.TEAM_PLAYER, cell)
		_placed.append(unit)
		_remaining[type] = int(_remaining[type]) - 1

	_grid_view.queue_redraw()
	_refresh_placement()


# ------------------------------- PHASE COMBAT --------------------------------
#
#  Le joueur joue une piece, l'IA repond avec une des siennes. Tant que c'est
#  au joueur, le plateau attend : aucune horloge ne tourne, il peut reflechir
#  aussi longtemps qu'il veut.

func _start_combat() -> void:
	if _placed.is_empty():
		return

	# La formation validee est retenue pour la prochaine fois : c'est elle que
	# reposera le bouton DERNIERE FORMATION, au combat suivant de la serie ou
	# des mois plus tard.
	var formation: Array = []
	for unit in _placed:
		formation.append([unit.type, unit.cell.x, unit.cell.y])
	Game.remember_formation(_battle_id(), formation)

	_phase = Phase.COMBAT
	_running = true
	_dames_deployed = 0
	for unit in _placed:
		if unit.type == Balance.DAME:
			_dames_deployed += 1
	# Le joueur tient un des deux camps : les garde-fous anti-blocage calibres
	# sur des secondes d'animation ne s'appliquent plus (cf. BattleEngine).
	_engine.auto_mode = false
	_style_combat_badge()
	_grid_view.preview_moves = []
	_grid_view.show_zones = false
	_clear_selection()
	_build_combat_ui()
	_build_blockage_badge()
	_refresh_stats_hud()
	_show_opening_word()
	_hand_over_to_player()


## Petit badge rouge sous le Tour-Badge, cache par defaut : cf.
## _BLOCKAGE_WARNING_RATIO. Rejoue le meme habillage (fond fonce, bordure,
## ombre) que les autres badges de l'ecran de combat.
func _build_blockage_badge() -> void:
	_blockage_badge = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.DANGER, 0.16)
	box.set_corner_radius_all(10)
	box.border_color = Color(UiTheme.DANGER, 0.7)
	box.set_border_width_all(1.5)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	_blockage_badge.add_theme_stylebox_override("panel", box)
	_blockage_badge.position = Vector2(12, 97)
	_blockage_badge.visible = false

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_blockage_badge.add_child(row)

	var icon := Icon.new()
	icon.icon_name = "clock"
	icon.color = UiTheme.DANGER
	icon.custom_minimum_size = Vector2(12, 12)
	row.add_child(icon)

	_blockage_label = UiTheme.make_label("", 10, UiTheme.DANGER)
	_blockage_label.add_theme_font_override("font", UiTheme.font_bold())
	_blockage_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_blockage_label)

	_tour_badge.get_parent().add_child(_blockage_badge)


func _clear_blockage_badge() -> void:
	if _blockage_badge != null:
		_blockage_badge.queue_free()
		_blockage_badge = null
		_blockage_label = null


## L'ECRAN DE COMBAT N'A PLUS DE BANDEAU DU BAS.
##
## Il en avait un de 77 points, qui portait le statut, le bouton AUTO et les
## trois vitesses. AUTO et les vitesses sont partis avec tout ce qui jouait a
## la place du joueur ; il ne restait qu'une ligne de texte - six mots - pour
## 77 points de haut.
##
## La maquette v2 (05_Bataille_Combat) tranche : plus de bandeau, l'etat du
## tour remonte dans le badge qui dit deja le numero du tour, et toute la
## hauteur gagnee retourne AU PLATEAU. C'est le bon calcul, chiffres a l'appui :
## une case fait 45 a 72 points de cote selon la bataille, et doit rester
## touchable au pouce. Chaque point pris par l'habillage etait un point pris
## aux cases.
func _build_combat_ui() -> void:
	_clear_bottom()
	_bottom_panel.visible = false
	# Le plateau reprend la place du bandeau, jusqu'a la barre gestuelle.
	_grid_view.offset_bottom = -8.0
	_refresh_combat_status()


# ------------------------------- COMBAT : LE COUP DU JOUEUR ------------------

## Selectionne une piece et allume ses coups possibles. Pour changer d'avis,
## on tape une autre piece ou une case vide (cf. _on_combat_tap).
func _select_unit(unit: BattleUnit) -> void:
	if _busy or unit == null or unit.team != BattleUnit.TEAM_PLAYER:
		return
	if _selected_unit == unit:
		return
	_selected_unit = unit
	_grid_view.selected_cell = unit.cell
	_grid_view.legal_targets = _engine.legal_moves(unit)
	_grid_view.queue_redraw()


func _clear_selection() -> void:
	_selected_unit = null
	_grid_view.selected_cell = Vector2i(-1, -1)
	_grid_view.legal_targets = []
	_grid_view.queue_redraw()


## Tape sur le plateau pendant le combat : soit on choisit une piece, soit on
## envoie la piece deja choisie sur la case tapee.
func _on_combat_tap(cell: Vector2i) -> void:
	if _busy:
		return

	if _selected_unit != null and _grid_view.legal_targets.has(cell):
		_try_player_move(_selected_unit, cell)
		return

	# _select_unit ignore une piece deja selectionnee : taper deux fois la meme
	# piece ne l'eteint donc pas. C'est voulu - l'appui qui precede ce tap l'a
	# selectionnee il y a une fraction de seconde (cf. _on_cell_pressed), la
	# deselectionner aussitot donnerait un plateau qui ne repond pas.
	var unit: BattleUnit = _engine.grid.unit_at(cell)
	if unit != null and unit.team == BattleUnit.TEAM_PLAYER:
		_select_unit(unit)
	else:
		_clear_selection()


## Joue le coup demande par le joueur, puis laisse l'IA repondre. Un coup
## illegal ne consomme rien : le moteur retourne une liste vide et la piece
## reste selectionnee.
func _try_player_move(unit: BattleUnit, destination: Vector2i) -> void:
	if _busy or _phase != Phase.COMBAT:
		return

	var events: Array = _engine.play_move(unit, destination)
	if events.is_empty():
		_status_message("COUP IMPOSSIBLE")
		return

	_busy = true
	_clear_selection()
	_grid_view.draggable_team = -1
	await _play_events(events)
	await _resume_until_player_turn()


## Enchaine tous les coups qui ne demandent rien au joueur : la reponse de
## l'IA, et un eventuel tour passe faute de coup legal.
func _resume_until_player_turn() -> void:
	while _running and not _engine.finished:
		_refresh_combat_status()
		var player_turn: bool = _engine.current_team == BattleUnit.TEAM_PLAYER
		if player_turn and _engine.has_any_move(BattleUnit.TEAM_PLAYER):
			break

		await _wait(float(Balance.COMBAT["ai_think_delay"]))
		if not _running:
			return
		await _play_events(_engine.step())

	if not _running:
		return
	if _engine.finished:
		_show_result()
	else:
		_hand_over_to_player()


## Rend la main au joueur : ses pieces redeviennent saisissables.
func _hand_over_to_player() -> void:
	_busy = false
	_grid_view.draggable_team = BattleUnit.TEAM_PLAYER
	_refresh_combat_status()

	# Cas limite : c'est au joueur mais aucune de ses pieces ne peut bouger.
	# Le moteur passe alors son tour tout seul plutot que de figer la partie.
	if not _engine.finished and not _engine.has_any_move(BattleUnit.TEAM_PLAYER):
		_busy = true
		_grid_view.draggable_team = -1
		_status_message("AUCUN COUP POSSIBLE — TU PASSES")
		await _resume_until_player_turn()


## Message temporaire A LA PLACE de l'etat du tour, dans le badge ; le prochain
## rafraichissement de statut reprend la main.
##
## Le badge se retaille dessus, donc un message peut etre plus long que "À TOI
## DE JOUER" sans rien couper - mais il reste sur une ligne : c'est une reponse
## au geste qu'on vient de faire, pas un paragraphe d'aide. L'aide, c'est le i.
func _status_message(text: String) -> void:
	_set_badge_state(text)


func _refresh_combat_status() -> void:
	_phase_label.text = str(_engine.turn)
	_refresh_stats_hud()
	_refresh_blockage_badge()

	if _engine.finished:
		_set_badge_state("BATAILLE TERMINÉE")
	elif _engine.current_team == BattleUnit.TEAM_PLAYER and not _busy:
		_set_badge_state("À TOI DE JOUER")
	else:
		_set_badge_state("L'ENNEMI JOUE…")


## N'apparait que passe _BLOCKAGE_WARNING_RATIO du seuil d'enlisement (cf.
## BattleEngine.stalemate_ratio) : le combat doit etre visiblement bloque
## depuis un moment, pas juste en train de manoeuvrer sans prise recente.
##
## Le compte a rebours s'exprime en COUPS restants : c'est le joueur qui joue,
## et une seconde ne veut rien dire tant qu'il reflechit.
func _refresh_blockage_badge() -> void:
	if _blockage_badge == null or _engine.finished:
		return
	# POSITION MORTE : plus aucune capture n'est possible, jamais - et non un
	# simple passage a vide. Le combat ne peut plus finir que sur un nul ; le
	# joueur a le droit de le savoir plutot que de manoeuvrer pour rien.
	var dead := _engine.dead_position_moves_remaining()
	if dead >= 0:
		_blockage_badge.visible = true
		_blockage_label.text = "Aucune capture possible - %d coups" % maxi(1, dead)
		return

	if _engine.stalemate_ratio() < _BLOCKAGE_WARNING_RATIO:
		_blockage_badge.visible = false
		return
	_blockage_badge.visible = true
	_blockage_label.text = "Blocage - %d coups" % maxi(1, _engine.stalemate_moves_remaining())


## Rejoue les evenements d'un coup. Ils sont deja resolus par le moteur :
## l'animation ne decide de rien, elle montre.
func _play_events(events: Array) -> void:
	for event in events:
		if not _running:
			return
		match String(event["type"]):
			"capture":
				await _grid_view.play_capture(
					event["cell"], float(Balance.COMBAT["capture_duration"]))
			"move":
				_grid_view.last_move = {"from": event["from"], "to": event["to"]}
				await _grid_view.play_move(
					int(event["unit"]), event["from"], event["to"],
					float(Balance.COMBAT["move_duration"]))
			"end":
				_end_reason = String(event.get("reason", ""))
			"promotion":
				if _engine.unit_by_id(int(event["unit"])).team == BattleUnit.TEAM_PLAYER:
					_promotions_this_battle += 1
				await _grid_view.play_promotion(
					event["cell"], String(event["result"]),
					float(Balance.COMBAT["promotion_duration"]))
			"pass":
				_status_message("CAMP BLOQUÉ : TOUR PASSÉ")
				await _wait(float(Balance.COMBAT["step_delay"]))
			_:
				pass


## Pieces du joueur que l'ennemi peut prendre a son prochain coup. La vue les
## cercle de rouge (cf. GridView._draw_threats).
##
## Rafraichi apres chaque coup, mais AUSSI pendant le placement, et ce second
## usage vaut le premier : on voit immediatement qu'on vient de poser une tour
## sous la ligne d'un fou adverse. C'est ce qui fait du placement un vrai
## contre-placement plutot qu'une repartition a l'aveugle - l'armee ennemie est
## deja sur le plateau quand on pose la sienne.
func _refresh_threats() -> void:
	_grid_view.threat_cells = _engine.threatened_cells(BattleUnit.TEAM_PLAYER)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout


# ------------------------------- PHASE RESULTAT ------------------------------

func _show_result() -> void:
	_phase = Phase.RESULT
	_running = false
	_clear_blockage_badge()

	var victory := _engine.winner == BattleUnit.TEAM_PLAYER
	var draw := _engine.is_draw()
	var battle_id := int(_battle["id"])

	_grid_view.draggable_team = -1
	_grid_view.legal_targets = []

	# Les pertes de CE combat. Elles quittent l'effectif de la serie tout de
	# suite, mais n'atteindront l'armee du village qu'a la fin de la serie
	# (cf. GameState.finish_run) : une serie est une seule unite economique.
	var losses: Dictionary = _engine.losses(BattleUnit.TEAM_PLAYER)

	# Compteurs de carriere pour les missions (cf. Balance.MISSIONS) : une
	# seule fois par combat, victoire ou defaite.
	var pieces_lost := 0
	for count in losses.values():
		pieces_lost += int(count)
	# losses() compte par TYPE de piece : il faut sommer, pas prendre size(),
	# qui donnerait le nombre de types differents captures.
	var pieces_captured := 0
	for count in _engine.losses(BattleUnit.TEAM_ENEMY).values():
		pieces_captured += int(count)
	# Le nul passe explicitement : sans lui, un match nul compterait comme une
	# defaite (cf. GameState.record_battle).
	Game.record_battle(victory, pieces_lost, pieces_captured, _promotions_this_battle, draw)

	var total_enemies := 0
	var enemy_data: Dictionary = _battle["enemies"]
	for type in enemy_data.keys():
		total_enemies += int(enemy_data[type])
	var enemies_defeated := total_enemies - _engine.living(BattleUnit.TEAM_ENEMY).size()

	_phase_prefix.text = ""
	if draw:
		_phase_label.text = "Match nul"
	else:
		_phase_label.text = "Victoire" if victory else "Défaite"

	# NUL : personne n'a gagne. Les survivants rentrent, les morts restent
	# morts, ce combat ne rapporte rien - mais la serie n'est pas rompue.
	# C'est un tour d'usure paye pour rien, pas une deroute.
	if draw:
		_run.record_draw(losses, enemies_defeated, _promotions_this_battle,
			_engine.promoted_survivors(BattleUnit.TEAM_PLAYER),
			_engine.promoted_knights(BattleUnit.TEAM_PLAYER))
		_show_fight_drawn(losses)
		return

	if not victory:
		_run.record_defeat(losses)
		_show_run_lost()
		return

	# Or promis par ce combat. L'aura ne compte que les Dames restees au
	# village - celles qu'on a emmenees se battent, elles ne tiennent pas la
	# cour (cf. GameState.dame_gold_bonus).
	var gold := Game.reward_for(battle_id)
	var dame_bonus := Game.dame_gold_bonus(gold, _dames_deployed)
	_run.record_victory(losses, enemies_defeated, _promotions_this_battle,
		_engine.promoted_survivors(BattleUnit.TEAM_PLAYER), gold + dame_bonus,
		_engine.promoted_knights(BattleUnit.TEAM_PLAYER))

	if _run.is_last_fight():
		_show_run_won(dame_bonus)
	else:
		_show_fight_won(losses)


## Combat gagne, serie pas finie : le bilan court, les blesses releves, et le
## bouton qui enchaine. Rien n'est encaisse ici - l'or promis attend la fin.
func _show_fight_won(losses: Dictionary) -> void:
	var battle_id := _run.battle_id
	var done := _run.fight
	# On avance MAINTENANT plutot qu'au clic : la serie est sauvegardee au
	# combat suivant, donc fermer le jeu sur cet ecran ne fait pas rejouer le
	# combat qu'on vient de gagner.
	var recovered := _run.advance(Balance.RUN_REINFORCE_WEIGHT, _capacity())
	Game.save_run(_run)

	# PAS d'ecran de victoire ici. Une serie est UN engagement : la couronner
	# a chaque combat vide la victoire de son sens et impose trois clics pour
	# un seul enjeu. Un bandeau court dit ou on en est et ce qu'on a perdu,
	# puis le placement du combat suivant s'ouvre - tout seul, ou au doigt.
	var banner := SeriesBanner.new()
	add_child(banner)
	banner.show_fight(done, _run.total, losses, recovered, _run.pieces_left())
	banner.continued.connect(func(): Router.goto_battle(battle_id))


## Combat nul. Tant qu'il reste des combats, la serie continue au suivant ;
## si c'etait le dernier, elle s'acheve sans etre remportee - il ne reste que
## la consolation sur ce que les combats gagnes avaient promis, et la bataille
## suivante ne s'ouvre pas.
func _show_fight_drawn(losses: Dictionary) -> void:
	var battle_id := _run.battle_id
	var done := _run.fight
	var fights := _run.total
	# ⚠️ CE N'EST PLUS `last` QUI DECIDE, C'EST LE PLAFOND DE NULS.
	#
	# Avant, un nul au dernier combat achevait la serie : finish_run effacait
	# la partie en cours, et le bouton "REPRENDRE LA SERIE" rouvrait en fait
	# une serie NEUVE au combat 1. Le libelle promettait de reprendre, le code
	# recommencait - c'est ce que le joueur a vu.
	#
	# Un nul est un tour d'usure paye pour rien, pas un combat gagne : il
	# REJOUE le meme combat, avec les survivants et les blesses releves, et le
	# compteur de combats ne bouge pas.
	#
	# Le plafond est ce qui l'empeche de devenir un abri : au troisieme nul
	# (Balance.RUN_DRAWS_ALLOWED), la serie s'acheve sans etre remportee.
	var closing := _run.draws_spent(Balance.RUN_DRAWS_ALLOWED)

	var recovered: Dictionary = {}
	var consolation := 0
	if closing:
		var promised := _run.reward
		Game.finish_run(_run, false)
		consolation = int(round(float(promised) * Balance.DEFEAT_CONSOLATION_RATIO))
	else:
		recovered = _run.replay(Balance.RUN_REINFORCE_WEIGHT, _capacity())
		Game.save_run(_run)

	var screen := BattleResult.new()
	add_child(screen)
	# Le grand mot grave est reserve a la fin de la serie (Figma 348:2) ; un
	# combat intermediaire garde sa plaque ecrite, comme pour la victoire.
	screen.open_draw("" if closing else "COMBAT %d SUR %d — NUL" % [done, fights])

	# ⚠️ SEULEMENT POUR UN VRAI PAT, pas pour les deux autres facons de finir
	# nul. La position morte et l'enlisement ont leurs propres raisons, et le
	# texte du popup parlerait d'un camp sans coup legal alors qu'il en avait.
	if _end_reason == "plus aucun coup possible":
		GuidePopup.show_once(self, GuidePopup.STALEMATE)

	if consolation > 0:
		screen.add_reward_row("Consolation", consolation)
	elif not closing:
		screen.add_reward_row("Butin promis", _run.reward)
	screen.add_stat_row("Combat nul", _draw_reason())
	screen.add_stat_row("Pertes du combat",
		"Aucune" if losses.is_empty() else _format_losses(losses), 1)
	if not recovered.is_empty():
		screen.add_icon_row("Blessés relevés", "check",
			_format_losses(recovered), Color("5fb37a"))
	if not closing:
		screen.add_stat_row("Armée restante", "%d pièces" % _run.pieces_left(), 1)

	if closing:
		screen.add_primary_button("REJOUER LA SERIE",
			func(): Router.goto_battle(battle_id))
	else:
		screen.add_primary_button("REJOUER LE COMBAT %d SUR %d" % [done, fights],
			func(): Router.goto_battle(battle_id))
	screen.add_action_button("ROYAUME", "castle", Router.leave_battle_for_village)
	screen.add_action_button("CAMPAGNE", "compass", Router.goto_campaign)


## Dernier combat gagne : la serie paye. C'est ici, et seulement ici, que les
## pertes atteignent l'armee du village et que la bataille suivante s'ouvre.
func _show_run_won(dame_bonus: int) -> void:
	var battle_id := _run.battle_id
	var promised := _run.reward
	var enemies := _run.enemies_defeated
	var fights := _run.total
	var run_losses := _run.losses.duplicate()
	var dames_resting := Game.dames_at_rest(_dames_deployed)

	# Dame offerte par la campagne, a la premiere victoire seulement : rejouer
	# la derniere bataille ne doit pas devenir une fabrique a Dames.
	var dames_found := 0
	if not Game.is_battle_won(battle_id):
		dames_found = Game.grant_dames(Balance.battle_dame_reward(_battle))
	var dames_gained := Game.finish_run(_run, true)

	var screen := BattleResult.new()
	add_child(screen)
	screen.open(true)

	screen.add_reward_row("Récompense totale", promised)
	screen.add_stat_row("Série remportée", "%d combats sur %d" % [fights, fights])
	if dame_bonus > 0:
		screen.add_icon_row(
			"Aura de %d Dame%s" % [dames_resting, "" if dames_resting <= 1 else "s"],
			"crown", "+%d Or" % dame_bonus, Color("d8a0d0"))
	screen.add_stat_row("Ennemis vaincus", str(enemies))
	if dames_gained > 0:
		screen.add_icon_row("Dames ramenées", "crown",
			"+%d au Château Royal" % dames_gained, Color("d8a0d0"))
	if dames_found > 0:
		screen.add_icon_row("La Dame retrouvée", "crown",
			"+%d Dame" % dames_found, Color("d8a0d0"))
	screen.add_stat_row("Pertes de la série",
		"Aucune" if run_losses.is_empty() else _format_losses(run_losses), 1)

	if battle_id < Balance.battle_count():
		# La CARTE d'abord : c'est la que le cachet de la bataille suivante
		# s'ouvre, et une progression qu'on ne voit pas n'existe pas. Le
		# raccourci vers la bataille suivante reste, en second.
		screen.add_primary_button("CARTE DE CAMPAGNE", Router.goto_campaign)
		screen.add_secondary_button("BATAILLE SUIVANTE",
			func(): Router.goto_prep(battle_id + 1))
	else:
		screen.add_primary_button("REJOUER LA SÉRIE",
			func(): Router.goto_battle(battle_id))

	screen.add_action_button("ROYAUME", "castle", Router.leave_battle_for_village)
	screen.add_action_button("CAMPAGNE", "compass", Router.goto_campaign)


## Combat perdu : c'est toute la serie qui tombe, et tout l'or promis avec.
## Il ne reste que la consolation, calculee sur ce que les combats deja gagnes
## avaient promis - tomber au dernier combat rapporte donc un peu plus que
## tomber au premier.
func _show_run_lost() -> void:
	var battle_id := _run.battle_id
	var lost_at := _run.fight
	var fights := _run.total
	var promised := _run.reward
	var run_losses := _run.losses.duplicate()
	var dames_gained := Game.finish_run(_run, false)
	var consolation := int(round(float(promised) * Balance.DEFEAT_CONSOLATION_RATIO))

	var screen := BattleResult.new()
	add_child(screen)
	screen.open(false)

	if consolation > 0:
		screen.add_reward_row("Consolation", consolation)
	screen.add_stat_row("Série perdue", "Combat %d sur %d" % [lost_at, fights])
	screen.add_stat_row("Pertes subies",
		"Aucune" if run_losses.is_empty() else _format_losses(run_losses))
	if dames_gained > 0:
		screen.add_icon_row("Dames ramenées", "crown",
			"+%d au Château Royal" % dames_gained, Color("d8a0d0"))

	screen.add_primary_button("REPRENDRE LA SÉRIE",
		func(): Router.goto_battle(battle_id))
	screen.add_action_button("ROYAUME", "castle", Router.leave_battle_for_village)
	screen.add_action_button("CAMPAGNE", "compass", Router.goto_campaign)


## Pourquoi ce combat est nul. Le moteur donne une raison technique ; le joueur
## a besoin d'une phrase. Sans elle, "NUL" ressemble a un bug - et c'en etait
## un, avant : une IA figee laissait la partie s'enliser sans rien dire.
func _draw_reason() -> String:
	match _end_reason:
		"plus aucun coup possible":
			return "Un camp ne pouvait plus jouer"
		"plus aucune capture possible":
			return "Plus aucune capture possible"
		"plus aucune prise possible":
			return "Aucune prise depuis trop longtemps"
		"limite de tours atteinte":
			return "Combat trop long"
		_:
			return "Aucun camp n'a plié"


## "4 Pions, 1 Cavalier" - une seule ligne, plutot que des jetons par type,
## cf. Losses-Row des nouvelles captures Figma 06/07.
func _format_losses(losses: Dictionary) -> String:
	var details: Array = []
	for type in Balance.ARMY_TYPES:
		if losses.has(type):
			details.append(Balance.unit_count(type, int(losses[type])))
	return ", ".join(details)


# ------------------------------- DIVERS --------------------------------------

func _clear_bottom() -> void:
	for child in _bottom.get_children():
		child.queue_free()
	_type_buttons.clear()
	_status_label = null
	_fight_button = null


func _on_quit() -> void:
	_running = false
	_clear_blockage_badge()
	Router.leave_battle_for_village()
