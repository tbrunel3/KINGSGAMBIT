class_name CampaignRun
extends RefCounted
##
## SERIE DE COMBATS - un niveau de campagne ne se gagne plus en une bataille.
##
## Les derniers niveaux se jouent en plusieurs combats d'affilee (cf. Balance
## "fights"), sans retour au village entre les deux. Les trois premiers n'en
## comptent qu'un : on y decouvre le jeu, on ne s'y epuise pas - et a un seul
## combat, tout ce fichier devient transparent. Ce qui fait la difficulte n'est pas
## une armee ennemie qui grossit - elle est la meme a chaque combat - mais
## l'USURE : l'ennemi revient au complet, le joueur revient avec ses
## survivants.
##
## Trois regles fixent l'enjeu :
##
##   1. Les pertes ne sont retirees de l'armee du village qu'a la FIN de la
##      serie. Pendant, elles vivent ici : la serie est une seule unite
##      economique, pas trois batailles cote a cote.
##   2. Entre deux combats, le joueur releve pour Balance.RUN_REINFORCE_WEIGHT
##      de poids parmi ses pertes, les moins cheres d'abord - les pions se
##      relevent, pas les tours. C'est ce qui empeche la spirale.
##   3. Perdre un seul combat perd la serie entiere, et donc tout l'or promis.
##      Gagner le troisieme combat sur trois paye les trois. Un combat NUL, lui,
##      ne rapporte rien mais ne rompt pas la serie : c'est un tour d'usure.
##
## Une DAME faite en cours de serie ne se met pas a l'abri : elle reste en
## ligne jusqu'au dernier combat (cf. _enlist_dames). C'est ce qui rend une
## Dame difficile a garder autant qu'a faire.
##
## L'objet se serialise (to_dict / from_dict) : une serie en cours survit a la
## fermeture du jeu. La reprise se fait au COMBAT suivant - quitter au milieu
## d'un combat le fait recommencer, avec le meme effectif.
##

var battle_id: int = 1

## Combat en cours, a partir de 1.
var fight: int = 1

## Nombre de combats de la serie.
var total: int = 1

## Pieces encore disponibles pour la serie, par type - la RESERVE de la serie,
## a la place de l'armee du village.
var roster: Dictionary = {}

## COMPOSITION choisie par le joueur : le sous-ensemble du roster qui part
## vraiment au combat, dans la limite de la charge du chateau (cf.
## Balance.deploy_capacity). C'est elle, et non le roster, que le placement
## propose - "on aurait acces aux pieces choisies dans le panneau deploiement".
##
## Recruter remplit le ROSTER, composer remplit le LINEUP : c'est la
## distinction que le jeu ne montrait nulle part, et qui faisait croire que
## recruter ne changeait rien.
##
## VIDE = aucune composition posee. Le placement retombe alors sur le roster
## entier, exactement comme avant l'ecran de composition. Ce n'est pas un cas
## d'erreur : c'est le chemin des bancs, qui n'ouvrent jamais la preparation,
## et c'est ce qui leur laisse mesurer la meme chose qu'avant.
##
## Elle SURVIT a la serie et se REDUIT des pertes (cf. _take_losses) ; les
## renforts releves entre deux combats y rentrent (cf. _reinforce), sans quoi
## le joueur ne pourrait pas les poser.
var lineup: Dictionary = {}

## Pertes cumulees depuis le debut de la serie, appliquees a l'armee du
## village a la fin seulement.
var losses: Dictionary = {}

## Or promis par les combats deja remportes. Verse a la fin de la serie.
var reward: int = 0

var enemies_defeated: int = 0
var promotions: int = 0

## Dames FAITES pendant la serie et encore en vie. Elles ne sont creditees au
## Chateau Royal qu'a la fin : une Dame promue au premier combat doit tenir
## jusqu'au dernier.
var dames_made: int = 0

## Combats nuls depuis le debut de la serie. Un nul rejoue le combat au lieu
## de le consommer (cf. replay) ; ce compteur est ce qui empeche la boucle
## infinie - au-dela de Balance.RUN_DRAWS_ALLOWED, la serie s'acheve.
var draws: int = 0

## LA CHARGE DE LA SERIE, GELEE A SON OUVERTURE.
##
## ⚠️ ELLE ETAIT RELUE A CHAUD, et c'etait une vraie fuite. Une serie ne
## repasse pas par le village entre deux combats - mais on PEUT y retourner
## (fermer le codex, la boutique, le chateau y ramene, et depuis la fiche 2
## cela n'abandonne plus la serie). Ameliorer le Chateau Royal au milieu d'une
## serie augmentait donc la charge des combats suivants, alors que l'armee
## ennemie, elle, revient identique a chaque fois.
##
## Ce n'est pas un detail d'equilibrage : la serie est "une seule unite
## economique, pas trois batailles cote a cote", et toute la difficulte du jeu
## tient a l'USURE. Une charge qui monte en cours de route annule l'usure.
##
## Zero = une sauvegarde ecrite avant ce correctif : on retombe alors sur la
## charge courante, comme avant.
var capacity: int = 0


