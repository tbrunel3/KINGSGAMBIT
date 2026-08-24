class_name Letters
##
## LES QUATRE MISSIVES DU ROI - leurs textes, et eux seuls.
##
## Le jeu ne dit jamais POURQUOI. Le joueur recoit une poignee de pieces et une
## bourse, et rien ne lui explique que c'est ce qui a survecu a l'enlevement
## plutot qu'un cadeau de depart. Le Roi parle une fois, sur son trone, puis
## disparait pour dix batailles. Ces lettres lui donnent une voix qui revient.
##
## ⚠️ CE FICHIER NE PORTE QUE DE LA PROSE. C'est voulu, et c'est la seule
## exception a "les textes vivent avec leur ecran" : ce sont les seuls textes du
## jeu que le joueur va relire et retoucher, et les lire ne doit pas demander de
## faire defiler du code de tween. Cf. chantier_i_missives.md.
##
## ⚠️ AUCUN CHIFFRE EN DUR DANS UN TEXTE. L'heritage s'interpole depuis
## Balance.STARTING_UNITS et Balance.STARTING_GOLD. Une transcription se decale
## des que le jeu bouge - c'est exactement ce qui a produit le codex faux, et ce
## que GuidePopup a deja verrouille.
##
## ⚠️ ELLES NE PARLENT JAMAIS DE REGLES. Le pat, la charge, l'aura, le temps
## reel : c'est GuidePopup, au moment ou la regle mord. Une lettre du Roi
## n'entre pas en combat.
##

const HERITAGE := "heritage"
const PREMIERE_DAME := "premiere_dame"
const PREMIERE_DEFAITE := "premiere_defaite"
const ELLE_EST_LA := "elle_est_la"

## Dans l'ordre de la campagne. Sert a la pile de courrier du Chateau Royal et
## a la recherche de la lettre due.
const ORDER := [HERITAGE, PREMIERE_DAME, PREMIERE_DEFAITE, ELLE_EST_LA]

## Celle qui S'IMPOSE. Les trois autres attendent au chateau - regle hybride
## tranchee par le joueur : la premiere doit etre vue, les suivantes se
## meritent.
const FORCED := [HERITAGE]


## Le titre grave sur le sceau, et le nom dans la pile de courrier.
static func title(key: String) -> String:
	match key:
		HERITAGE: return "Ce qu'il reste"
		PREMIERE_DAME: return "La couronne retrouvée"
		PREMIERE_DEFAITE: return "Après la chute"
		ELLE_EST_LA: return "La tour du Nord"
	return "Missive"


## Les trois blocs de la lettre, dans l'ordre du parchemin : l'adresse, le
## corps, la signature. Trois et non un seul texte qui coule - les deux
## plissures peintes dans l'illustration tomberaient en plein milieu des
## lignes (cf. chantier_i_missives.md, "Ce que les mesures imposent").
static func blocks(key: String) -> Array:
	match key:
		HERITAGE:
			return [
				"À qui relèvera mes couleurs,\ndepuis une salle du trône\nqu'il vaut mieux ne pas voir.",
				"On vous a remis %s, et %s pièces d'or.\n\nCe n'est pas une dotation. C'est l'inventaire. Le reste est tombé la nuit où on me l'a prise, et je n'ai pas eu le temps de compter.\n\nJe vous donne ce qui a survécu, et rien de plus, parce qu'il n'y a rien de plus."
					% [_inventory(), Balance.STARTING_GOLD],
				"Faites-en une armée.\nMoi, je ne peux plus que\nvous regarder faire.\n\n— Le Roi",
			]
		PREMIERE_DAME:
			return [
				"À vous, qui venez de faire\nce que je croyais fini.",
				"Un de vos fantassins a traversé le champ entier et porte la couronne. Je l'ai vu entrer. J'ai cru une seconde que c'était elle.\n\nCe n'en est pas une autre : c'est une DAME, la vôtre, et le trône est moins vide.\n\nElle vous attend au Château Royal — c'est là que les couronnes se reposent, et vous pouvez la reprendre quand vous voudrez.",
				"Gardez-la vivante.\nJ'en ai déjà perdu une.\n\n— Le Roi",
			]
		PREMIERE_DEFAITE:
			return [
				"À vous, ce soir,\net sans reproche.",
				"On m'a rapporté le champ. Je ne vous demande pas ce qui s'est passé.\n\nUne armée se refait : la caserne recrute, l'or rentre, et ce qui est tombé aujourd'hui se remplace. C'est la seule chose de ce royaume qui se remplace.\n\nElle, non. C'est pour ça que je vous écris plutôt que de vous compter les pertes.",
				"Reprenez la route quand\nvous serez prêt.\nMoi, j'attends.\n\n— Le Roi",
			]
		ELLE_EST_LA:
			return [
				"À vous, enfin,\net vite.",
				"Je sais où elle est. Un de mes derniers fidèles est revenu du Nord avec un nom, et je n'ai pas dormi depuis.\n\nElle est vivante. Elle est gardée. Ce que vous allez trouver là-bas ne ressemble à aucune des batailles d'avant, et je ne vous mentirai pas là-dessus.\n\nTout ce que vous avez levé depuis la première clairière, c'était pour cette porte.",
				"Ramenez-la.\nJe n'ai rien d'autre\nà vous demander.\n\n— Le Roi",
			]
	return []


## Ce que le joueur a recu au depart, en toutes lettres et depuis Balance :
## "quatre pions et un cavalier". Jamais transcrit - regler STARTING_UNITS doit
## reecrire la phrase.
static func _inventory() -> String:
	var parts: Array[String] = []
	for type in Balance.ARMY_TYPES:
		var count := int(Balance.STARTING_UNITS.get(type, 0))
		if count <= 0:
			continue
		var name := String(Balance.unit_name(type)).to_lower()
		parts.append("%s %s%s" % [_spelled(count), name, "s" if count > 1 else ""])
	if parts.is_empty():
		return "rien"
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " et " + parts[-1]


## Les petits nombres en toutes lettres : "quatre pions" et non "4 pions". Un
## chiffre au milieu d'une lettre manuscrite casse la voix. Au-dela de douze on
## rend le chiffre - aucune composition de depart n'ira jamais si haut, et une
## table interminable serait pire que le repli.
static func _spelled(n: int) -> String:
	const MOTS := ["zéro", "un", "deux", "trois", "quatre", "cinq", "six",
		"sept", "huit", "neuf", "dix", "onze", "douze"]
	return MOTS[n] if n >= 0 and n < MOTS.size() else str(n)


## La lettre dont le jalon est atteint, ou "" s'il n'y en a aucune.
##
## ⚠️ UN SEUL ENDROIT LIT LES QUATRE CONDITIONS, et c'est ce qui garantit
## qu'une lettre ne peut pas arriver au mauvais moment - par-dessus un ecran de
## defaite, ou en pleine serie. Aucun appel a disseminer dans battle_result,
## campaign_run ou castle_screen.
static func due() -> String:
	for key in ORDER:
		if Game.letter_received(key):
			continue
		if _milestone_reached(key):
			return key
	return ""


static func _milestone_reached(key: String) -> bool:
	match key:
		HERITAGE:
			return Game.has_seen_intro()
		PREMIERE_DAME:
			return Game.units_owned(Balance.DAME) >= 1
		PREMIERE_DEFAITE:
			return Game.defeats() >= 1
		ELLE_EST_LA:
			return Game.unlocked_battle() >= Balance.battle_count()
	return false


## Celle-ci s'impose au joueur ; les autres l'attendent au Chateau Royal.
static func is_forced(key: String) -> bool:
	return FORCED.has(key)
