extends Control
class_name GuidePopup
##
## LES POPUPS D'ACCOMPAGNEMENT - chantier E.
##
## Le jeu a quatre regles qu'on ne peut pas deviner, et qui n'etaient
## expliquees nulle part au moment ou elles frappent. Chacune a son popup, et
## chaque popup se montre UNE FOIS, a l'instant precis ou la chose arrive -
## jamais dans un tutoriel d'ouverture que personne ne lit.
##
## ⚠️ DEUX REGLES DE FORME, toutes deux payees ailleurs :
##
## 1. UN POPUP QUI SE ROUVRE EST UNE PUNITION. Chacun porte un drapeau dans la
##    sauvegarde (GameState.has_seen_guide / mark_guide_seen), lu avec un
##    defaut a false pour que les vieilles sauvegardes se chargent sans
##    broncher.
##
## 2. AUCUN CHIFFRE N'EST ECRIT DANS LE TEXTE. La charge, le pourcentage de
##    l'aura, les poids des pieces : tout est interpole depuis Balance et
##    GameState au moment de l'affichage. Une transcription se decale des que
##    le jeu bouge - c'est exactement ce qui avait produit le codex faux.
##
## Le gabarit est celui de SeriesPopup : une Modal, des blocs titre + corps,
## un bouton qui ferme. Il ne pose aucune regle, il en explique.
##

const ModalScene := preload("res://scenes/ui/components/modal.tscn")
const DividerScene := preload("res://scenes/ui/components/ornate_divider.tscn")

signal closed

## Les quatre sujets. La cle sert de drapeau dans la sauvegarde.
const STALEMATE := "stalemate"
const LINEUP := "lineup"
const DAME_AURA := "dame_aura"
const REALTIME := "realtime"

var _modal: Modal


## Montre le popup `key` s'il n'a jamais ete vu, et le marque vu.
##
## Rend `true` s'il s'est ouvert - l'appelant peut ainsi enchainer autre chose
## quand il ne s'ouvre pas.
##
## ⚠️ NE RIEN AFFICHER PENDANT UN BANC. Les bancs rejouent des dizaines de
## parties : un popul modal a chaque nul bloquerait smoke_test, et il faudrait
## le decouvrir a la premiere execution de quarante minutes.
static func show_once(parent: Node, key: String) -> bool:
	if parent == null or not parent.is_inside_tree():
		return false
	if Game.has_seen_guide(key):
		return false
	Game.mark_guide_seen(key)

	var popup := GuidePopup.new()
	parent.add_child(popup)
	popup._build(key)
	return true


func _build(key: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_modal = ModalScene.instantiate()
	add_child(_modal)
	_modal.closed.connect(func():
		closed.emit()
		queue_free())

	match key:
		STALEMATE:
			_build_stalemate()
		LINEUP:
			_build_lineup()
		DAME_AURA:
			_build_dame_aura()
		REALTIME:
			_build_realtime()
		_:
			_modal.open("", Modal.Context.NEUTRAL)

	_skin()
	_modal.body.add_child(_dismiss())


# ------------------------------- LES QUATRE ----------------------------------

## LE PAT. Le plus utile des quatre, et de loin.
##
## Mesure : 6 des 19 parties du banc finissent nulles par pat, bataille 1
## comprise - presque toujours parce que l'ennemi est reduit a trois pions
## bloques alors que le joueur mene largement. Sans un mot, "NUL" ressemble a
## un bug, et c'en etait un avant qu'on affiche la raison.
##
## ⚠️ Ce popup n'a d'objet que si Balance.COMBAT.stalemate_is_draw vaut true.
## A false, le camp bloque PERD et il n'y a plus rien a expliquer : le retirer
## alors, ne pas le laisser mentir.
func _build_stalemate() -> void:
	# ⚠️ UNE COURONNE ENTIERE, PAS BRISEE. Le glyphe etait `crown_broken` -
	# celui du blason de la DEFAITE - et il disait donc exactement le contraire
	# du popup : un nul n'est pas une deroute, "ta serie n'est pas rompue" est
	# meme la troisieme regle de l'ecran. La maquette (499:23) pose un ♛, la
	# piece royale entiere.
	_modal.open("PERSONNE N'A GAGNÉ", Modal.Context.NEUTRAL, "crown")
	var body := _modal.body

	body.add_child(_paragraph(
		"L'ennemi n'avait plus un seul coup légal. Aux échecs comme ici, un camp "
		+ "qui ne peut plus bouger sans être déjà perdu fait match nul — même "
		+ "s'il ne lui restait que quelques pièces face à ton armée."))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("C'est une ressource, pas un défaut",
		"Acculé à ton tour, tu peux t'en servir : un camp qui n'a plus de coup "
		+ "à jouer sauve la partie au lieu de la perdre."))

	body.add_child(_rule("Le pat est fréquent ici",
		"Sur un plateau étroit, les pions se bloquent nez à nez — et un pion ne "
		+ "prend pas tout droit. Beaucoup plus souvent qu'aux échecs."))

	body.add_child(_rule("Ta série n'est pas rompue",
		"Un nul ne rapporte rien, mais il ne fait pas tomber la série : c'est un "
		+ "tour d'usure payé pour rien, pas une déroute."))