## Promus NON-Dames faits pendant la serie et encore en ligne. Ils restent
## jusqu'au dernier combat puis redeviennent des pions : le village n'en voit
## jamais un seul, puisque seule `losses` lui est appliquee a la fin.
var knights_made: int = 0


## Ouvre une serie sur cette bataille, avec l'armee du village au complet.
static func start(id: int, fights: int, army: Dictionary,
		deploy_capacity: int = 0) -> CampaignRun:
	var run := CampaignRun.new()
	run.battle_id = id
	run.total = maxi(1, fights)
	run.fight = 1
	run.roster = army.duplicate()
	run.capacity = maxi(0, deploy_capacity)
	return run


func is_last_fight() -> bool:
	return fight >= total


## Effectif encore en lice, toutes pieces confondues. Sert aux ecrans : c'est
## le chiffre qui dit si la serie est encore tenable.
func pieces_left() -> int:
	var total_pieces := 0
	for count in roster.values():
		total_pieces += int(count)
	return total_pieces


# ------------------------------- COMPOSITION ---------------------------------

## Une composition a-t-elle ete posee ? Sinon le placement propose le roster
## entier (cf. le commentaire de `lineup`).
func has_lineup() -> bool:
	for count in lineup.values():
		if int(count) > 0:
			return true
	return false


## Ce que le placement propose : la composition si elle existe, le roster
## sinon. C'est le SEUL endroit qui tranche entre les deux.
func deployable() -> Dictionary:
	return lineup.duplicate() if has_lineup() else roster.duplicate()


## Pieces de ce type restees a la caserne : possedees, mais pas choisies.
func reserve(type: String) -> int:
	return maxi(0, int(roster.get(type, 0)) - int(lineup.get(type, 0)))


## Charge depensee par la composition (cf. Balance.deploy_weight). C'est le
## seul budget que le joueur depense : le placement ne fait plus que poser ce
## qui a deja ete choisi.
func lineup_weight() -> int:
	var weight := 0
	for type in lineup.keys():
		weight += int(lineup[type]) * Balance.deploy_weight(type)
	return weight


## Pose la composition du joueur, bornee au roster et a la charge. Les deux
## bornes sont appliquees ICI plutot qu'a l'ecran : une composition relue d'une
## vieille sauvegarde, ou memorisee quand le chateau etait plus grand, doit
## rentrer elle aussi.
func set_lineup(chosen: Dictionary, capacity: int) -> void:
	var clean: Dictionary = {}
	var weight := 0
	# Les plus legeres d'abord : si la charge ne suffit plus, c'est la piece
	# la plus chere qu'on laisse a la caserne, pas trois pions.
	var types: Array = chosen.keys()
	types.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))
	for type in types:
		var wanted := mini(int(chosen[type]), int(roster.get(type, 0)))
		var unit_weight: int = Balance.deploy_weight(type)
		while wanted > 0 and weight + unit_weight <= capacity:
			clean[type] = int(clean.get(type, 0)) + 1
			weight += unit_weight
			wanted -= 1
	lineup = clean


## Retire une piece de la composition, si elle y est. Utilise partout ou le
## roster perd une piece : la composition ne doit jamais promettre au
## placement une piece qui n'existe plus.
func _drop_from_lineup(type: String, count: int) -> void:
	if count <= 0 or not lineup.has(type):
		return
	lineup[type] = maxi(0, int(lineup[type]) - count)


## Enregistre un combat gagne : ce qui est tombe sort de l'effectif, ce qui
## est gagne s'accumule, et les Dames faites restent en ligne.
func record_victory(fight_losses: Dictionary, defeated: int, won_promotions: int,
		dames: int, gold: int, knights: int = 0) -> void:
	_record_fight(fight_losses, defeated, won_promotions, dames, knights)
	reward += gold


## Combat nul : la serie continue, mais ce combat-la n'a rien rapporte. Les
## survivants restent en ligne, les morts restent morts.
func record_draw(fight_losses: Dictionary, defeated: int, won_promotions: int,
		dames: int, knights: int = 0) -> void:
	draws += 1
	_record_fight(fight_losses, defeated, won_promotions, dames, knights)


