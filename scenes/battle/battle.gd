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
## Le combat se joue coup par coup : une piece du joueur, une piece de l'IA.
## Le bouton AUTO laisse l'IA jouer les deux camps jusqu'au bout - pratique
## pour refaire de l'or sur une bataille deja gagnee. La vitesse (x1/x2/x4)
## n'agit que sur les durees d'affichage, jamais sur l'issue d'un coup.
##

enum Phase { PLACEMENT, COMBAT, RESULT }

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const SelectionChipScene := preload("res://scenes/ui/components/selection_chip.tscn")

@onready var _tour_badge: PanelContainer = $Safe/Overlay/TourBadge
@onready var _phase_prefix: Label = $Safe/Overlay/TourBadge/TourRow/PhasePrefixLabel
@onready var _phase_label: Label = $Safe/Overlay/TourBadge/TourRow/PhaseLabel
@onready var _quit_button: Button = $Safe/Overlay/QuitButton
@onready var _grid_view: Control = $Safe/Overlay/Grid
@onready var _stats_hud: PanelContainer = $Safe/Overlay/StatsHud
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
var _speed: float = 1.0
var _running: bool = false

## Piece du joueur actuellement selectionnee (tape ou saisie au doigt).
var _selected_unit: BattleUnit = null

## Vrai pendant qu'une animation ou le tour de l'IA se joue : le plateau
## n'accepte alors aucun geste, sinon un joueur rapide jouerait deux coups.
var _busy: bool = false

## Resolution automatique : l'IA joue les DEUX camps jusqu'a la fin.
var _auto: bool = false

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
var _speed_buttons: Dictionary = {}
var _fight_button: Button = null
var _auto_button: PanelContainer = null
var _auto_label: Label = null
var _turn_label: Label = null


func _ready() -> void:
	_battle = Router.current_battle()
	if _battle.is_empty():
		Router.goto_village()
		return

	_style_stats_hud()
	_quit_button.add_theme_font_size_override("font_size", 13)
	_quit_button.pressed.connect(_on_quit)
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

	for type in Balance.ARMY_TYPES:
		_remaining[type] = int(_run.roster.get(type, 0))

	_grid_view.setup(_engine)
	_grid_view.cell_clicked.connect(_on_cell_clicked)
	_grid_view.cell_pressed.connect(_on_cell_pressed)
	_grid_view.piece_dropped.connect(_on_piece_dropped)
	_grid_view.draggable_team = BattleUnit.TEAM_PLAYER

	_enter_placement()


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


## Pieces de ce type engagees dans la serie, posees ou non. `_remaining` ne
## compte que celles qui restent en main pendant le placement.
func _owned(type: String) -> int:
	if _run == null:
		return Game.units_owned(type)
	return int(_run.roster.get(type, 0))


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

const _HELP_RECT := Rect2(0, 12, 30, 30)


## Petit rond discret, cale a gauche de la croix de sortie.
func _build_help_button() -> void:
	var help := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0d0f1a", 0.75)
	box.set_corner_radius_all(15)
	box.border_color = Color(1, 1, 1, 0.18)
	box.set_border_width_all(1)
	box.set_content_margin_all(6)
	help.add_theme_stylebox_override("panel", box)
	help.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon := Icon.new()
	icon.icon_name = "info"
	icon.color = Color("ccd1e0")
	icon.custom_minimum_size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.add_child(icon)

	_quit_button.get_parent().add_child(help)

	# Ancre au bord droit, comme la croix de sortie : lire la position de
	# celle-ci ici ne marcherait pas, la mise en page n'a pas encore tourne au
	# moment du _ready() et elle vaut encore son offset negatif.
	var gap := 8.0
	var quit_width := absf(_quit_button.offset_left)
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.offset_left = -(quit_width + gap + _HELP_RECT.size.x)
	help.offset_right = -(quit_width + gap)
	help.offset_top = _HELP_RECT.position.y
	help.offset_bottom = _HELP_RECT.position.y + _HELP_RECT.size.y
	help.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_help()
	)


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


