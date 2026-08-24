extends Control
##
## PREPARATION DE BATAILLE - l'ecran ou le joueur COMPOSE son armee.
##
## Il ne se contentait que d'annoncer : armee ennemie, ton armee, l'enjeu. Il
## lui manquait le GESTE, et c'est ce qui donnait au joueur l'impression que
## recruter ne changeait rien - au chateau Nv.1 on pose 16 de charge, et un
## dixieme pion n'entrait sur aucun plateau.
##
## La distinction que le jeu ne montrait nulle part est desormais un ecran :
##
##   RECRUTER remplit la CASERNE (panneau du bas). C'est une reserve, elle
##   n'a pas de plafond.
##   COMPOSER remplit le DEPLOIEMENT (panneau du milieu). C'est l'armee qui
##   part, et elle est bornee par la charge du chateau.
##
## La charge se depense ICI, une seule fois. Le placement ne fait plus que
## poser ce qui a deja ete choisi (cf. CampaignRun.lineup et battle.gd) : deux
## plafonds qui se ressemblent, et le joueur ne saurait plus lequel le bloque.
##
## Repris de la maquette Figma preparation-bataille-v2 (node-id 169:4), refaite
## par le joueur : parchemin clair, panneaux blancs cercles de bleu, ennemi en
## haut, deploiement au milieu, caserne en bas. C'est le SEUL ecran clair du
## jeu - le choix a ete pose en connaissance de la rupture avec la carte de
## campagne et le placement, qui restent en nuit et or.
##
## Deux libelles de la maquette ne sont PAS repris tels quels, parce qu'ils
## decrivent un autre jeu que celui du code (cf. CLAUDE.md, regle 2) :
##   - "Points: 0/15" compte des points ; le jeu compte une CHARGE (Pion 1,
##     Cavalier 3, Fou 3, Tour 5, Dame 5) contre la capacite du chateau.
##   - "Plateau 8x11 cases" est fixe ; la taille du terrain vient de la
##     bataille jouee, et va de 5x6 a 8x9.
##

# ------------------------------- PALETTE -------------------------------------
#
#  Relevee sur la maquette 169:4. Aucune de ces couleurs n'est celle du reste
#  du jeu : cet ecran ne partage pas la plaque royale, il a sa propre peau.

const CornerButton := preload("res://scenes/ui/components/corner_button.gd")
const PAGE_BG := Color("f6f1e8")
const PAGE_BG_DEEP := Color("efe7d9")
const PANEL_BG := Color("ffffff")
const PANEL_EDGE := Color("bfd7e8")
const TILE_BG := Color("f2f7fb")
const TILE_EDGE := Color("7fa6c2")
const ACCENT_BG := Color("eaf2fb")
const BEVEL_BG := Color("ddebff")
const INK := Color("2b1a0a")
const INK_SOFT := Color("334e68")
const CTA_BG := Color("f5d87a")
const DAME_INK := Color("8a4b7d")

const COIN_TEXTURE := preload("res://assets/ui/kg_coin.png")
## Chargee a la demande et non en preload : elle ne sert qu'a la derniere
## bataille, et 160 Ko n'ont rien a faire en memoire les neuf autres fois.
const CAPTIVE_TEXTURE := "res://assets/story/dame_captive.png"

## Cote d'une case de deploiement, et nombre de cases par rangee. A 40 points
## et 6 de separation, sept cases tiennent dans les 361 points utiles - on en
## met six, comme la maquette, et la septieme place sert de marge.
const SLOT_SIZE := 40.0
const SLOTS_PER_ROW := 6

@onready var _background: TextureRect = $Background
@onready var _header: HBoxContainer = $Safe/Root/HeaderMargin/Header
@onready var _body: VBoxContainer = $Safe/Root/Scroll/Body
@onready var _cta_row: HBoxContainer = $Safe/Root/CtaRow

var _battle: Dictionary = {}
var _run: CampaignRun

## Composition en cours d'edition : {type: nombre}. Elle n'est versee dans la
## serie qu'au moment de lancer le combat - reculer ne l'engage a rien.
var _chosen: Dictionary = {}

## Faux des le deuxieme combat d'une serie. La composition SURVIT a la serie
## et se reduit des pertes : on ne la refait pas entre deux combats, sinon on
## remet un ecran de decision la ou le bandeau de serie vient d'en enlever un.
var _composing: bool = true

var _slot_flow: HFlowContainer

## Les deux ZONES DE LACHER du glisser-deposer : le deploiement et la caserne.
## Elles entourent les rangees plutot que de se confondre avec elles, pour
## qu'un lacher tombe juste meme entre deux cases.
var _zone_deploiement: Poignee
var _zone_caserne: Poignee

var _charge_label: Label
var _hint_label: Label
var _barracks_row: HBoxContainer
var _barracks_total: Label
var _actions_row: HBoxContainer
var _cta: PanelContainer
var _cta_label: Label

## Panneaux de l'ecran, par nom : c'est ce que l'animation d'entree fait
## arriver l'un apres l'autre (cf. _animate_entry).
var _sections: Dictionary = {}