## Enregistre le combat perdu qui met fin a la serie.
func record_defeat(fight_losses: Dictionary) -> void:
	_take_losses(fight_losses)


func _record_fight(fight_losses: Dictionary, defeated: int, won_promotions: int,
		dames: int, knights: int = 0) -> void:
	_take_losses(fight_losses)
	enemies_defeated += defeated
	promotions += won_promotions
	_enlist_dames(dames)
	_enlist_knights(knights)


## Les Dames faites au combat precedent REPRENNENT LE CHEMIN au combat
## suivant : le pion qu'elles etaient quitte l'effectif, elles le rejoignent.
##
## C'est ce qui rend une Dame difficile a GARDER : elle ne se met pas a l'abri
## des qu'elle est couronnee, elle doit traverser toute la serie. Face a une
## recherche qui adore prendre une piece a cinq points, ce n'est pas rien.
func _enlist_dames(count: int) -> void:
	if count <= 0:
		return
	var composed := has_lineup()
	var from_pawns := mini(count, int(roster.get(Balance.PION, 0)))
	roster[Balance.PION] = int(roster.get(Balance.PION, 0)) - from_pawns
	roster[Balance.DAME] = int(roster.get(Balance.DAME, 0)) + count
	# La composition suit : le pion couronne etait forcement dedans, c'est lui
	# qui a traverse le plateau. Sans ca, la Dame faite au combat 1 ne serait
	# pas posable au combat 2.
	if composed:
		_drop_from_lineup(Balance.PION, from_pawns)
		lineup[Balance.DAME] = int(lineup.get(Balance.DAME, 0)) + count
	dames_made += count


## Les promus NON-Dames restent en ligne le temps de la serie.
##
## Calque sur _enlist_dames, a une difference pres qui fait tout : PAS de
## compteur permanent. Le village n'apprend jamais leur existence - seule
## `losses` lui est appliquee a la fin -, donc le pion qu'ils etaient est
## toujours a la caserne quand la serie se termine. C'est exactement "il reste
## pour la serie, puis redevient pion".
func _enlist_knights(count: int) -> void:
	if count <= 0:
		return
	var composed := has_lineup()
	var from_pawns := mini(count, int(roster.get(Balance.PION, 0)))
	if from_pawns <= 0:
		return
	roster[Balance.PION] = int(roster.get(Balance.PION, 0)) - from_pawns
	roster[Balance.PROMOTION_FALLBACK] = 		int(roster.get(Balance.PROMOTION_FALLBACK, 0)) + from_pawns
	if composed:
		_drop_from_lineup(Balance.PION, from_pawns)
		lineup[Balance.PROMOTION_FALLBACK] = 			int(lineup.get(Balance.PROMOTION_FALLBACK, 0)) + from_pawns
	knights_made += from_pawns


func _take_losses(fight_losses: Dictionary) -> void:
	var composed := has_lineup()
	for type in fight_losses.keys():
		var count := int(fight_losses[type])

		# Ce qui tombe quitte AUSSI la composition : une piece morte au combat
		# 1 ne doit pas se reproposer au combat 2. C'est le "se reduit" de la
		# regle choisie - la composition survit a la serie, amputee.
		if composed:
			_drop_from_lineup(type, count)

		# Une Dame FAITE pendant la serie qui tombe ne coute pas une Dame au
		# village - il n'y en avait aucune la-bas. Elle coute le PION qu'elle
		# etait : c'est ce pion qui manquera a la caserne.
		# Meme raisonnement que pour la Dame ci-dessous : un promu fait
		# PENDANT la serie qui tombe ne coute pas une piece de ce type au
		# village - il n'y en avait pas. Il coute le PION qu'il etait.
		# Sans ca, un cavalier promu qui meurt supprimerait un VRAI cavalier
		# de l'armee du joueur.
		if type == Balance.PROMOTION_FALLBACK and knights_made > 0:
			var was_knight := mini(count, knights_made)
			knights_made -= was_knight
			count -= was_knight
			roster[type] = maxi(0, int(roster.get(type, 0)) - was_knight)
			losses[Balance.PION] = int(losses.get(Balance.PION, 0)) + was_knight
			if count <= 0:
				continue

		if type == Balance.DAME and dames_made > 0:
			var was_made := mini(count, dames_made)
			dames_made -= was_made
			count -= was_made
			roster[Balance.DAME] = maxi(0, int(roster.get(Balance.DAME, 0)) - was_made)
			losses[Balance.PION] = int(losses.get(Balance.PION, 0)) + was_made
			if count <= 0:
				continue

		losses[type] = int(losses.get(type, 0)) + count
		roster[type] = maxi(0, int(roster.get(type, 0)) - count)