## Badge de tour (haut-gauche) : bleu "PHASE DE PLACEMENT" pendant la pose,
## or "TOUR N" pendant le combat - couleurs et tailles reprises telles quelles
## de la maquette Figma (Tour-Badge, ecrans 04 et 05), border+ombre incluses.
func _style_tour_badge(bg: Color, border: Color, radius: int, prefix_color: Color, prefix_size: int,
		main_color: Color, main_size: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = Color(0, 0, 0, 0.4)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 2)
	_tour_badge.add_theme_stylebox_override("panel", box)

	_phase_prefix.add_theme_color_override("font_color", prefix_color)
	_phase_prefix.add_theme_font_size_override("font_size", prefix_size)
	_phase_prefix.add_theme_font_override("font", UiTheme.font_bold())
	_phase_label.add_theme_color_override("font_color", main_color)
	_phase_label.add_theme_font_size_override("font_size", main_size)
	_phase_label.add_theme_font_override("font", UiTheme.font_bold())


func _style_placement_badge() -> void:
	_style_tour_badge(UiTheme.ACCENT, Color("1a66b2", 0.7), 12,
		Color.WHITE, 10, Color.WHITE, 13)
	# Le badge dit ou l'on en est dans la SERIE : c'est le seul endroit de
	# l'ecran de placement qui le rappelle, et c'est ce qui change la facon de
	# poser son armee - on ne place pas pareil au premier combat sur trois et
	# au dernier.
	if _run != null and _run.total > 1:
		_phase_prefix.text = "COMBAT %d/%d —" % [_run.fight, _run.total]
	else:
		_phase_prefix.text = "PHASE DE"
	_phase_label.text = "PLACEMENT"
	_tour_badge.custom_minimum_size = Vector2(169, 35)
	_tour_badge.size = Vector2(169, 35)


func _style_combat_badge() -> void:
	_style_tour_badge(UiTheme.GOLD, Color("d9a600", 0.7), 14,
		UiTheme.GOLD_TEXT, 13, Color("331a00"), 18)
	_phase_prefix.text = "TOUR"
	_tour_badge.custom_minimum_size = Vector2(86, 41)
	_tour_badge.size = Vector2(86, 41)


## Panneau lateral (Stats-HUD, ecrans 04 et 05) : meme habillage sombre
## translucide dans les deux phases, seul le contenu (Body) change.
func _style_stats_hud() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0d0f1a", 0.75)
	box.set_corner_radius_all(12)
	box.border_color = Color(1, 1, 1, 0.1)
	box.set_border_width_all(1)
	box.set_content_margin_all(10)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 2)
	_stats_hud.add_theme_stylebox_override("panel", box)

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

	var header_label := UiTheme.make_label("DISPONIBLES AU PLACEMENT", 11, Color("ccccd9"))
	header_label.add_theme_font_override("font", UiTheme.font_bold())
	header_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(header_label)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	_status_label = UiTheme.make_label("Tape ou glisse", 10, Color("e5bf4d"))
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
		var path := "res://assets/pieces/%s/%s.png" % [folder, type]
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		row.add_child(chip)
		chip.set_piece.call_deferred(texture, Balance.unit_name(type).to_upper(), int(_remaining[type]))
		chip.pressed.connect(_on_type_selected.bind(type))
		_type_buttons[type] = chip

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_bottom.add_child(actions)

	var auto := UiTheme.make_button("AUTO", Color(1, 1, 1, 0.08), 12)
	auto.add_theme_font_override("font", UiTheme.font_bold())
	auto.add_theme_color_override("font_color", Color("ccccd9"))
	auto.pressed.connect(_on_auto_place)
	actions.add_child(auto)

	var reset := UiTheme.make_button("RÉINITIALISER", Color(1, 1, 1, 0.08), 12)
	reset.add_theme_font_override("font", UiTheme.font_bold())
	reset.add_theme_color_override("font_color", Color("ccccd9"))
	reset.pressed.connect(_on_reset_placement)
	actions.add_child(reset)

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


## Poids total (cf. Balance.deploy_weight) des pieces deja posees - c'est ce
## qu'on compare a Game.deploy_capacity(), pas un nombre de pieces : voir
## CASTLE_DATA.deploy_capacity dans balance.gd.
func _placed_weight() -> int:
	var weight := 0
	for unit in _placed:
		weight += Balance.deploy_weight(unit.type)
	return weight


func _refresh_placement() -> void:
	var capacity := Game.deploy_capacity()
	if _placed_weight() >= capacity:
		_status_label.text = "Charge maximale atteinte"
	else:
		_status_label.text = "Tape ou glisse"

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
		var count := UiTheme.make_label("%d/%d" % [_placed_weight(), Game.deploy_capacity()], 13, Color("99ccff"))
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stats_box.add_child(count)
	else:
		_stats_box.add_child(_hud_row(UiTheme.ENEMY, Color("ffb299"), _engine.living(BattleUnit.TEAM_ENEMY).size()))
		_stats_box.add_child(_hud_separator())
		_stats_box.add_child(_hud_row(UiTheme.ACCENT, Color("99ccff"), _engine.living(BattleUnit.TEAM_PLAYER).size()))

	UiTheme.ignore_mouse_recursive(_stats_hud)
	_keep_hud_on_screen.call_deferred()