func _ready() -> void:
	_battle = Router.current_battle()
	_build_background()
	_build_header()
	if _battle.is_empty():
		_body.add_child(UiTheme.make_label("Bataille introuvable", 16, UiTheme.DANGER))
		return
	_prepare_run()
	_build_stake_band()
	_build_enemy_panel()
	_build_deployment_panel()
	_build_barracks_panel()
	_build_info_panel()
	_build_cta()
	_refresh()
	_animate_entry.call_deferred()
	# La distinction reserve / armee, une seule fois, a la premiere ouverture
	# de l'ecran qui l'introduit. Pas au deuxieme combat d'une serie : l'ecran
	# y est en lecture seule, il n'y a plus rien a composer.
	if _composing:
		GuidePopup.show_once.call_deferred(self, GuidePopup.LINEUP)


## Recupere la serie en cours, ou en monte une PROVISOIRE.
##
## Provisoire, et non ouverte pour de bon : `Game.begin_run` ecrase la serie en
## cours des qu'elle porte sur une autre bataille. Venir REGARDER la bataille 5
## effacerait alors une serie entamee sur la 3. La serie n'est versee qu'au
## moment de lancer le combat (cf. _on_launch).
func _prepare_run() -> void:
	var id := int(_battle["id"])
	_run = Game.current_run(id)
	if _run == null:
		var army: Dictionary = {}
		for type in Balance.ARMY_TYPES:
			army[type] = Game.units_owned(type)
		_run = CampaignRun.start(id, Balance.battle_fights(_battle), army)
		# La derniere composition validee ici est reproposee, ramenee a ce que
		# le joueur possede encore et a la charge d'aujourd'hui. Ce n'est pas
		# une armee composee par l'ordinateur (regle 3) : c'est SA decision
		# precedente, qu'on lui evite de reprendre piece par piece.
		_run.set_lineup(Game.remembered_lineup(id), _capacity())
	_composing = _run.fight <= 1
	_chosen = _run.lineup.duplicate()


## Fond de la maquette : un parchemin clair, a peine plus chaud sur les bords.
func _build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, PAGE_BG)
	gradient.set_color(1, PAGE_BG_DEEP)

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.4)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	_background.texture = texture


# ------------------------------- EN-TETE -------------------------------------

