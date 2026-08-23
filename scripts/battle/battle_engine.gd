class_name BattleEngine
extends RefCounted
##
## MOTEUR DE COMBAT - la boucle tour par tour, sans aucun affichage.
##
## Le combat se joue coup par coup, comme aux echecs : un camp deplace UNE
## piece de son choix, puis c'est a l'autre. Deux entrees pour un meme
## chemin de resolution :
##
##   play_move(unit, cell)  le joueur joue le coup qu'il a choisi
##   step()                 l'IA choisit ET joue le coup du camp courant
##
## Les deux retournent la liste des evenements qui viennent de se produire ;
## c'est la vue qui les rejoue. Le coup est deja resolu quand l'animation
## commence : celle-ci ne decide de rien, elle montre.
##
## Evenements produits :
##   {"type": "move",      "unit": id, "from": Vector2i, "to": Vector2i}
##   {"type": "capture",   "unit": id, "target": id, "cell": Vector2i}
##   {"type": "promotion", "unit": id, "cell": Vector2i, "result": String}
##   {"type": "pass",      "team": team}   camp sans aucun coup legal
##   {"type": "end",       "winner": team, "reason": String}
##

const TEAM_PLAYER := BattleUnit.TEAM_PLAYER
const TEAM_ENEMY := BattleUnit.TEAM_ENEMY

## Issue nulle : la bataille est finie et PERSONNE ne l'a gagnee. C'est la
## valeur que prend `winner` (cf. is_draw).
const TEAM_NONE := -1

var grid: GridModel
var units: Array = []

var finished: bool = false
var winner: int = -1
var activation_count: int = 0

## Numero du tour affiche : il avance quand la main revient au joueur.
var turn: int = 1

## Camp qui joue le prochain coup. Le joueur ouvre toujours la bataille.
var current_team: int = TEAM_PLAYER

## Niveau de jeu de l'armee ENNEMIE (cf. Balance.AI_NOVICE). C'est le seul
## niveau qui compte en partie : le camp du joueur, lui, est joue par le
## joueur.
var enemy_skill: int = Balance.AI_EXPERT

## Niveau de jeu du camp du JOUEUR quand l'IA le joue a sa place - ce qui
## n'arrive plus QUE dans les bancs (tools/). Au maximum par defaut : un banc
## qui mesure une bataille doit montrer ce que le placement vaut, pas ce qu'une
## IA distraite en ferait. Seul tools/ai_bench.tscn l'abaisse, pour faire jouer
## deux niveaux l'un contre l'autre.
var player_skill: int = Balance.AI_EXPERT

## Vrai quand les DEUX camps sont joues par l'IA - c'est-a-dire dans les BANCS,
## et nulle part ailleurs : le jeu n'offre plus aucun moyen de se jouer tout
## seul. En partie, certains garde-fous anti-blocage calibres sur des secondes
## d'animation n'ont plus de sens (cf. _stalemate_limit).
var auto_mode: bool = true

var _next_id: int = 1

## Materiel engage par chaque camp au depart, cumule a la pose des pieces.
## Sert a savoir si une bataille est encore DISPUTEE au moment ou un pion
## atteint le fond adverse (cf. _resolve, promotion).
var _material_at_start: Dictionary = {TEAM_PLAYER: 0, TEAM_ENEMY: 0}

## Dames deja couronnees par camp dans cette bataille (cf.
## Balance.PROMOTION_ONE_PER_BATTLE).
var _crowned: Dictionary = {TEAM_PLAYER: 0, TEAM_ENEMY: 0}

## Activations consecutives sans capture. Sert a detecter deux armees qui ne
## peuvent plus s'atteindre.
var _idle_activations: int = 0

## Tours passes d'affilee faute de coup legal : deux de suite et plus personne
## ne peut jouer (cf. _pass_turn).
var _passes_in_a_row: int = 0
## Activation a laquelle la position est devenue morte, ou -1. Sert au compte
## a rebours affiche avant le nul.
var _dead_position_since: int = -1