## Bande libre entre les boutons du haut (qui s'arretent a 42) et le plateau
## (qui commence a 100).
const _HUD_TOP := 54.0


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
	var capacity := Game.deploy_capacity()
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


## Formation automatique : les pions devant, les pieces lourdes derriere.
##
## Aligner tout le monde sur la meme rangee est le pire placement possible :
## les pieces se bouchent le passage et la tour ne sort jamais. Les pions
## ouvrent le contact, les pieces de valeur suivent une fois les lignes ouvertes.
func _on_auto_place() -> void:
	var capacity := Game.deploy_capacity()
	var weight := 0
	var order: Array = []
	# Types qui ne rentrent plus dans la charge restante : a exclure des tours
	# suivants sans arreter la formation pour autant, un type plus leger peut
	# encore avoir sa place (ex. il reste 2 de charge, la Tour a 5 ne rentre
	# plus mais un Pion a 1 oui).
	var exhausted: Dictionary = {}
	while true:
		var type := _pick_available_type(order, exhausted)
		if type.is_empty():
			break
		var type_weight := Balance.deploy_weight(type)
		if weight + type_weight > capacity:
			exhausted[type] = true
			continue
		order.append(type)
		weight += type_weight

	# Les pions passent devant, le reste garde son ordre d'alternance.
	order.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))

	var cells: Array = _engine.grid.free_player_cells()
	for i in range(mini(order.size(), cells.size())):
		var type: String = order[i]
		var unit := _engine.add_unit(type, _unit_level(type),
			BattleUnit.TEAM_PLAYER, cells[i])
		_placed.append(unit)
		_remaining[type] = int(_remaining[type]) - 1

	_grid_view.queue_redraw()
	_refresh_placement()


## Alterne les types disponibles plutot que de vider la caserne la plus pleine :
## un mur de pions perd contre a peu pres tout.
##
## `taken` contient les types deja retenus pour cette formation, afin de tenir
## le compte avant que les pieces soient reellement posees. `exhausted` exclut
## les types qui ne rentrent plus dans la charge restante (cf. _on_auto_place).
func _pick_available_type(taken: Array = [], exhausted: Dictionary = {}) -> String:
	var types: Array = _deployable_types()
	for offset in range(types.size()):
		var type: String = types[(taken.size() + offset) % types.size()]
		if exhausted.has(type):
			continue
		if int(_remaining[type]) - taken.count(type) > 0:
			return type
	return ""


# ------------------------------- PHASE COMBAT --------------------------------
#
#  Le joueur joue une piece, l'IA repond avec une des siennes. Tant que c'est
#  au joueur, le plateau attend : aucune horloge ne tourne, il peut reflechir
#  aussi longtemps qu'il veut. Le bouton AUTO confie les deux camps a l'IA.

func _start_combat() -> void:
	if _placed.is_empty():
		return
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
	_style_bottom_panel(Color("111319", 0.85), 0, 0)
	_place_bottom_panel(77)
	_grid_view.preview_moves = []
	_grid_view.show_zones = false
	_clear_selection()
	_build_combat_ui()
	_build_blockage_badge()
	_refresh_stats_hud()
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


