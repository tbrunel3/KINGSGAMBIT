extends Control
##
## PANNEAU DES MISSIONS - la liste des objectifs en cours, au village.
##
## Les missions repondent a la question que le village ne repondait nulle
## part : "et maintenant, je fais quoi ?". Elles se deverrouillent en chaine
## (cf. Balance.MISSIONS > requires), donc le joueur ne voit jamais qu'une
## poignee d'objectifs atteignables - pas un mur de defis dont la moitie lui
## est encore fermee.
##
## Aucune regle ici : tout vient de Balance.MISSIONS et des compteurs de
## GameState. Ajouter une mission ne demande de toucher a ce fichier.
##

const CardScene := preload("res://scenes/ui/components/card.tscn")
const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")

## Au-dela, la liste deborderait de l'ecran (la modale ne defile pas). Les
## missions suivantes apparaitront au fur et a mesure des reclamations.
const _MAX_SHOWN := 4

## LA CASCADE D'OUVERTURE, relevee sur mission-popup (410:5664).
##
## Le jaillissement du panneau lui-meme est deja pose par Modal (tache 7). Ce
## qui est propre a cet ecran, c'est la suite : croix, titre, separateur et
## liste montent l'un apres l'autre, puis les barres se remplissent.
##
## ⚠️ LA MAQUETTE FAIT MONTER CES BLOCS DE 10 px, et on ne le porte pas : ce
## sont des enfants du VBox de la modale. Opacite seulement - a 10 points, la
## translation ne se lirait de toute facon presque pas.
const OPEN_STAGGER := 0.06
const OPEN_DURATION := 0.25
## Les barres partent apres la liste et se remplissent en 0,6 s, decalees de
## 0,15 s. C'est ce qui donne a l'ecran son impression de faire le compte.
const BAR_DELAY := 0.30
const BAR_STAGGER := 0.15
const BAR_DURATION := 0.60

@onready var _modal: Modal = $Modal

## Les barres a remplir : {noeud, cible}. Rebatie a chaque reconstruction.
var _fills: Array = []
## L'ouverture ne se joue qu'une fois : cet ecran se reconstruit a chaque
## reclamation, comme la boutique.
var _opened: bool = false


func _ready() -> void:
	_modal.closed.connect(queue_free)
	Game.missions_changed.connect(_refresh)
	Game.gold_changed.connect(func(_g): _refresh())
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_modal):
		return

	_fills.clear()
	var body := _modal.body
	# free() immediat plutot que queue_free() : le panneau se reconstruit a
	# chaque reclamation, et l'ancien contenu fausserait la taille du panneau
	# le temps d'une image (meme correctif que building_popup.gd).
	for child in body.get_children():
		body.remove_child(child)
		child.free()

	# EN-TETE EN LIGNE, pas de badge centre : la maquette pose l'icone a gauche
	# du mot MISSIONS, sur une seule ligne, exactement comme les popups de
	# batiment au repos. Un grand glyphe centre au-dessus d'un titre centre
	# appartient aux ecrans de RESULTAT (victoire, defaite, chateau), pas a une
	# liste d'objectifs.
	_modal.open("", Modal.Context.GOLD)
	body.add_child(_inline_header())
	body.add_child(DividerScene.instantiate())

	var missions := Game.missions_visible()
	if missions.is_empty():
		body.add_child(_all_done())
		_open_once()
		return

	var shown := 0
	for mission in missions:
		if shown >= _MAX_SHOWN:
			break
		body.add_child(_mission_card(mission))
		shown += 1

	var remaining := missions.size() - shown
	if remaining > 0:
		var more := UiTheme.make_label(
			"%d autre%s objectif%s se devoilera%s ensuite." % [
				remaining, "" if remaining <= 1 else "s", "" if remaining <= 1 else "s",
				"" if remaining <= 1 else "ient"],
			11, UiTheme.TEXT_DIM)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(more)

	_open_once()


## ⚠️ L'OUVERTURE NE SE JOUE QU'UNE FOIS. Cet ecran se reconstruit a chaque
## reclamation - meme piege que la boutique, et il est plus vicieux ici : la
## reclamation a SA propre animation, et rejouer l'ouverture par-dessus la
## masquerait.
func _open_once() -> void:
	if _opened:
		# Les barres, elles, se reposent a leur nouvelle valeur sans animation :
		# le compte a change, il doit se voir tout de suite.
		return
	_opened = true
	_animate_open.call_deferred()


func _animate_open() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_modal):
		return

	var tween := create_tween().set_parallel(true)

	# Croix, titre, separateur, puis les cartes - dans l'ordre de lecture.
	var rank := 0
	for node in _modal.body.get_children():
		if node is Control:
			node.modulate.a = 0.0
			tween.tween_property(node, "modulate:a", 1.0, OPEN_DURATION) \
				.set_delay(float(rank) * OPEN_STAGGER)
			rank += 1

	# Puis les barres font le compte.
	for index in range(_fills.size()):
		var entry: Dictionary = _fills[index]
		var fill: Control = entry["node"]
		if not is_instance_valid(fill):
			continue
		fill.anchor_right = 0.0
		tween.tween_property(fill, "anchor_right", float(entry["target"]),
				BAR_DURATION) \
			.set_delay(BAR_DELAY + float(index) * BAR_STAGGER) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Toutes les missions du jeu ont ete reclamees.