func _init(cols: int, rows: int) -> void:
	grid = GridModel.new(cols, rows)


# ------------------------------- CONSTRUCTION --------------------------------

func add_unit(type: String, level: int, team: int, cell: Vector2i) -> BattleUnit:
	var unit := BattleUnit.create(_next_id, type, level, team, cell)
	_next_id += 1
	units.append(unit)
	grid.place(unit, cell)
	_material_at_start[team] = int(_material_at_start.get(team, 0)) + unit.value
	return unit


## Retire une piece du plateau (utilise pendant la phase de placement).
func remove_unit(unit: BattleUnit) -> void:
	grid.remove_unit(unit)
	units.erase(unit)
	# Reprise pendant le placement : la piece n'aura jamais combattu.
	_material_at_start[unit.team] = maxi(
		0, int(_material_at_start.get(unit.team, 0)) - unit.value)


func unit_by_id(id: int) -> BattleUnit:
	for unit in units:
		if unit.id == id:
			return unit
	return null


func living(team: int) -> Array:
	var result: Array = []
	for unit in units:
		if unit.is_alive() and unit.team == team:
			result.append(unit)
	return result


## Pieces d'un camp capturees pendant la bataille, comptees par type d'origine.
## Une Dame promue puis prise compte comme le pion qu'elle etait.
func losses(team: int) -> Dictionary:
	var lost: Dictionary = {}
	for unit in units:
		if unit.team != team or unit.is_alive():
			continue
		lost[unit.origin_type] = int(lost.get(unit.origin_type, 0)) + 1
	return lost


## Pieces d'un camp promues pendant la bataille et encore debout a la fin.
## Cote joueur, ce sont les Dames qui rentrent vivantes : le pion qu'elles
## etaient quitte la caserne, la Dame rejoint le Chateau Royal
## (cf. GameState.store_promotions). Une Dame promue puis capturee ne compte
## pas : elle est perdue comme le pion qu'elle etait.
func promoted_survivors(team: int) -> int:
	var count := 0
	for unit in living(team):
		# Seules les DAMES rejoignent le Chateau Royal. Un pion promu en piece
		# intermediaire faute de bataille disputee (cf. _promotion_for) a
		# gagne sa mobilite pour ce combat, rien de plus : il redevient le
		# pion qu'il etait.
		if unit.promoted and unit.type == Balance.DAME:
			count += 1
	return count


## Les promus qui ne sont PAS des Dames, et qui ont survecu.
##
## ⚠️ AVANT, ILS DISPARAISSAIENT PUREMENT ET SIMPLEMENT. Le joueur, apres
## test : "apres avoir pousse un pion jusqu'a faire un cavalier, je n'ai pas
## gagne ce cavalier pour le combat par la suite". C'etait la regle ecrite, et
## il a demande a la changer.
##
## Sa decision : le promu RESTE EN LIGNE jusqu'au bout de la serie, puis
## redevient le pion qu'il etait. Meme traitement que la Dame pour la duree,
## sans le gain permanent - sinon 17 promotions sur 19 parties de banc
## rendraient les Ecuries inutiles, et il faudrait rejouer economy_probe
## pendant des heures pour le verifier.
func promoted_knights(team: int) -> int:
	var count := 0
	for unit in living(team):
		if unit.promoted and unit.type != Balance.DAME:
			count += 1
	return count

# ------------------------------- BOUCLE --------------------------------------

## Cases ou cette piece peut se rendre maintenant. C'est ce que la vue
## surligne quand le joueur saisit une piece.
func legal_moves(unit: BattleUnit) -> Array:
	if finished or unit == null or not unit.is_alive() or unit.team != current_team:
		return []
	return MovementRules.legal_moves(unit, grid)