func _build_combat_ui() -> void:
	_clear_bottom()

	var separator := ColorRect.new()
	separator.color = Color(0.18, 0.357, 1.0, 0.38)
	separator.custom_minimum_size = Vector2(0, 1)
	_bottom.add_child(separator)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_bottom.add_child(row)

	# A gauche : a qui de jouer. C'est la seule information dont le joueur a
	# besoin en permanence - le tour et les effectifs sont deja dans le badge
	# et le HUD lateral (cf. captures Figma 05).
	_turn_label = UiTheme.make_label("", 12, Color("e5e5f0"))
	_turn_label.add_theme_font_override("font", UiTheme.font_bold())
	_turn_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_turn_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_turn_label)

	_auto_button = _icon_button("skip", "AUTO", Color("1c2135"), Color("2a2f45"), Color("a0aabf"), 14, 11)
	_auto_label = _auto_button.find_child("Label", true, false)
	_auto_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_auto_pressed()
	)
	row.add_child(_auto_button)

	var toggle := PanelContainer.new()
	var toggle_box := StyleBoxFlat.new()
	toggle_box.bg_color = Color("161926")
	toggle_box.set_corner_radius_all(12)
	toggle_box.border_color = Color("2a2f45")
	toggle_box.set_border_width_all(1)
	toggle_box.set_content_margin_all(4)
	toggle.add_theme_stylebox_override("panel", toggle_box)
	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 3)
	toggle.add_child(toggle_row)
	row.add_child(toggle)

	_speed_buttons.clear()
	for speed in Balance.SPEEDS:
		var pill := PanelContainer.new()
		var pill_label := UiTheme.make_label("x%d" % int(speed), 12, Color("5a6480"))
		pill_label.add_theme_font_override("font", UiTheme.font_bold())
		pill_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(pill_label)
		var margin := StyleBoxFlat.new()
		margin.set_corner_radius_all(8)
		margin.content_margin_left = 10
		margin.content_margin_right = 10
		margin.content_margin_top = 7
		margin.content_margin_bottom = 7
		margin.bg_color = Color("1c2135")
		pill.add_theme_stylebox_override("panel", margin)
		pill.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_speed_selected(float(speed))
		)
		toggle_row.add_child(pill)
		_speed_buttons[speed] = pill

	_refresh_combat_status()


## Panneau clic-able icone + texte (Pause / Fin Tour, ecran 05) - un
## PanelContainer plutot qu'un Button, pour placer une Icon vectorielle a
## cote du texte sans dependre d'une police emoji (cf. icon.gd).
func _icon_button(icon_name: String, text: String, bg: Color, border: Color, fg: Color,
		icon_size: float, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(10)
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var icon := Icon.new()
	icon.icon_name = icon_name
	icon.color = fg
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	row.add_child(icon)

	var label := UiTheme.make_label(text, font_size, fg)
	label.name = "Label"
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)

	UiTheme.ignore_mouse_recursive(row)
	return panel


func _on_speed_selected(speed: float) -> void:
	_speed = speed
	_refresh_combat_status()


# ------------------------------- COMBAT : LE COUP DU JOUEUR ------------------

## Selectionne une piece et allume ses coups possibles. Pour changer d'avis,
## on tape une autre piece ou une case vide (cf. _on_combat_tap).
func _select_unit(unit: BattleUnit) -> void:
	if _busy or _auto or unit == null or unit.team != BattleUnit.TEAM_PLAYER:
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
	if _busy or _auto:
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
	if _busy or _auto or _phase != Phase.COMBAT:
		return

	var events: Array = _engine.play_move(unit, destination)
	if events.is_empty():
		_status_message("Ce coup n'est pas possible")
		return

	_busy = true
	_clear_selection()
	_grid_view.draggable_team = -1
	await _play_events(events)
	await _resume_until_player_turn()


## Enchaine tous les coups qui ne demandent rien au joueur : la reponse de
## l'IA, et un eventuel tour passe faute de coup legal. En mode AUTO, la
## boucle ne rend jamais la main et resout la bataille entiere.
func _resume_until_player_turn() -> void:
	while _running and not _engine.finished:
		_refresh_combat_status()
		var player_turn: bool = _engine.current_team == BattleUnit.TEAM_PLAYER
		if player_turn and not _auto and _engine.has_any_move(BattleUnit.TEAM_PLAYER):
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
		_status_message("Aucun coup possible - tu passes ton tour")
		await _resume_until_player_turn()


func _on_auto_pressed() -> void:
	_auto = not _auto
	if not _auto:
		_refresh_combat_status()
		return

	_clear_selection()
	if _busy or _engine.finished or _phase != Phase.COMBAT:
		_refresh_combat_status()
		return

	_busy = true
	_grid_view.draggable_team = -1
	await _resume_until_player_turn()


## Message temporaire dans le bandeau du bas ; le prochain rafraichissement
## de statut reprend la main.
func _status_message(text: String) -> void:
	if _turn_label != null:
		_turn_label.text = text


func _refresh_combat_status() -> void:
	_phase_label.text = str(_engine.turn)
	_refresh_stats_hud()
	_refresh_blockage_badge()
	_update_speed_pills(_speed)

	if _auto_label != null:
		_auto_label.text = "MANUEL" if _auto else "AUTO"

	if _turn_label == null:
		return
	if _engine.finished:
		_turn_label.text = "Bataille terminee"
	elif _auto:
		_turn_label.text = "Resolution automatique..."
	elif _engine.current_team == BattleUnit.TEAM_PLAYER and not _busy:
		_turn_label.text = "A toi de jouer"
	else:
		_turn_label.text = "L'ennemi joue..."


