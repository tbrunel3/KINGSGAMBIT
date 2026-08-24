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
	_modal.open("PERSONNE N'A GAGNÉ", Modal.Context.NEUTRAL, "crown_broken")
	var body := _modal.body

	body.add_child(_paragraph(
		"L'ennemi n'avait plus un seul coup légal. Aux échecs comme ici, un camp "
		+ "qui ne peut plus bouger sans être déjà perdu fait match nul — même "
		+ "s'il ne lui restait que quelques pièces face à ton armée."))
	body.add_child(DividerScene.instantiate())

	body.add_child(_rule("C'est une ressource, pas un défaut",
		"Acculé à ton tour, tu peux t'en servir : un camp qui n'a plus de coup "
		+ "à jouer sauve la partie au lieu de la perdre.", RULE_GREEN))

	body.add_child(_rule("Le pat est fréquent ici",
		"Sur un plateau étroit, les pions se bloquent nez à nez — et un pion ne "
		+ "prend pas tout droit. Beaucoup plus souvent qu'aux échecs."))

	body.add_child(_rule("Ta série n'est pas rompue",
		"Un nul ne rapporte rien, mais il ne fait pas tomber la série : c'est un "
		+ "tour d'usure payé pour rien, pas une déroute.", RULE_RED))


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
		+ "composition survit à la série et se réduit de tes pertes.", RULE_RED))


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
		+ "tomber. Une Dame perdue ne revient pas.", RULE_RED))

	body.add_child(_rule("Le choix se repose à chaque bataille",
		"Rien n'est définitif : tu décides au placement, une bataille à la fois.",
		RULE_GREEN))


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
		"Le compte à rebours ne s'arrête pas. Reviens quand il est terminé.",
		RULE_GREEN))

	body.add_child(_rule("Ou l'abréger",
		"Un coffre de la boutique donne du temps d'amélioration — le Légendaire "
		+ "termine un chantier d'un coup."))


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


## ⚠️ LES TROIS TITRES N'ONT PAS LA MEME COULEUR, ET C'EST LA MAQUETTE (fiche 6).
##
## Ils etaient tous en or. Les quatre frames du designer (499:2, 500:2, 500:55,
## 500:108) leur donnent une teinte chacun, et ce n'est pas decoratif : elle dit
## de quel genre est la regle. La rassurante est verte, le fait est or, et celle
## qui parle de ce qu'on peut perdre est rouge. Trois lignes d'or les rendaient
## interchangeables, alors qu'on ne les lit pas pour la meme raison.
const RULE_GOLD := Color("ffd11a")
const RULE_GREEN := Color("5fd08a")
const RULE_RED := Color("ff7a5c")


func _rule(title_text: String, body_text: String,
		teinte: Color = RULE_GOLD) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)

	var title := UiTheme.make_label(title_text, 13, teinte)
	title.add_theme_font_override("font", UiTheme.font_bold())
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var text := UiTheme.make_label(body_text, 11, Color("ccd1e0"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	return column


func _dismiss() -> Button:
	var button := UiTheme.make_button("J'AI COMPRIS", UiTheme.GOLD_BUTTON, 15)
	button.pressed.connect(func(): _modal.close())
	return button