## RESERVE OU ARMEE. C'est le malentendu que le joueur a eu lui-meme :
## "apres le recrutement de troupe, rien ne change ensuite". Il avait raison
## sur le ressenti et tort sur la cause - le plafond n'a jamais ete l'effectif,
## c'est la CHARGE.
func _build_lineup() -> void:
	_modal.open("RECRUTER N'EST PAS COMPOSER", Modal.Context.BLUE, "house")
	var body := _modal.body

	body.add_child(_paragraph(
		"La caserne garde tout ce que tu recrutes. Le déploiement, lui, ne prend "
		+ "que ce que ton château peut porter."))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("Ta charge : %d" % Game.deploy_capacity(),
		"C'est le total que ton armée peut peser. Améliorer le Château Royal "
		+ "est la seule chose qui l'augmente."))

	body.add_child(_rule("Chaque pièce a son poids", _weights()))

	body.add_child(_rule("La charge se dépense ici, une fois",
		"Le placement ne fait plus que poser ce que tu viens de choisir. Ta "
		+ "composition survit à la série et se réduit de tes pertes."))


## L'AURA. Un vrai choix - deployer la Dame ou encaisser sa part - et il est
## strictement indevinable.
func _build_dame_aura() -> void:
	_modal.open("UNE DAME AU REPOS RAPPORTE", Modal.Context.GOLD, "crown")
	var body := _modal.body

	body.add_child(_paragraph(
		"Ta Dame est rentrée vivante et tient la cour au Château Royal."))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("+%d %% d'or par bataille" % _aura_percent(),
		"Tant qu'elle reste au château, chaque bataille gagnée rapporte cette "
		+ "part en plus. Le bonus se compte par Dame AU REPOS."))

	body.add_child(_rule("Ou elle se bat",
		"Déployée, c'est la pièce la plus puissante du plateau — et elle peut "
		+ "tomber. Une Dame perdue ne revient pas."))

	body.add_child(_rule("Le choix se repose à chaque bataille",
		"Rien n'est définitif : tu décides au placement, une bataille à la fois."))


## LE TEMPS REEL. Le plus mineur des quatre, mais un joueur qui croit devoir
## laisser le jeu ouvert quatre heures ne le laisse pas ouvert - il arrete de
## jouer.
func _build_realtime() -> void:
	_modal.open("LE CHANTIER TOURNE SANS TOI", Modal.Context.BLUE, "clock")
	var body := _modal.body

	body.add_child(_paragraph(
		"Une amélioration prend du temps RÉEL, et il continue de s'écouler "
		+ "quand le jeu est fermé."))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("Tu peux fermer le jeu",
		"Le compte à rebours ne s'arrête pas. Reviens quand il est terminé."))

	body.add_child(_rule("Ou l'abréger",
		"Un coffre de la boutique donne du temps d'amélioration — le Légendaire "
		+ "termine un chantier d'un coup."))