## N'apparait que passe _BLOCKAGE_WARNING_RATIO du seuil d'enlisement (cf.
## BattleEngine.stalemate_ratio) : le combat doit etre visiblement bloque
## depuis un moment, pas juste en train de manoeuvrer sans prise recente.
##
## En resolution automatique le compte a rebours s'exprime en secondes (le
## joueur regarde), en mode manuel en coups restants (le joueur joue, une
## seconde ne veut plus rien dire).
func _refresh_blockage_badge() -> void:
	if _blockage_badge == null or _engine.finished:
		return
	if _engine.stalemate_ratio() < _BLOCKAGE_WARNING_RATIO:
		_blockage_badge.visible = false
		return
	_blockage_badge.visible = true
	if _auto:
		var seconds := _engine.stalemate_seconds_remaining() / _speed
		_blockage_label.text = "Blocage - %ds" % maxi(1, int(ceil(seconds)))
	else:
		_blockage_label.text = "Blocage - %d coups" % maxi(1, _engine.stalemate_moves_remaining())


func _update_speed_pills(shown_speed: float) -> void:
	for speed in _speed_buttons.keys():
		var pill: PanelContainer = _speed_buttons[speed]
		var active: bool = speed == shown_speed
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(8)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		box.bg_color = Color("ffd700") if active else Color("1c2135")
		pill.add_theme_stylebox_override("panel", box)
		var label: Label = pill.get_child(0)
		label.add_theme_color_override("font_color", Color("0f111a") if active else Color("5a6480"))


## Rejoue les evenements d'un coup. Seules les DUREES dependent de la vitesse
## choisie : les evenements, eux, sont deja resolus.
func _play_events(events: Array) -> void:
	for event in events:
		if not _running:
			return
		match String(event["type"]):
			"capture":
				await _grid_view.play_capture(
					event["cell"], float(Balance.COMBAT["capture_duration"]) / _speed)
			"move":
				_grid_view.last_move = {"from": event["from"], "to": event["to"]}
				await _grid_view.play_move(
					int(event["unit"]), event["from"], event["to"],
					float(Balance.COMBAT["move_duration"]) / _speed)
			"promotion":
				if _engine.unit_by_id(int(event["unit"])).team == BattleUnit.TEAM_PLAYER:
					_promotions_this_battle += 1
				await _grid_view.play_promotion(
					event["cell"], String(event["result"]),
					float(Balance.COMBAT["promotion_duration"]) / _speed)
			"crowning":
				# Le sacre prend un tour : le pion est arrive, il n'est pas
				# encore Dame. On le signale et on marque la case - c'est
				# maintenant que les deux camps doivent la regarder.
				_refresh_crowning()
				var mine := _engine.unit_by_id(
					int(event["unit"])).team == BattleUnit.TEAM_PLAYER
				_status_message("Sacre au prochain tour — protège-la !" if mine
					else "L'ennemi va faire une Dame — empêche-le !")
				await _wait(float(Balance.COMBAT["promotion_duration"]))
			"pass":
				_status_message("Camp bloque : tour passe")
				await _wait(float(Balance.COMBAT["step_delay"]))
			_:
				pass
	_refresh_crowning()


## Cases des pions qui attendent leur couronne. La vue les entoure d'un anneau
## qui bat : une Dame annoncee est aussi une cible designee.
func _refresh_crowning() -> void:
	var cells: Array = []
	for unit in _engine.units:
		if unit.awaiting_crown and unit.is_alive():
			cells.append(unit.cell)
	_grid_view.crowning_cells = cells
	_grid_view.queue_redraw()