## ⚠️ CE RETOUR NE PASSE PAS AU COMPOSANT PARTAGE, et c'est delibere.
##
## Il est bien a 52 points comme les trois autres - la taille, elle, est
## commune - mais sa PEAU est celle d'un ecran CLAIR : coquille blanche, filet
## bleu pale, biseau creuse. La preparation est le seul ecran clair du jeu
## (maquette 410:7227), quand la carte qui la precede et le placement qui la
## suit restent en nuit et or.
##
## Lui poser la plaque royale doree du composant repeindrait un ecran que la
## maquette veut clair - ce serait faire primer une regle de code sur une
## decision de design, exactement l'inverse de la regle 2.
func _build_header() -> void:
	var back := _shell(PANEL_BG, TILE_EDGE, 1.5, 16.0, 4)
	back.custom_minimum_size = Vector2(CornerButton.BACK_SIZE, CornerButton.BACK_SIZE)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.gui_input.connect(func(event: InputEvent):
		if _is_tap(event):
			Router.goto_campaign())
	_header.add_child(back)

	# Le "inner-bevel" de la maquette : un carre bleu pale dans le blanc, qui
	# creuse le bouton au lieu de le poser a plat.
	var bevel := _shell(BEVEL_BG, TILE_EDGE, 1.0, 12.0, 0)
	bevel.custom_minimum_size = Vector2(40, 40)
	bevel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bevel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_child(bevel)

	var arrow := Icon.new()
	arrow.icon_name = "arrow_left"
	arrow.color = INK
	arrow.custom_minimum_size = Vector2(14, 14)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bevel.add_child(arrow)

	if _battle.is_empty():
		return

	var plate := _shell(ACCENT_BG, TILE_EDGE, 1.0, 16.0, 6)
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(plate)

	var inner := _shell(PANEL_BG, TILE_EDGE, 1.0, 12.0, 8)
	plate.add_child(inner)

	var name := String(_battle["name"]).to_upper()
	var title := _ink_label("BATAILLE %d — %s" % [int(_battle["id"]), name], 16, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	# "BATAILLE 10 — LA TOUR DE LA DAME" fait 32 signes : on reduit le corps
	# plutot que de laisser le nom se faire couper.
	if title.text.length() > 28:
		title.add_theme_font_size_override("font_size", 13)
	elif title.text.length() > 22:
		title.add_theme_font_size_override("font_size", 14)
	inner.add_child(title)


# ------------------------------- L'ENJEU -------------------------------------

## Bandeau d'enjeu de la DERNIERE bataille (Figma preparation-bataille-10-v3).
##
## La Dame captive est l'image centrale de l'histoire du jeu - le Roi a perdu
## sa Dame, toute la campagne consiste a la retrouver. La condition est `dame`
## dans Balance.CAMPAIGN, que seule la dixieme bataille declare : les neuf
## autres n'ont pas ce bandeau.
func _build_stake_band() -> void:
	var dames := Balance.battle_dame_reward(_battle)
	if dames <= 0:
		return
	if not ResourceLoader.exists(CAPTIVE_TEXTURE):
		return

	var column := _panel("stake")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = load(CAPTIVE_TEXTURE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(52, 76)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text)

	var title := _ink_label("ELLE EST LÀ-HAUT", 15, INK, true)
	title.add_theme_font_override("font", UiTheme.font_black())
	text.add_child(title)

	# Le nombre de combats et le nombre de Dames viennent de la bataille, pas
	# d'une phrase ecrite en dur : a `fights: 1`, le bandeau dit "ce combat".
	var fights := Balance.battle_fights(_battle)
	var what := "les %d combats" % fights if fights > 1 else "ce combat"
	var prize := "une Dame" if dames <= 1 else "%d Dames" % dames
	var body := _ink_label(
		"Remporte %s et %s rejoint le %s — le trône vide du premier écran du jeu."
			% [what, prize, Balance.building_name(Balance.DAME)], 12, INK_SOFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(body)


# ------------------------------- ARMEE ENNEMIE -------------------------------

func _build_enemy_panel() -> void:
	var column := _panel("enemy")

	var banner := _pill("ARMÉE ENNEMIE", 13)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(banner)
	_sections["enemy_banner"] = banner

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	var enemies: Dictionary = _battle["enemies"]
	var level := int(_battle["level"])
	# Le corps du nom suit le NOMBRE de cartes : la derniere bataille aligne
	# les quatre types, et "Cavalier x1" y arrivait tronque en "avalier >".
	# Mieux vaut deux points de moins que le nom coupe.
	var kinds := 0
	for type in Balance.UNIT_TYPES:
		if enemies.has(type):
			kinds += 1
	var crowded := kinds >= 4

	for type in Balance.UNIT_TYPES:
		if not enemies.has(type):
			continue
		var count := int(enemies[type])
		if crowded:
			row.add_child(_piece_card(type, "rouge", Balance.unit_name(type),
				"×%d · Nv.%d" % [count, level], 11, 48, 56))
		else:
			row.add_child(_piece_card(type, "rouge",
				"%s ×%d" % [Balance.unit_name(type), count],
				"Nv.%d" % level, 13, 48, 56))


# ------------------------------- DEPLOIEMENT ---------------------------------
#
#  Le panneau du milieu : les cases de l'armee qui part. Une case par piece
#  choisie, plus des cases vides en pointille pour dire qu'il en reste de la
#  place. C'est ici, et nulle part ailleurs, que la charge se depense.

func _build_deployment_panel() -> void:
	var column := _panel("deployment")

	var header := HBoxContainer.new()
	column.add_child(header)

	var title := _ink_label("DÉPLOIEMENT", 13, INK, true)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var charge_pill := _pad(_shell(ACCENT_BG, TILE_EDGE, 1.0, 10.0, 0), 10, 4)
	charge_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(charge_pill)

	_charge_label = _ink_label("", 11, INK, true)
	_charge_label.add_theme_font_override("font", UiTheme.font_black())
	_charge_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	charge_pill.add_child(_charge_label)

	# La zone de lacher ENTOURE les cases au lieu d'etre les cases : lacher
	# entre deux cases, ou sous la derniere rangee, doit engager quand meme.
	_zone_deploiement = _zone(
		func(charge: Dictionary) -> bool:
			return _composing and charge.get("ou", "") == "caserne" \
				and _peut_engager(_type_de(charge)),
		func(charge: Dictionary) -> void: _add(_type_de(charge)))
	column.add_child(_zone_deploiement)

	_slot_flow = HFlowContainer.new()
	_slot_flow.add_theme_constant_override("h_separation", 6)
	_slot_flow.add_theme_constant_override("v_separation", 6)
	_slot_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_zone_deploiement.add_child(_slot_flow)

	_hint_label = _ink_label("", 11, INK_SOFT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint_label)

	_actions_row = HBoxContainer.new()
	_actions_row.add_theme_constant_override("separation", 8)
	_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_actions_row)


## Les deux boutons de service du deploiement. Absents de la maquette, mais le
## gameplay en a besoin : sans VIDER, une composition ratee ne se defait qu'en
## retirant les pieces une par une.
func _rebuild_actions() -> void:
	for child in _actions_row.get_children():
		_actions_row.remove_child(child)
		child.free()

	if not _composing:
		return

	if Game.has_remembered_lineup(int(_battle["id"])):
		var last := _light_button("DERNIÈRE COMPOSITION")
		last.pressed.connect(_on_last_lineup)
		_actions_row.add_child(last)

	if _chosen_weight() > 0:
		var clear := _light_button("VIDER")
		clear.pressed.connect(func():
			_chosen.clear()
			_hint_label.text = ""
			_queue_refresh())
		_actions_row.add_child(clear)


func _rebuild_slots() -> void:
	for child in _slot_flow.get_children():
		_slot_flow.remove_child(child)
		child.free()

	var filled := 0
	for type in Balance.ARMY_TYPES:
		for i in range(int(_chosen.get(type, 0))):
			_slot_flow.add_child(_filled_slot(type))
			filled += 1

	if not _composing:
		return

	# Des cases vides tant qu'il reste de la charge a depenser : elles disent
	# "il te reste de la place" mieux qu'un compteur. Une fois la charge
	# pleine, elles disparaissent - une case qu'on ne peut plus remplir est un
	# mensonge.
	if not _can_add_anything():
		return
	var target := maxi(SLOTS_PER_ROW, filled + 1)
	if target % SLOTS_PER_ROW != 0:
		target += SLOTS_PER_ROW - (target % SLOTS_PER_ROW)
	for i in range(target - filled):
		_slot_flow.add_child(_empty_slot())


## Case occupee : la piece choisie. On la touche pour la renvoyer a la caserne.
func _filled_slot(type: String) -> PanelContainer:
	var slot := _shell(TILE_BG, TILE_EDGE, 1.5, 10.0, 3, true)
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	if _composing:
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.tooltip_text = "Glisse-le vers la caserne, ou touche-le, pour le renvoyer"
		slot.gui_input.connect(func(event: InputEvent):
			if _is_tap(event):
				_remove(type))
		_saisir(slot, "deploiement", type)

	var sprite := TextureRect.new()
	sprite.texture = UiTheme.piece_texture("bleu", type)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(sprite)
	return slot


func _empty_slot() -> Control:
	var slot := DashedSlot.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.gui_input.connect(func(event: InputEvent):
		if _is_tap(event):
			_hint_label.text = "Touche une pièce de la caserne pour l'engager."
	)
	return slot


# ------------------------------- CASERNE -------------------------------------
#
#  Le panneau du bas : ce que le joueur POSSEDE. Recruter le remplit, et il n'a
#  pas de plafond - c'est le deploiement au-dessus qui en a un.

func _build_barracks_panel() -> void:
	var column := _panel("barracks")

	var header := HBoxContainer.new()
	column.add_child(header)

	var title := _ink_label("CASERNE", 13, INK, true)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_barracks_total = _ink_label("", 12, INK_SOFT, true)
	_barracks_total.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(_barracks_total)

	# Meme raison qu'au deploiement : c'est la zone qui recoit, pas les cartes.
	# Y lacher une piece engagee, c'est la renvoyer en reserve.
	_zone_caserne = _zone(
		func(charge: Dictionary) -> bool:
			return _composing and charge.get("ou", "") == "deploiement" \
				and int(_chosen.get(_type_de(charge), 0)) > 0,
		func(charge: Dictionary) -> void: _remove(_type_de(charge)))
	column.add_child(_zone_caserne)

	_barracks_row = HBoxContainer.new()
	_barracks_row.add_theme_constant_override("separation", 8)
	_zone_caserne.add_child(_barracks_row)


func _rebuild_barracks() -> void:
	for child in _barracks_row.get_children():
		_barracks_row.remove_child(child)
		child.free()

	var in_reserve := 0
	for type in Balance.ARMY_TYPES:
		var owned := int(_run.roster.get(type, 0))
		var left := _run_reserve(type)
		in_reserve += left
		# La Dame ne figure sur le briefing que si le Roi en a retrouve une :
		# elle ne se recrute pas, une case vide n'apprendrait rien.
		if type == Balance.DAME and owned <= 0:
			continue

		# Son niveau est celui que la bataille lui donnera vraiment (cf.
		# GameState.dame_level), pas celui de la caserne des pions.
		var level := Game.dame_level() if type == Balance.DAME else Game.building_level(type)
		# Un batiment pas encore apparu au village n'a pas de niveau : la carte
		# n'ecrit alors rien plutot qu'un "Nv.0" faux.
		var level_text := "Nv.%d" % level if level > 0 else ""
		var engaged := int(_chosen.get(type, 0)) > 0

		# Le nombre descend sur la ligne du niveau, jamais a cote du nom : a
		# quatre cartes, chacune fait 78 points et "Cavalier x0" y arrivait
		# tronque en "Cavalier xC". C'est le NOM qu'il ne faut pas couper - le
		# panneau ennemi paie deja exactement la meme lecon.
		var subtitle := "×%d" % left
		if not level_text.is_empty():
			subtitle += " · " + level_text
		var card := _piece_card(type, "bleu" if left > 0 or engaged else "absent",
			Balance.unit_name(type), subtitle, 12, 36, 44, _composing)
		# La pastille descend dans la colonne de la carte, pas a cote d'elle :
		# c'est le premier enfant du PanelContainer qui porte la mise en page.
		card.get_child(0).add_child(
			_status_pill("AU COMBAT" if engaged else "RÉSERVE", engaged))

		if _composing:
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.tooltip_text = "Glisse-le vers le déploiement, ou touche-le : %s, charge %d" % [
				Balance.unit_name(type), Balance.deploy_weight(type)]
			card.gui_input.connect(func(event: InputEvent):
				if _is_tap(event):
					_add(type))
			# On ne saisit que ce qui reste en reserve : glisser une carte vide
			# ferait miroiter un engagement que `_add` refuserait au lacher.
			if left > 0:
				_saisir(card, "caserne", type)
		if left <= 0 and not engaged:
			card.modulate.a = 0.6

		_barracks_row.add_child(card)

	_barracks_total.text = "Total : %d" % in_reserve


# ------------------------------- L'ENJEU CHIFFRE -----------------------------

func _build_info_panel() -> void:
	var column := _panel("info")

	var reward := Game.reward_for(int(_battle["id"]))
	var fights := Balance.battle_fights(_battle)

	# La serie d'abord : c'est elle l'engagement que le joueur prend en
	# appuyant sur le bouton. L'or annonce est celui de la serie ENTIERE - il
	# n'est verse qu'au dernier combat gagne, et un seul combat perdu le fait
	# tomber (cf. CampaignRun).
	# Une bataille qui se joue en un seul combat n'a pas de serie a annoncer :
	# la ligne disparait plutot que d'ecrire "serie : un seul combat".
	if fights > 1:
		var fights_label := _ink_label("%d combats d'affilée" % fights, 14, INK, true)
		fights_label.add_theme_font_override("font", UiTheme.font_black())
		column.add_child(_info_row(
			"Série en cours (%d/%d)" % [_run.fight, fights] if _run.fight > 1 else "Série",
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
	var gold_label := _ink_label(
		"%s Or" % UiTheme.format_thousands(reward * fights), 15, INK, true)
	gold_label.add_theme_font_override("font", UiTheme.font_black())
	gold_value.add_child(gold_label)
	column.add_child(_info_row(
		"Récompense de la série" if fights > 1 else "Récompense totale", gold_value))

	# Ce que rapporteraient les Dames si elles restaient toutes au village :
	# c'est ici, avant le placement, que le choix se prepare.
	var dame_bonus := Game.dame_gold_bonus(reward)
	if dame_bonus > 0:
		var dames := Game.dames_owned()
		var bonus := _ink_label("+%d Or" % dame_bonus, 14, DAME_INK, true)
		column.add_child(_info_row(
			"Aura de %d Dame%s au repos" % [dames, "" if dames <= 1 else "s"], bonus))

	var line := ColorRect.new()
	line.color = PANEL_EDGE
	line.custom_minimum_size = Vector2(0, 1)
	column.add_child(line)

	var terrain := _ink_label(
		"Plateau %d×%d cases" % [int(_battle["cols"]), int(_battle["rows"])], 14, INK, true)
	terrain.add_theme_font_override("font", UiTheme.font_black())
	column.add_child(_info_row("Terrain de bataille", terrain))

	if Game.is_battle_won(int(_battle["id"])):
		column.add_child(_ink_label(
			"(bataille déjà gagnée — récompense réduite)", 12, INK_SOFT))


func _info_row(label_text: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := _ink_label(label_text, 14, INK_SOFT)
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

func _build_cta() -> void:
	_cta = _pad(_shell(CTA_BG, TILE_EDGE, 1.0, 12.0, 0), 24, 20)
	_cta.custom_minimum_size = Vector2(280, 0)
	_cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cta.mouse_filter = Control.MOUSE_FILTER_STOP
	_cta.gui_input.connect(func(event: InputEvent):
		if _is_tap(event):
			_on_launch())
	_cta_row.add_child(_cta)

	_cta_label = _ink_label("LANCER LE COMBAT", 20, INK, true)
	_cta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cta.add_child(_cta_label)


## Verse la composition dans la serie et part au placement.
##
## C'est ICI que la serie s'ouvre pour de bon (cf. _prepare_run) : jusqu'a ce
## clic, l'ecran n'a rien engage.
func _on_launch() -> void:
	if not _commit_lineup():
		return
	Router.goto_battle(int(_battle["id"]))


## Verse la composition dans la serie, et dit si c'etait possible.
##
## Separee du depart pour que le banc d'interface puisse la verifier sans
## declencher un changement de scene - qui, lance depuis un banc, emporte le
## banc lui-meme.
func _commit_lineup() -> bool:
	if _chosen_weight() <= 0:
		_hint_label.text = "Engage au moins une pièce avant de partir."
		return false
	var id := int(_battle["id"])
	_run.set_lineup(_chosen, _capacity())
	# Memorisee seulement quand c'est bien une DECISION du joueur : au
	# deuxieme combat d'une serie, la composition est le fruit des pertes, pas
	# un choix - la retenir ecraserait celui qu'il avait pris au premier.
	if _composing:
		Game.remember_lineup(id, _run.lineup)
	Game.save_run(_run)
	return true


# ------------------------------- COMPOSITION ---------------------------------

func _capacity() -> int:
	return Game.deploy_capacity()


func _chosen_weight() -> int:
	var weight := 0
	for type in _chosen.keys():
		weight += int(_chosen[type]) * Balance.deploy_weight(type)
	return weight


## Pieces de ce type restees a la caserne : possedees dans la serie, mais pas
## engagees. `_chosen` est l'edition en cours, pas encore versee dans le run.
func _run_reserve(type: String) -> int:
	return maxi(0, int(_run.roster.get(type, 0)) - int(_chosen.get(type, 0)))


## Reste-t-il une piece que la charge laisse encore entrer ? Sert a decider si
## on montre des cases vides.
func _can_add_anything() -> bool:
	var left := _capacity() - _chosen_weight()
	for type in Balance.ARMY_TYPES:
		if _run_reserve(type) > 0 and Balance.deploy_weight(type) <= left:
			return true
	return false


## Rendre une coque SAISISSABLE : ce qu'elle donne, et ce qu'on verra sous
## le doigt. Deux lignes recopiees a deux endroits ; une de plus et le
## troisieme aurait oublie l'apercu.
func _saisir(panel: PanelContainer, ou: String, type: String) -> void:
	var poignee := panel as Poignee
	if poignee == null:
		return
	poignee.charge = {"ou": ou, "type": type}


## La ZONE DE LACHER d'un panneau : une coque transparente qui entoure une
## rangee et repond a sa place. Les deux panneaux la fabriquaient a
## l'identique, a la provenance pres.
func _zone(accepte: Callable, recoit: Callable) -> Poignee:
	var zone := Poignee.new()
	zone.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	zone.accepte = accepte
	zone.recoit = recoit
	return zone


## Le type porte par une charge de glissement, quelle que soit sa provenance.
func _type_de(charge: Dictionary) -> String:
	return String(charge.get("type", ""))


## Ce qu'une carte de caserne peut promettre au moment ou on la saisit : les
## MEMES deux conditions que `_add`, mais sans le message d'erreur. La zone de
## lacher refuse alors visiblement au lieu d'accepter puis de ne rien faire.
func _peut_engager(type: String) -> bool:
	if type.is_empty() or _run_reserve(type) <= 0:
		return false
	return _chosen_weight() + Balance.deploy_weight(type) <= _capacity()


## ⚠️ UNE SEULE ECRITURE DE LA REGLE. `_add` re-verifiait mot pour mot ce que
## `_peut_engager` venait de dire, et le commentaire l'assumait ("les MEMES
## deux conditions"). Deux copies d'une regle de charge, c'est deux endroits a
## corriger et un a oublier - et l'oubli produit exactement le defaut que le
## refus avant lacher voulait supprimer : une zone qui accepte puis ne fait rien.
func _add(type: String) -> void:
	if not _composing:
		return
	if not _peut_engager(type):
		_hint_label.text = _pourquoi_pas(type)
		return
	_chosen[type] = int(_chosen.get(type, 0)) + 1
	_hint_label.text = ""
	_queue_refresh()


## Le refus se DIT. La regle est dans `_peut_engager` ; ici on explique.
func _pourquoi_pas(type: String) -> String:
	if _run_reserve(type) <= 0:
		return "Plus de %s en caserne — recrute au village." % Balance.unit_name(type)
	# Le message nomme la piece ET son poids : "charge maximale" tout seul
	# n'apprend pas pourquoi la Tour ne passe pas alors qu'un Pion passe.
	return "Charge pleine : un %s coûte %d, il reste %d." % [
		Balance.unit_name(type), Balance.deploy_weight(type),
		_capacity() - _chosen_weight()]


func _remove(type: String) -> void:
	if not _composing or int(_chosen.get(type, 0)) <= 0:
		return
	_chosen[type] = int(_chosen[type]) - 1
	_hint_label.text = ""
	_queue_refresh()


## Repose la composition que le JOUEUR avait validee la fois precedente. Meme
## doctrine que DERNIERE FORMATION au placement : on lui rend sa decision, on
## n'en prend pas une a sa place.
func _on_last_lineup() -> void:
	var probe := CampaignRun.new()
	probe.roster = _run.roster.duplicate()
	probe.set_lineup(Game.remembered_lineup(int(_battle["id"])), _capacity())
	_chosen = probe.lineup
	_hint_label.text = ""
	_queue_refresh()


## Reconstruction DIFFEREE d'une image.
##
## Le geste qui la declenche vient d'une carte ou d'un bouton que la
## reconstruction va justement liberer, et Godot refuse de liberer un objet en
## train d'emettre son signal ("Attempted to free a locked object"). Appelee a
## chaud, la carte survivait : la composition restait bloquee sur sa premiere
## piece, sans qu'aucune erreur ne remonte a l'ecran.
func _queue_refresh() -> void:
	_refresh.call_deferred()


func _refresh() -> void:
	_charge_label.text = "Charge : %d/%d" % [_chosen_weight(), _capacity()]
	_rebuild_slots()
	_rebuild_barracks()
	_rebuild_actions()

	var ready := _chosen_weight() > 0
	_cta_label.text = "REPRENDRE — COMBAT %d" % _run.fight if not _composing \
		else "LANCER LE COMBAT"
	_cta.modulate.a = 1.0 if ready else 0.5

	if not _composing and _hint_label.text.is_empty():
		# Au deuxieme combat d'une serie, la composition ne se refait pas :
		# elle a survecu au combat precedent, amputee de ses pertes et grossie
		# des releves. Le dire, sinon l'ecran a l'air casse.
		_hint_label.text = "Composition de la série — réduite des pertes, renforts compris."
	elif _composing and _chosen_weight() <= 0 and _hint_label.text.is_empty():
		_hint_label.text = "Touche une pièce de la caserne pour l'engager."


# ------------------------------- ENTREE ---------------------------------------

## ENTREE DE L'ECRAN - relevee sur la timeline Figma de la preparation
## (248:406, 2 s, douze noeuds, sur la page "Ecrans tries").
##
## Attention : c'est la COPIE de la page "Ecrans tries" qui porte la timeline,
## pas l'original 169:4. Le releve d'origine, fait sur les seize frames de la
## page principale, ne pouvait donc pas la voir.
##
## Ce qui est repris : les DECALAGES, les DUREES et les COURBES. La boucle de
## Figma est un artefact d'apercu - l'entree ne se joue qu'une fois.
##
## Ce qui ne l'est PAS : les translations. La maquette fait arriver les
## panneaux en diagonale (-30, +40) et (+30, +40) ; ici tous les panneaux sont
## enfants d'un VBoxContainer, et un tween de position s'y bat avec la mise en
## page - c'est le bug qui avait colle le bandeau de serie en haut de l'ecran.
## Restent l'opacite et l'ECHELLE, que la maquette anime aussi (0,95 pour les
## panneaux, 0,9 pour le bouton, 0,5 pour la banniere) et que les conteneurs
## ne touchent pas.
func _animate_entry() -> void:
	if not is_inside_tree():
		return

	var tween := create_tween()
	tween.set_parallel(true)

	# L'en-tete descend a plat dans la maquette : il ne reste que le fondu.
	_fade_in(tween, _header, 0.0, 0.5)

	# Les deux panneaux du haut arrivent ensemble (10 % -> 45 % de 2 s), le
	# deploiement et la caserne juste apres : la maquette n'avait qu'un panneau
	# joueur, le notre en fait deux.
	_rise(tween, _sections.get("stake"), 0.95, 0.1, 0.7)
	_rise(tween, _sections.get("enemy"), 0.95, 0.2, 0.7)
	_rise(tween, _sections.get("deployment"), 0.95, 0.3, 0.7)
	_rise(tween, _sections.get("barracks"), 0.95, 0.4, 0.7)
	_rise(tween, _sections.get("info"), 0.95, 0.7, 0.6)

	# La banniere ARMEE ENNEMIE eclot de 0,5 avec un depassement : c'est le
	# seul element de l'ecran que la maquette fait REBONDIR.
	var banner: Control = _sections.get("enemy_banner")
	if banner != null:
		banner.pivot_offset = banner.size / 2.0
		banner.modulate.a = 0.0
		banner.scale = Vector2(0.5, 0.5)
		tween.tween_property(banner, "modulate:a", 1.0, 0.3).set_delay(0.9)
		tween.tween_property(banner, "scale", Vector2.ONE, 0.4).set_delay(0.9) 			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_rise(tween, _cta, 0.9, 1.1, 0.7)


## Fondu simple, pour ce que la maquette fait arriver a plat.
func _fade_in(tween: Tween, node: Control, delay: float, duration: float) -> void:
	if node == null:
		return
	node.modulate.a = 0.0
	tween.tween_property(node, "modulate:a", 1.0, duration).set_delay(delay) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


## Un panneau qui se pose : il s'allume en revenant a sa taille.
##
## `pivot_offset` est pose ICI et pas a la construction : il se calcule sur la
## TAILLE du noeud, que le conteneur ne lui donne qu'une fois la mise en page
## faite. Pose trop tot, la plaque grandit par son coin haut-gauche.
func _rise(tween: Tween, node: Control, from: float, delay: float,
		duration: float) -> void:
	if node == null:
		return
	node.pivot_offset = node.size / 2.0
	node.modulate.a = 0.0
	node.scale = Vector2(from, from)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	tween.tween_property(node, "scale", Vector2.ONE, duration).set_delay(delay) 		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ------------------------------- BRIQUES -------------------------------------

## Un tap : le clic gauche relache. Ecrit une fois plutot que six.
func _is_tap(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT


func _box(bg: Color, edge: Color, width: float, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = edge
	box.set_border_width_all(int(ceilf(width)))
	box.set_corner_radius_all(int(radius))
	return box


## Coque rectangulaire de la maquette : un fond, un trait, un rayon, une marge.
## Toute la peau claire de l'ecran en sort.
##
## La marge est posee sur les `content_margin` de la StyleBox, PAS sur des
## constantes "margin_*" : un PanelContainer ne connait pas ces constantes -
## c'est le MarginContainer qui les lit. Pose la, une marge ne fait rien du
## tout, et le contenu vient coller le trait.
func _shell(bg: Color, edge: Color, width: float, radius: float,
		padding: int, saisissable: bool = false) -> PanelContainer:
	var panel: PanelContainer = Poignee.new() if saisissable else PanelContainer.new()
	var box := _box(bg, edge, width, radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## Marge asymetrique d'une coque deja construite (les pastilles de la maquette
## sont larges et plates : 10 ou 16 de cote, 4 en hauteur).
func _pad(panel: PanelContainer, horizontal: int, vertical: int) -> PanelContainer:
	var box: StyleBoxFlat = panel.get_theme_stylebox("panel")
	box.content_margin_left = horizontal
	box.content_margin_right = horizontal
	box.content_margin_top = vertical
	box.content_margin_bottom = vertical
	return panel


## Grand panneau blanc de section, deja pose dans le corps de l'ecran.
##
## `slot` sert a le retrouver dans _animate_entry : la timeline Figma fait
## arriver les panneaux l'un apres l'autre, il faut donc pouvoir les nommer.
func _panel(slot: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_EDGE, 1.0, 14.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(panel)
	if not slot.is_empty():
		_sections[slot] = panel

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	pad.add_child(column)
	return column


## Le libelle de la maquette : encre brune sur clair. Remplace `gold_label`,
## qui ne se lit pas sur du blanc.
func _ink_label(text: String, size: int, color: Color = INK,
		no_wrap: bool = false) -> Label:
	var label := UiTheme.make_label(text, size, color)
	label.add_theme_font_override("font", UiTheme.font_bold())
	if no_wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## La pastille bleu pale de la maquette (banniere d'ennemi, compteurs).
func _pill(text: String, size: int) -> PanelContainer:
	var pill := _pad(_shell(ACCENT_BG, TILE_EDGE, 1.0, 12.0, 0), 16, 4)
	var label := _ink_label(text, size, INK, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(label)
	UiTheme.ignore_mouse_recursive(pill)
	return pill


## Carte de piece : l'illustration, son nom, son niveau. Sert aux deux
## panneaux - l'ennemi en rouge, la caserne en bleu.
func _piece_card(type: String, team: String, title: String, level_text: String,
		name_size: int, art_width: float, art_height: float,
		saisissable: bool = false) -> PanelContainer:
	var card := _shell(TILE_BG, TILE_EDGE if team == "bleu" else PANEL_EDGE,
		1.0, 14.0, 8, saisissable)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var sprite := TextureRect.new()
	sprite.texture = UiTheme.piece_texture(team, type)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.custom_minimum_size = Vector2(art_width, art_height)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sprite)

	var name_label := _ink_label(title, name_size, INK, true)
	name_label.add_theme_font_override("font", UiTheme.font_black())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	column.add_child(name_label)

	if not level_text.is_empty():
		var level_label := _ink_label(level_text, 11, INK_SOFT, true)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(level_label)

	# La carte de caserne est CLIQUABLE : sans ca, un libelle qui garde le
	# filtre par defaut avale le tap et seule la moitie de la carte repond.
	# L'appelant remet la carte elle-meme en STOP apres coup.
	UiTheme.ignore_mouse_recursive(card)
	return card


func _status_pill(text: String, active: bool) -> PanelContainer:
	var pill := _pad(_shell(BEVEL_BG if active else TILE_BG,
		TILE_EDGE if active else PANEL_EDGE, 1.0, 8.0, 0), 6, 4)
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := _ink_label(text, 8, INK if active else INK_SOFT, true)
	label.add_theme_font_override("font", UiTheme.font_black())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	pill.add_child(label)
	UiTheme.ignore_mouse_recursive(pill)
	return pill


## Petit bouton de service, dans la peau claire de l'ecran.
func _light_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_font_override("font", UiTheme.font_bold())
	button.add_theme_color_override("font_color", INK_SOFT)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := ACCENT_BG
		if state == "hover":
			bg = BEVEL_BG
		elif state == "pressed":
			bg = BEVEL_BG.darkened(0.08)
		var box := _box(bg, TILE_EDGE, 1.0, 10.0)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, box)
	return button


## LA POIGNEE : une coque qu'on peut SAISIR, et sur laquelle on peut LACHER.
##
## ⚠️ Godot ne sait glisser-deposer que par TROIS VIRTUELLES de Control
## (`_get_drag_data`, `_can_drop_data`, `_drop_data`), et une virtuelle demande
## un script. Or les cartes de cet ecran sont construites a la main, sans scene
## ni script attache : il n'y avait donc aucun endroit ou les ecrire. D'ou
## cette coque, qui les porte toutes les trois et delegue a des `Callable` -
## le reste de l'ecran garde exactement la forme qu'il avait.
##
## ⚠️ ET LE TAP CONTINUE DE MARCHER. Godot ne demande `_get_drag_data` qu'une
## fois le bouton enfonce ET la souris deplacee ; un appui immobile part encore
## dans `gui_input`. Les deux gestes cohabitent donc sans se voler l'evenement,
## et c'est important : le tap est le chemin court, le glissement est celui que
## le joueur a demande.
##
## ⚠️ UNE ZONE QUI REFUSE FAIT REMONTER LE LACHER A SON PARENT. C'est ce qui
## permet de laisser les cases du deploiement refuser tout, et la zone qui les
## entoure accepter : le lacher tombe juste meme entre deux cases.
class Poignee extends PanelContainer:
	## Ce que la poignee DONNE quand on la saisit. Vide = on ne la saisit pas.
	var charge: Dictionary = {}
	## ⚠️ LA SILHOUETTE SE RESOUT AU MOMENT DU GLISSEMENT, PAS A LA
	## CONSTRUCTION. Elle etait posee sur chaque case et chaque carte a chaque
	## reconstruction - c'est-a-dire a chaque tap - alors que le joueur ne
	## glisse jamais qu'un seul noeud. La moitie des chargements de cet ecran
	## etait pour rien.
	var apercu_cote: float = SLOT_SIZE
	## (charge) -> bool : cette zone accepte-t-elle ce qu'on lui apporte ?
	var accepte: Callable
	## (charge) -> void : ce qu'elle en fait.
	var recoit: Callable

	func _get_drag_data(_position: Vector2) -> Variant:
		if charge.is_empty():
			return null
		UiTheme.drag_preview_for(self,
			UiTheme.piece_texture("bleu", String(charge.get("type", ""))),
			apercu_cote)
		return charge

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		return accepte.is_valid() and data is Dictionary and bool(accepte.call(data))

	func _drop_data(_position: Vector2, data: Variant) -> void:
		if recoit.is_valid():
			recoit.call(data)


## La case vide de la maquette : un carre arrondi au trait POINTILLE, marque
## d'un plus. Godot ne sait pas pointiller la bordure d'un StyleBoxFlat - il
## faut la tracer soi-meme, et le "+" avec (aucune icone du jeu ne le porte).
class DashedSlot extends Control:
	const FILL := Color("f2f7fb")
	const EDGE := Color("7fa6c2")
	const RADIUS := 10.0

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = FILL
		box.set_corner_radius_all(int(RADIUS))
		draw_style_box(box, Rect2(Vector2.ZERO, size))

		# Les quatre cotes droits, en sautant les coins arrondis : un pointille
		# qui suivrait la courbe demanderait un arc echantillonne pour un
		# resultat que personne ne distingue a 40 points de cote.
		var inset := 0.75
		var r := RADIUS
		var sides := [
			[Vector2(r, inset), Vector2(size.x - r, inset)],
			[Vector2(r, size.y - inset), Vector2(size.x - r, size.y - inset)],
			[Vector2(inset, r), Vector2(inset, size.y - r)],
			[Vector2(size.x - inset, r), Vector2(size.x - inset, size.y - r)],
		]
		for side in sides:
			draw_dashed_line(side[0], side[1], EDGE, 1.5, 4.0)

		var mid := size * 0.5
		var arm := 5.0
		draw_line(mid - Vector2(arm, 0), mid + Vector2(arm, 0), EDGE, 1.5)
		draw_line(mid - Vector2(0, arm), mid + Vector2(0, arm), EDGE, 1.5)