## Passe au combat suivant et releve les blesses. Retourne ce qui a ete
## remis en ligne, {type: nombre}, pour que l'ecran puisse l'annoncer.
## `capacity` est la charge du chateau : les releves rentrent dans la
## composition, jamais au-dela d'elle. Passee en parametre plutot que lue sur
## Game - CampaignRun est justement l'objet que GameState serialise, et n'a
## rien a savoir de lui.
func advance(reinforce_weight: int, capacity: int = 0) -> Dictionary:
	fight += 1
	return _reinforce(reinforce_weight, capacity)


## Rejoue LE MEME combat : on releve les blesses, mais le compteur de combats
## ne bouge pas. C'est ce que fait un nul.
##
## Un nul est un tour d'usure paye pour rien, pas un combat gagne : le faire
## avancer revenait a offrir la serie a qui savait bloquer la position. Le
## garde-fou est le plafond de nuls (draws_spent).
func replay(reinforce_weight: int, capacity: int = 0) -> Dictionary:
	return _reinforce(reinforce_weight, capacity)


## Vrai quand la serie a epuise sa tolerance aux nuls et doit s'achever.
func draws_spent(limit: int) -> bool:
	return draws >= limit


## Rend au roster, en piochant dans les pertes de la serie, jusqu'a epuiser le
## budget de poids. Les moins cheres d'abord : c'est la pietaille qu'on releve.
##
## Une piece relevee n'est plus une perte - elle ne sera donc pas retiree de
## l'armee du village a la fin de la serie.
func _reinforce(weight_budget: int, capacity: int) -> Dictionary:
	var recovered: Dictionary = {}
	var budget := weight_budget
	var composed := has_lineup()
	var used := lineup_weight()

	var types: Array = []
	for type in losses.keys():
		if int(losses[type]) > 0:
			types.append(type)
	types.sort_custom(func(a, b): return Balance.deploy_weight(a) < Balance.deploy_weight(b))

	for type in types:
		var weight: int = Balance.deploy_weight(type)
		while budget >= weight and int(losses[type]) > 0:
			budget -= weight
			losses[type] = int(losses[type]) - 1
			roster[type] = int(roster.get(type, 0)) + 1
			recovered[type] = int(recovered.get(type, 0)) + 1

			# LE RENFORT REJOINT LA COMPOSITION, sinon il se releve dans une
			# caserne que le joueur ne rouvrira pas avant la fin de la serie -
			# il serait vivant et impossible a poser. La charge reste la borne :
			# une piece relevee prend la place que sa mort avait liberee.
			if composed and used + weight <= capacity:
				lineup[type] = int(lineup.get(type, 0)) + 1
				used += weight

	return recovered


func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"fight": fight,
		"total": total,
		"roster": roster.duplicate(),
		"lineup": lineup.duplicate(),
		"losses": losses.duplicate(),
		"reward": reward,
		"enemies_defeated": enemies_defeated,
		"promotions": promotions,
		"dames_made": dames_made,
		"knights_made": knights_made,
		"draws": draws,
		"capacity": capacity,
	}


static func from_dict(data: Dictionary) -> CampaignRun:
	var run := CampaignRun.new()
	run.battle_id = int(data.get("battle_id", 1))
	run.fight = int(data.get("fight", 1))
	run.total = maxi(1, int(data.get("total", 1)))
	run.reward = int(data.get("reward", 0))
	run.enemies_defeated = int(data.get("enemies_defeated", 0))
	run.promotions = int(data.get("promotions", 0))
	run.dames_made = int(data.get("dames_made", 0))
	# Absent des sauvegardes d'avant le plafond de nuls : elles reprennent a zero.
	run.draws = int(data.get("draws", 0))
	run.knights_made = int(data.get("knights_made", 0))
	# Absente des sauvegardes d'avant le gel de la charge : elles retombent
	# sur la charge courante, exactement comme avant.
	run.capacity = int(data.get("capacity", 0))

	# Les cles reviennent du disque en String et les valeurs en float (JSON) :
	# on les repasse par des entiers, sinon un "3.0" se glisse dans un
	# compteur d'unites et le placement affiche des pieces a la virgule.
	# "lineup" manque aux sauvegardes d'avant l'ecran de composition : elles
	# reviennent avec une composition vide, donc au placement sur roster
	# entier - le comportement qu'elles avaient. Rien a migrer.
	for source in [["roster", data.get("roster", {})],
			["lineup", data.get("lineup", {})],
			["losses", data.get("losses", {})]]:
		var target: Dictionary = {}
		var raw: Dictionary = source[1]
		for type in raw.keys():
			target[String(type)] = int(raw[type])
		run.set(String(source[0]), target)

	return run