func _all_done() -> PanelContainer:
	var card: PanelContainer = CardScene.instantiate()
	var card_body: VBoxContainer = card.get_node("%Body")
	var title := UiTheme.make_label("TOUT EST ACCOMPLI", 13, UiTheme.GOLD)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_body.add_child(title)
	var text := UiTheme.make_label(
		"Le royaume n'a plus rien a te demander. Le reste de l'or se gagne sur le champ de bataille.",
		11, Color("ccd1e0"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_body.add_child(text)
	return card


## Une mission : libelle, barre de progression, recompense, et le bouton
## RECLAMER qui s'allume quand c'est fait.
## Le glyphe qui va avec ce que la mission demande. La maquette en pose un
## devant chaque ligne, et il vaut mieux qu'une puce : d'un coup d'oeil, on
## trie ce qui se gagne au combat de ce qui se construit au village.
func _goal_icon(goal: String) -> String:
	match goal:
		"battles_won", "flawless_wins":
			return "sword"
		"units_recruited":
			return "house"
		"upgrades", "castle_level":
			return "castle"
		"captures":
			return "crown_broken"
		"promotions", "dames":
			return "crown"
		_:
			return "star"


## Titre en ligne : le glyphe, puis le mot, cales a gauche.
func _inline_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := Icon.new()
	icon.icon_name = "star"
	icon.color = UiTheme.GOLD
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var title := UiTheme.make_label("MISSIONS", 18, UiTheme.GOLD)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	return row


func _mission_card(mission: Dictionary) -> PanelContainer:
	var complete := Game.is_mission_complete(mission)
	var progress := Game.mission_progress(String(mission["goal"]))
	var target := int(mission["target"])

	var card: PanelContainer = CardScene.instantiate()
	if complete:
		# Une mission terminee se distingue au premier coup d'oeil : bordure
		# et fond dores, sinon le joueur passe a cote de sa recompense.
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTheme.GOLD, 0.09)
		box.border_color = Color(UiTheme.GOLD, 0.55)
		box.set_border_width_all(1)
		box.set_corner_radius_all(12)
		box.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", box)

	var card_body: VBoxContainer = card.get_node("%Body")

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var icon := Icon.new()
	icon.icon_name = _goal_icon(String(mission["goal"]))
	icon.color = UiTheme.GOLD if complete else Color("8fa0b8")
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon)

	var label := UiTheme.make_label(String(mission["text"]), 12,
		Color("f0f3f8") if complete else Color("ccd1e0"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 4)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin := Icon.new()
	coin.icon_name = "coin"
	coin.color = UiTheme.GOLD
	coin.custom_minimum_size = Vector2(13, 13)
	reward.add_child(coin)
	var gold_label := UiTheme.make_label("%d Or" % int(mission["gold"]), 13, UiTheme.GOLD)
	gold_label.add_theme_font_override("font", UiTheme.font_bold())
	gold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward.add_child(gold_label)
	header.add_child(reward)
	card_body.add_child(header)

	if complete:
		card_body.add_child(_claim_button(String(mission["id"])))
	else:
		card_body.add_child(_progress_row(progress, target))

	return card


func _progress_row(progress: int, target: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var track := PanelContainer.new()
	var track_box := StyleBoxFlat.new()
	track_box.bg_color = Color("1c1f2e")
	track_box.set_corner_radius_all(4)
	track.add_theme_stylebox_override("panel", track_box)
	track.custom_minimum_size = Vector2(0, 8)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var fill := ColorRect.new()
	# Vert et non bleu : la maquette (Figma mission-popup, 410:5664) peint ces
	# barres en vert, et c'est la seule difference qu'elle avait encore avec
	# cet ecran. Le bleu est l'accent du JOUEUR au combat ; ici on parle
	# d'avancement, pas de camp.
	fill.color = UiTheme.SUCCESS
	fill.anchor_bottom = 1.0
	var share := clampf(float(progress) / float(maxi(target, 1)), 0.0, 1.0)
	fill.anchor_right = share
	track.add_child(fill)
	# Retenue pour l'ouverture : la barre part de zero et se remplit. Le
	# remplissage est ce qui rend la progression LISIBLE - une barre deja
	# pleine a l'ouverture ne dit pas qu'on a avance.
	_fills.append({"node": fill, "target": share})
	row.add_child(track)

	var count := UiTheme.make_label("%d/%d" % [mini(progress, target), target], 11, Color("a0aabf"))
	count.add_theme_font_override("font", UiTheme.font_bold())
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(count)

	return row


## Panneau clic-able plutot qu'un Button : meme habillage dore que les autres
## actions du village (cf. _action_row dans building_popup.gd).
func _claim_button(id: String) -> PanelContainer:
	var button := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.GOLD
	box.border_color = Color("b8860b")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	button.add_theme_stylebox_override("panel", box)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var label := UiTheme.make_label("RÉCLAMER", 12, Color("331f00"))
	label.add_theme_font_override("font", UiTheme.font_bold())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	# call_deferred : encaisser reconstruit le panneau, donc libere ce bouton
	# alors qu'il est en train d'emettre le signal qui nous amene ici.
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Les pieces partent AVANT que le panneau ne se reconstruise : le
			# bouton est encore la, donc on sait d'ou elles decollent.
			_animate_claim(button.get_global_rect().get_center())
			Game.claim_mission.call_deferred(id))
	return button


## LA RECLAMATION - la SECONDE animation de mission-popup, et la seule qui ne
## se joue pas a l'ouverture.
##
## ⚠️ LA MAQUETTE LES MET DANS UNE SEULE TIMELINE, parce que Figma ne sait pas
## dire "au clic". Les porter ensemble ferait voler les pieces a l'ouverture,
## sans que le joueur ait rien reclame.
##
## Relevé : dix pieces eclosent a 0,04 s d'ecart en depassant a 1,4, se
## dispersent un peu, puis montent de ~288 points vers la bourse en
## retrecissant a 0,3 ; la bourse rebondit ensuite huit fois entre 1,09 et
## 1,14.
const CLAIM_COINS := 10
const CLAIM_STAGGER := 0.04
const CLAIM_BLOOM := 0.16
const CLAIM_FLIGHT := 0.55

## La bourse d'or de la barre haute du village, posee par celui qui ouvre ce
## popup. Les pieces y atterrissent.
##
## ⚠️ ELLE N'EST PAS DANS CE POPUP : elle est dans le VILLAGE. C'est ce qui
## rend cette animation particuliere - elle part d'un ecran et arrive dans un
## autre. On la RECOIT plutot que d'aller la chercher par get_parent() : un
## popup qui fouille son parent casse des qu'on l'ouvre d'ailleurs.
var purse: Control = null


func _animate_claim(from: Vector2) -> void:
	# ⚠️ SANS BOURSE, PAS DE VOL. Mieux vaut encaisser sans animation qu'envoyer
	# dix pieces vers Vector2.ZERO, c'est-a-dire le coin haut-gauche.
	if not is_instance_valid(purse):
		return

	# Les pieces traversent l'ecran : elles ne peuvent pas vivre dans la modale,
	# qui les couperait a son bord. D'ou une couche au-dessus de tout - et c'est
	# un Control NU, donc l'exception qui autorise a animer leur position.
	var flight := Control.new()
	flight.name = "CoinFlight"
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(flight)
	# Le popup se reconstruit juste apres : la couche doit lui survivre, mais
	# pas au village.
	tree_exiting.connect(func():
		if is_instance_valid(flight):
			flight.queue_free())

	var target := purse.get_global_rect().get_center()
	var tween := create_tween().set_parallel(true)

	for index in range(CLAIM_COINS):
		var coin := TextureRect.new()
		coin.texture = load("res://assets/ui/kg_coin.png")
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(18, 18)
		coin.pivot_offset = coin.size * 0.5
		coin.global_position = from - coin.size * 0.5
		coin.scale = Vector2.ZERO
		flight.add_child(coin)

		var delay := float(index) * CLAIM_STAGGER
		# Eclosion, avec le depassement a 1,4 de la maquette.
		tween.tween_property(coin, "scale", Vector2.ONE, CLAIM_BLOOM).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Une dispersion courte AVANT le vol : sans elle les dix pieces partent
		# en ligne droite au meme instant, et on n'en voit qu'une.
		var scatter := from + Vector2(randf_range(-28, 28), randf_range(-14, 22))
		tween.tween_property(coin, "global_position", scatter - coin.size * 0.5,
				CLAIM_BLOOM).set_delay(delay)
		tween.tween_property(coin, "global_position", target - coin.size * 0.5,
				CLAIM_FLIGHT).set_delay(delay + CLAIM_BLOOM) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(coin, "scale", Vector2(0.3, 0.3), CLAIM_FLIGHT) \
			.set_delay(delay + CLAIM_BLOOM)
		tween.tween_property(coin, "modulate:a", 0.0, 0.12) \
			.set_delay(delay + CLAIM_BLOOM + CLAIM_FLIGHT - 0.12)

	# La bourse rebondit a l'arrivee des premieres pieces.
	purse.pivot_offset = purse.size * 0.5
	var bounce := create_tween()
	bounce.tween_interval(CLAIM_BLOOM + CLAIM_FLIGHT * 0.75)
	for i in range(4):
		bounce.tween_property(purse, "scale", Vector2(1.12, 1.12), 0.07)
		bounce.tween_property(purse, "scale", Vector2.ONE, 0.07)

	tween.finished.connect(func():
		if is_instance_valid(flight):
			flight.queue_free())
