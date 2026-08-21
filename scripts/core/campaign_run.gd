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

## Pieces encore disponibles pour la serie, par type. C'est ce que le
## placement propose, a la place de l'armee du village.
var roster: Dictionary = {}

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


## Ouvre une serie sur cette bataille, avec l'armee du village au complet.
static func start(id: int, fights: int, army: Dictionary) -> CampaignRun:
	var run := CampaignRun.new()
	run.battle_id = id
	run.total = maxi(1, fights)
	run.fight = 1
	run.roster = army.duplicate()
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


## Enregistre un combat gagne : ce qui est tombe sort de l'effectif, ce qui
## est gagne s'accumule, et les Dames faites restent en ligne.
func record_victory(fight_losses: Dictionary, defeated: int, won_promotions: int,
		dames: int, gold: int) -> void:
	_record_fight(fight_losses, defeated, won_promotions, dames)
	reward += gold


## Combat nul : la serie continue, mais ce combat-la n'a rien rapporte. Les
## survivants restent en ligne, les morts restent morts.
func record_draw(fight_losses: Dictionary, defeated: int, won_promotions: int,
		dames: int) -> void:
	_record_fight(fight_losses, defeated, won_promotions, dames)


## Enregistre le combat perdu qui met fin a la serie.
func record_defeat(fight_losses: Dictionary) -> void:
	_take_losses(fight_losses)


func _record_fight(fight_losses: Dictionary, defeated: int, won_promotions: int,
		dames: int) -> void:
	_take_losses(fight_losses)
	enemies_defeated += defeated
	promotions += won_promotions
	_enlist_dames(dames)


## Les Dames faites au combat precedent REPRENNENT LE CHEMIN au combat
## suivant : le pion qu'elles etaient quitte l'effectif, elles le rejoignent.
##
## C'est ce qui rend une Dame difficile a GARDER : elle ne se met pas a l'abri
## des qu'elle est couronnee, elle doit traverser toute la serie. Face a une
## recherche qui adore prendre une piece a cinq points, ce n'est pas rien.
func _enlist_dames(count: int) -> void:
	if count <= 0:
		return
	var from_pawns := mini(count, int(roster.get(Balance.PION, 0)))
	roster[Balance.PION] = int(roster.get(Balance.PION, 0)) - from_pawns
	roster[Balance.DAME] = int(roster.get(Balance.DAME, 0)) + count
	dames_made += count


func _take_losses(fight_losses: Dictionary) -> void:
	for type in fight_losses.keys():
		var count := int(fight_losses[type])

		# Une Dame FAITE pendant la serie qui tombe ne coute pas une Dame au
		# village - il n'y en avait aucune la-bas. Elle coute le PION qu'elle
		# etait : c'est ce pion qui manquera a la caserne.
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
func advance(reinforce_weight: int) -> Dictionary:
	fight += 1
	return _reinforce(reinforce_weight)


## Rend au roster, en piochant dans les pertes de la serie, jusqu'a epuiser le
## budget de poids. Les moins cheres d'abord : c'est la pietaille qu'on releve.
##
## Une piece relevee n'est plus une perte - elle ne sera donc pas retiree de
## l'armee du village a la fin de la serie.
func _reinforce(weight_budget: int) -> Dictionary:
	var recovered: Dictionary = {}
	var budget := weight_budget

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

	return recovered


func to_dict() -> Dictionary:
	return {
		"battle_id": battle_id,
		"fight": fight,
		"total": total,
		"roster": roster.duplicate(),
		"losses": losses.duplicate(),
		"reward": reward,
		"enemies_defeated": enemies_defeated,
		"promotions": promotions,
		"dames_made": dames_made,
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

	# Les cles reviennent du disque en String et les valeurs en float (JSON) :
	# on les repasse par des entiers, sinon un "3.0" se glisse dans un
	# compteur d'unites et le placement affiche des pieces a la virgule.
	for source in [["roster", data.get("roster", {})], ["losses", data.get("losses", {})]]:
		var target: Dictionary = {}
		var raw: Dictionary = source[1]
		for type in raw.keys():
			target[String(type)] = int(raw[type])
		run.set(String(source[0]), target)

	return run