func _wait(seconds: float) -> void:
	var duration := maxf(0.01, seconds / _speed)
	await get_tree().create_timer(duration).timeout


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
	Game.record_battle(victory, pieces_lost, pieces_captured, _promotions_this_battle)

	var total_enemies := 0
	var enemy_data: Dictionary = _battle["enemies"]
	for type in enemy_data.keys():
		total_enemies += int(enemy_data[type])
	var enemies_defeated := total_enemies - _engine.living(BattleUnit.TEAM_ENEMY).size()

	_phase_prefix.text = ""
	if draw:
		_phase_label.text = "Match nul"
	else:
		_phase_label.text = "Victoire" if victory else "Defaite"

	# NUL : personne n'a gagne. Les survivants rentrent, les morts restent
	# morts, ce combat ne rapporte rien - mais la serie n'est pas rompue.
	# C'est un tour d'usure paye pour rien, pas une deroute.
	if draw:
		_run.record_draw(losses, enemies_defeated, _promotions_this_battle,
			_engine.promoted_survivors(BattleUnit.TEAM_PLAYER))
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
		_engine.promoted_survivors(BattleUnit.TEAM_PLAYER), gold + dame_bonus)

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
	var recovered := _run.advance(Balance.RUN_REINFORCE_WEIGHT)
	Game.save_run(_run)

	var screen := BattleResult.new()
	add_child(screen)
	screen.open(true, "COMBAT %d SUR %d" % [done, _run.total])

	screen.add_reward_row("Butin promis", _run.reward)
	screen.add_stat_row("Ennemis vaincus", str(_run.enemies_defeated))
	screen.add_stat_row("Pertes du combat",
		"Aucune" if losses.is_empty() else _format_losses(losses), 1)
	if not recovered.is_empty():
		screen.add_icon_row("Blessés relevés", "check",
			_format_losses(recovered), Color("5fb37a"))
	screen.add_stat_row("Armée restante", "%d pièces" % _run.pieces_left(), 1)

	screen.add_primary_button("COMBAT %d SUR %d" % [_run.fight, _run.total],
		func(): Router.goto_battle(battle_id))
	screen.add_action_button("ROYAUME", "castle", Router.goto_village)
	screen.add_action_button("CAMPAGNE", "compass", Router.goto_campaign)


## Combat nul. Tant qu'il reste des combats, la serie continue au suivant ;
## si c'etait le dernier, elle s'acheve sans etre remportee - il ne reste que
## la consolation sur ce que les combats gagnes avaient promis, et la bataille
## suivante ne s'ouvre pas.
func _show_fight_drawn(losses: Dictionary) -> void:
	var battle_id := _run.battle_id
	var done := _run.fight
	var fights := _run.total
	var last := _run.is_last_fight()

	var recovered: Dictionary = {}
	var consolation := 0
	if last:
		var promised := _run.reward
		Game.finish_run(_run, false)
		consolation = int(round(float(promised) * Balance.DEFEAT_CONSOLATION_RATIO))
	else:
		recovered = _run.advance(Balance.RUN_REINFORCE_WEIGHT)
		Game.save_run(_run)

	var screen := BattleResult.new()
	add_child(screen)
	screen.open_draw("SÉRIE NULLE" if last else "COMBAT %d SUR %d — NUL" % [done, fights])

	if consolation > 0:
		screen.add_reward_row("Consolation", consolation)
	elif not last:
		screen.add_reward_row("Butin promis", _run.reward)
	screen.add_stat_row("Combat nul", "Aucun camp n'a plié")
	screen.add_stat_row("Pertes du combat",
		"Aucune" if losses.is_empty() else _format_losses(losses), 1)
	if not recovered.is_empty():
		screen.add_icon_row("Blessés relevés", "check",
			_format_losses(recovered), Color("5fb37a"))
	if not last:
		screen.add_stat_row("Armée restante", "%d pièces" % _run.pieces_left(), 1)

	if last:
		screen.add_primary_button("REPRENDRE LA SÉRIE",
			func(): Router.goto_battle(battle_id))
	else:
		screen.add_primary_button("COMBAT %d SUR %d" % [_run.fight, fights],
			func(): Router.goto_battle(battle_id))
	screen.add_action_button("ROYAUME", "castle", Router.goto_village)
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
		screen.add_primary_button("BATAILLE SUIVANTE",
			func(): Router.goto_prep(battle_id + 1))
		screen.add_secondary_button("REJOUER LA SÉRIE",
			func(): Router.goto_battle(battle_id))
	else:
		screen.add_primary_button("REJOUER LA SÉRIE",
			func(): Router.goto_battle(battle_id))

	screen.add_action_button("ROYAUME", "castle", Router.goto_village)
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
	screen.add_action_button("ROYAUME", "castle", Router.goto_village)
	screen.add_action_button("CAMPAGNE", "compass", Router.goto_campaign)



## "4 Pions, 1 Cavalier" - une seule ligne, plutot que des jetons par type,
## cf. Losses-Row des nouvelles captures Figma 06/07.
func _format_losses(losses: Dictionary) -> String:
	var details: Array = []
	for type in Balance.ARMY_TYPES:
		if losses.has(type):
			details.append("%d %s" % [int(losses[type]), Balance.unit_name(type)])
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
	Router.goto_village()