## Cases des pieces de `team` que l'adversaire peut capturer a son prochain
## coup. La vue en fait un lisere rouge.
##
## C'est exactement la question que se pose l'IA avant de poser une piece
## quelque part (MovementRules.is_cell_threatened, dont elle vit depuis
## toujours) : on ne fait que la rendre lisible au joueur.
##
## Pourquoi ca compte. Le jeu n'a NI POINTS DE VIE NI DEGATS - une piece est sur
## le plateau, ou capturee, definitivement. Toute la tension d'un tel jeu tient
## a voir la piece qui attaque : aux echecs on ne ressent pas le danger parce
## que la position est mauvaise, mais parce qu'on voit l'attaque arriver. Sans
## ce signal, le danger existait sans jamais se montrer, et le joueur decouvrait
## ses pertes apres coup.
func threatened_cells(team: int) -> Array:
	var foe := TEAM_ENEMY if team == TEAM_PLAYER else TEAM_PLAYER
	var cells: Array = []
	for unit in living(team):
		if MovementRules.is_cell_threatened(unit.cell, foe, grid, units):
			cells.append(unit.cell)
	return cells


## Vrai si ce camp a au moins un coup legal. Un camp qui n'en a aucun passe
## son tour (cf. _pass_turn) plutot que de bloquer la partie.
func has_any_move(team: int) -> bool:
	for unit in living(team):
		if not MovementRules.legal_moves(unit, grid).is_empty():
			return true
	return false


## Coup joue par un humain. Retourne les evenements, ou une liste vide si le
## coup est refuse (piece adverse, case illegale, partie finie) : la vue n'a
## alors rien a rejouer et le tour ne change pas.
func play_move(unit: BattleUnit, destination: Vector2i) -> Array:
	if not legal_moves(unit).has(destination):
		return []
	return _resolve(unit, destination)


## Coup choisi ET joue par l'IA pour le camp courant.
func step() -> Array:
	var events: Array = []
	if finished:
		return events
	if _check_end(events):
		return events

	var skill: int = enemy_skill if current_team == TEAM_ENEMY else player_skill
	var choice := BattleAI.decide_team(
		current_team, grid, units, _idle_activations, _stalemate_limit(), skill)
	var unit: BattleUnit = choice["unit"]
	if unit == null:
		_pass_turn(events)
		return events

	return _resolve(unit, choice["move"])


## Resolution commune au coup humain et au coup de l'IA : capture, promotion,
## passage de main, fin de partie.
func _resolve(unit: BattleUnit, destination: Vector2i) -> Array:
	var events: Array = []
	if finished:
		return events

	activation_count += 1
	var from := unit.cell
	var captured := false

	var target: BattleUnit = grid.unit_at(destination)
	if target != null and unit.is_enemy_of(target):
		target.captured = true
		grid.remove_unit(target)
		captured = true
		unit.captures += 1
		events.append({
			"type": "capture",
			"unit": unit.id,
			"target": target.id,
			"cell": destination,
		})

	grid.move_unit(unit, destination)
	unit.has_moved = true
	events.append({"type": "move", "unit": unit.id, "from": from, "to": destination})

	# Promotion : un pion qui atteint le fond adverse devient Dame, comme aux
	# echecs. Elle garde le niveau du pion (voir BattleUnit.promote_to) : une
	# Dame issue d'un pion Nv.1 se deplace donc bien moins loin que celle d'un
	# pion Nv.10. Cote joueur, une Dame ramenee VIVANTE rejoint ensuite la
	# Chateau Royal (cf. promoted_survivors).
	var promotion_row := unit.promotion_row(grid.rows)
	if unit.origin_type == Balance.PION and not unit.promoted and destination.y == promotion_row:
		var result := _promotion_for(unit)
		unit.promote_to(result)
		# ⚠️ Le compteur des couronnes se tient ICI, et nulle part ailleurs.
		# Il vivait dans le chemin differe du sacre ; en retirant ce chemin,
		# l'oublier aurait laisse un camp couronner plusieurs Dames dans la
		# meme bataille, malgre PROMOTION_ONE_PER_BATTLE.
		if result == Balance.DAME:
			_crowned[unit.team] = int(_crowned.get(unit.team, 0)) + 1
		events.append({
			"type": "promotion", "unit": unit.id, "cell": destination, "result": unit.type,
		})

	_idle_activations = 0 if captured else _idle_activations + 1
	# Une prise vient d'avoir lieu : la position n'etait donc pas morte.
	if captured:
		_dead_position_since = -1
	_passes_in_a_row = 0
	_end_of_activation(events)
	return events