# ------------------------------- LA PEAU COMMUNE -----------------------------
#
#  LES QUATRE POPUPS SONT UNE FAMILLE, et les quatre maquettes le disent :
#  13-popup-guide-pat (499:2), 14 (500:2), 15 (500:55) et 16 (500:108) portent
#  exactement le meme habillage, quel que soit le sujet. C'est ce qui les fait
#  reconnaitre comme LA VOIX DU JEU plutot que comme quatre popups de plus.
#
#  Le code les servait au contraire dans quatre contextes differents (NEUTRAL,
#  BLUE, GOLD, BLUE), ce qui donnait au popup du pat un cadre gris et une
#  couronne grise - la seule chose qu'on voyait de lui etait qu'il etait terne.
#
#  Releve sur 499:18, valeurs exactes : cadre 2 pt #ffd700 (l'or VIF, pas le
#  #d4af37 sourd des autres modales), pastille d'en-tete #262c3f avec le
#  glyphe en #ffd700, titre #a0aabf, corps #ccd1e0, titres de regle #ffd700.

## Le cadre des quatre : l'or vif, pas l'or sourd des modales ordinaires.
const FRAME := Color("ffd700")
## Le disque derriere le glyphe.
const BADGE := Color("262c3f")
## Le titre des quatre. ⚠️ GRIS, ET DANS LES QUATRE : les maquettes lui donnent
## la meme couleur quel que soit le sujet, alors que Modal.set_context le
## colorait selon l'accent - or pour l'aura, bleu pour la composition. Deux ors
## empiles (le titre et les titres de regle) se disputent l'oeil ; le gris rend
## aux regles leur relief.
const TITLE := Color("a0aabf")
## Le bouton J'AI COMPRIS, releve sur Btn-Dismiss (499:157).
const DISMISS_BG := Color("ffc800")
const DISMISS_BORDER := Color("b8860b")
const DISMISS_INK := Color("331f00")


func _skin() -> void:
	_modal.set_border_color(FRAME)
	_modal.set_header_badge(BADGE, FRAME)
	_modal.set_title_color(TITLE)


# ------------------------------- FABRIQUE ------------------------------------

## Les poids, relus dans Balance. Ecrire "Pion 1, Cavalier 3" a la main serait
## faux le jour ou un poids bouge.
func _weights() -> String:
	var parts: PackedStringArray = []
	for type in Balance.ARMY_TYPES:
		parts.append("%s %d" % [Balance.unit_name(type), Balance.deploy_weight(type)])
	return ", ".join(parts) + "."


func _aura_percent() -> int:
	return int(round(float(Balance.DAME_GOLD_BONUS) * 100.0))


func _paragraph(text: String) -> Label:
	var label := UiTheme.make_label(text, 12, Color("ccd1e0"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _rule(title_text: String, body_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)

	var title := UiTheme.gold_label(title_text, 13)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var text := UiTheme.make_label(body_text, 11, Color("ccd1e0"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	return column


## LE BOUTON QUI FERME, releve sur Btn-Dismiss (499:157) : fond #ffc800,
## liseré 2 pt #b8860b, coins a 12, libelle Inter Bold 13 en #331f00.
##
## ⚠️ IL ETAIT EN OR SOURD AVEC UN LIBELLE BLANC. `UiTheme.make_button` laisse
## la couleur de texte du theme, qui est claire : "J'AI COMPRIS" en blanc sur
## #c59b27 est le pire contraste de tout le jeu, et c'est le seul bouton de ces
## quatre ecrans.
func _dismiss() -> Button:
	var button := UiTheme.make_button("J'AI COMPRIS", DISMISS_BG, 13)
	button.add_theme_font_override("font", UiTheme.font_bold())
	button.add_theme_color_override("font_color", DISMISS_INK)
	button.add_theme_color_override("font_hover_color", DISMISS_INK)
	button.add_theme_color_override("font_pressed_color", DISMISS_INK)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = DISMISS_BG
		if state == "hover":
			box.bg_color = DISMISS_BG.lightened(0.12)
		elif state == "pressed":
			box.bg_color = DISMISS_BG.darkened(0.18)
		box.border_color = DISMISS_BORDER
		box.set_border_width_all(2)
		box.set_corner_radius_all(12)
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, box)
	UiTheme.press_feedback(button)
	button.pressed.connect(func(): _modal.close())
	return button