## PASSER SON TOUR N'EXISTE PLUS, et ce qui reste ici est un garde-fou.
##
## Deux portes menaient a une passe, et les deux sont fermees :
##   - le camp n'a aucun coup legal : il fait desormais NUL (cf.
##     _end_of_activation), la partie est finie avant d'arriver ici ;
##   - l'IA n'a rien voulu choisir : c'est un bug, pas une decision, et
##     BattleAI.decide_team joue maintenant un coup des qu'il en existe un.
##
## L'ancien compteur de deux passes consecutives ne pouvait de toute facon pas
## rattraper le second cas : le coup du JOUEUR le remettait a zero, donc une IA
## figee laissait la partie tourner indefiniment. C'est le bug qui a motive
## tout ceci - 48 passes illegitimes mesurees sur 60 parties.
func _pass_turn(events: Array) -> void:
	push_error("BattleEngine : passe de tour demandee alors que le camp %d a %d coup(s) legal(aux)"
		% [current_team, 1 if has_any_move(current_team) else 0])
	events.append({"type": "pass", "team": current_team})
	_finish(TEAM_NONE, "plus aucun coup possible", events)


## Fin d'activation, quel que soit le coup joue : passage de main, verdict.
func _end_of_activation(events: Array) -> void:
	current_team = _other_team(current_team)
	if current_team == TEAM_PLAYER:
		turn += 1

	if _check_end(events):
		return

	# PAT - le camp au trait n'a plus aucun coup legal. Comme aux echecs, c'est
	# un NUL, quel que soit le materiel restant.
	#
	# Avant, ce cas partait en verdict au materiel : un camp bloque pouvait
	# donc GAGNER une bataille qu'il ne jouait plus, ou la perdre sans avoir
	if not has_any_move(current_team):
		if bool(Balance.COMBAT["stalemate_is_draw"]):
			_finish(TEAM_NONE, "plus aucun coup possible", events)
		else:
			_finish(_other_team(current_team), "adversaire bloque", events)
		return

	# POSITION MORTE : plus aucune capture n'est possible, jamais. Inutile
	# d'attendre le compteur d'enlisement - il tomberait quatre-vingts
	# activations plus tard sur une bataille dont l'issue est deja connue.
	if _idle_activations >= int(Balance.COMBAT["dead_position_check_after"]):
		if _dead_position_since < 0 and not capture_still_possible():
			_dead_position_since = activation_count
		if _dead_position_since >= 0 \
				and activation_count - _dead_position_since >= int(Balance.COMBAT["dead_position_grace"]):
			_finish(TEAM_NONE, "plus aucune capture possible", events)
			return

	# Deux armees qui ne peuvent plus s'atteindre ne doivent pas bloquer la
	# partie : on tranche au nombre de pieces restantes.
	if _idle_activations >= _stalemate_limit():
		_finish_on_material("plus aucune prise possible", events)
	elif activation_count >= int(Balance.COMBAT["max_activations"]):
		_finish_on_material("limite de tours atteinte", events)


## Seuil d'enlisement exprime en activations, deduit du nombre de pieces
## encore en jeu : un tour complet coute une activation par piece vivante.
##
## Quand les deux camps sont joues par l'IA - donc dans les BANCS - le seuil
## est aussi plafonne a Balance.COMBAT.stalemate_seconds_cap : une simulation
## ne doit pas tourner indefiniment sur une position bloquee. En partie ce
## plafond ne s'applique pas - un humain a le droit de reflechir - et le seuil
## en tours est bien plus large, pour laisser la place aux manoeuvres sans
## prise.
func _stalemate_limit() -> int:
	var alive := living(TEAM_PLAYER).size() + living(TEAM_ENEMY).size()
	var rounds := int(Balance.COMBAT["stalemate_rounds" if auto_mode else "stalemate_rounds_manual"])
	var by_army_size := rounds * maxi(4, alive)
	if not auto_mode:
		return by_army_size
	var seconds_cap := int(Balance.COMBAT["stalemate_seconds_cap"])
	var by_seconds := int(ceil(float(seconds_cap) / float(Balance.COMBAT["step_delay"])))
	return mini(by_army_size, by_seconds)


## Vrai s'il reste au moins une capture POSSIBLE, un jour, dans cette position.
##
## Deux camps dont les pieces ne peuvent jamais se rencontrer ne se prendront
## jamais rien. Cas reel et frequent : un cavalier Nv.1 ne saute qu'en
## diagonale d'une case, il ne quitte donc JAMAIS la couleur de case ou il est
## pose - deux cavaliers Nv.1 sur des couleurs opposees peuvent se courir apres
## indefiniment. Le fou a la meme propriete, par construction.
##
## La reponse est volontairement PRUDENTE : les portees sont calculees sur un
## plateau vide (cf. MovementRules.reachable_on_empty_board), donc sur-estimees.
## On peut rater une position morte ; on ne peut pas en inventer une.
func capture_still_possible() -> bool:
	var mine := living(TEAM_PLAYER)
	var theirs := living(TEAM_ENEMY)
	if mine.is_empty() or theirs.is_empty():
		return false

	# Un pion encore en vie garde la position vivante : il avance vers le fond
	# adverse et, une fois Dame, il atteint tout.
	for unit in mine + theirs:
		if unit.origin_type == Balance.PION and not unit.promoted:
			return true

	var reach_mine: Dictionary = {}
	for unit in mine:
		for cell in MovementRules.reachable_on_empty_board(unit, grid.cols, grid.rows):
			reach_mine[cell] = true
	for unit in theirs:
		for cell in MovementRules.reachable_on_empty_board(unit, grid.cols, grid.rows):
			if reach_mine.has(cell):
				return true
	return false


## Coups restants avant le nul pour position morte, ou -1 si la position est
## encore vivante. Sert au badge d'annonce.
func dead_position_moves_remaining() -> int:
	if _dead_position_since < 0:
		return -1
	return maxi(0, int(Balance.COMBAT["dead_position_grace"])
		- (activation_count - _dead_position_since))


## Progression vers l'enlisement (0 = aucune prise recente, 1 = resolution
## imminente au materiel). Sert uniquement a l'affichage du "chrono" de
## blocage cote vue - la resolution elle-meme reste pilotee par step().
func stalemate_ratio() -> float:
	var limit := _stalemate_limit()
	return 0.0 if limit <= 0 else clampf(float(_idle_activations) / float(limit), 0.0, 1.0)


## Coups restants avant que le moteur tranche au materiel si aucune prise ne
## survient d'ici la. C'est le compte affiche par le badge de blocage : on
## parle au joueur en COUPS, parce que c'est lui qui tient l'horloge et qu'une
## seconde ne veut rien dire tant qu'il reflechit.
func stalemate_moves_remaining() -> int:
	return maxi(0, _stalemate_limit() - _idle_activations)



## Departage a la valeur totale des pieces restantes.
##
## L'egalite parfaite revient au JOUEUR des lors qu'il a joue lui-meme ses
## coups : perdre une bataille de plusieurs minutes sur un match nul est une
## punition que personne ne comprend. En resolution automatique, ou le
## placement fait tout, l'avantage reste a l'ennemi - au joueur d'aller
## chercher la victoire plutot que de miser sur le verdict.
## Bataille enlisee : on tranche au materiel restant. A EGALITE STRICTE,
## personne n'a gagne - c'est un nul.
##
## Avant, l'egalite etait attribuee au joueur en combat manuel : il suffisait
## alors de bloquer le plateau et de laisser filer le compteur pour encaisser
## la recompense pleine. Un camp qui MENE au materiel garde en revanche sa
## victoire : etre incapable d'attraper la derniere piece qui vous fuit ne
## doit pas effacer un avantage gagne.
func _finish_on_material(reason: String, events: Array) -> void:
	var mine := material(TEAM_PLAYER)
	var theirs := material(TEAM_ENEMY)
	if mine == theirs:
		_finish(TEAM_NONE, reason, events)
		return
	_finish(TEAM_PLAYER if mine > theirs else TEAM_ENEMY, reason, events)


## Vrai quand la bataille est finie sans vainqueur.
func is_draw() -> bool:
	return finished and winner == TEAM_NONE


## En quoi promeut un pion arrive au fond adverse.
##
## Une DAME ne se gagne que dans une bataille ENCORE DISPUTEE. Sinon c'est une
## promotion de ramassage : quand il ne reste plus rien en face, un pion se
## promene jusqu'au bout sans que personne puisse l'arreter, et la piece la
## plus precieuse du jeu tombe toute seule. Mesure avant la regle : la moitie
## des promotions arrivaient contre un adversaire deja sous un tiers de son
## materiel.
##
## Le pion promeut quand meme - il a traverse le plateau, il a merite mieux
## qu'un pion - mais en piece intermediaire (cf. Balance.PROMOTION_FALLBACK),
## qui ne rejoint pas le Chateau Royal a la fin de la bataille.
func _promotion_for(unit: BattleUnit) -> String:
	# Une seule couronne par camp et par bataille : une percee est un
	# evenement, pas une chaine de production. Un pion qui attend deja son
	# sacre compte comme couronne - sinon deux pions arrives coup sur coup
	# passeraient tous les deux.
	if Balance.PROMOTION_ONE_PER_BATTLE and _crown_taken(unit.team):
		return Balance.PROMOTION_FALLBACK

	# Il doit avoir fait ses preuves : un pion qui a traverse un couloir vide
	# n'a rien prouve.
	if Balance.PROMOTION_REQUIRES_CAPTURE and unit.captures <= 0:
		return Balance.PROMOTION_FALLBACK

	# Le trone plutot que la rangee, quand la regle est ouverte.
	if Balance.PROMOTION_THRONE_WIDTH > 0 and not _is_throne(unit.cell):
		return Balance.PROMOTION_FALLBACK

	var foe := _other_team(unit.team)
	var engaged := float(_material_at_start.get(foe, 0))
	if engaged <= 0.0:
		return Balance.PROMOTION_FALLBACK
	var ratio := float(material(foe)) / engaged
	if ratio >= Balance.PROMOTION_CONTESTED_RATIO:
		return Balance.DAME
	return Balance.PROMOTION_FALLBACK


## Vrai si ce camp a deja sa Dame de la bataille.
func _crown_taken(team: int) -> bool:
	return int(_crowned.get(team, 0)) > 0


## Cases centrales du fond adverse, quand le trone remplace la rangee entiere.
func _is_throne(cell: Vector2i) -> bool:
	var width: int = mini(Balance.PROMOTION_THRONE_WIDTH, grid.cols)
	var first := int(floor((float(grid.cols) - float(width)) / 2.0))
	return cell.x >= first and cell.x < first + width


func material(team: int) -> int:
	var total := 0
	for unit in living(team):
		total += unit.value
	return total


func _check_end(events: Array) -> bool:
	if finished:
		return true
	if living(TEAM_ENEMY).is_empty():
		_finish(TEAM_PLAYER, "armee ennemie capturee", events)
		return true
	if living(TEAM_PLAYER).is_empty():
		_finish(TEAM_ENEMY, "armee du Roi capturee", events)
		return true
	return false


func _finish(winning_team: int, reason: String, events: Array) -> void:
	finished = true
	winner = winning_team
	events.append({"type": "end", "winner": winning_team, "reason": reason})


func _other_team(team: int) -> int:
	return TEAM_ENEMY if team == TEAM_PLAYER else TEAM_PLAYER
