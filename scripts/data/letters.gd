class_name Letters
##
## LES QUATRE MISSIVES DU ROI - chantier I, et RIEN D'AUTRE.
##
## Ce fichier ne porte que de la prose. Le dépli, le cachet, les tweens et le
## routage vivent dans scenes/story/royal_letter.gd.
##
## Pourquoi les textes ici, alors que le codex et les GuidePopup gardent les
## leurs avec leur écran : ce sont les seuls textes du jeu qui soient de la
## PROSE, et ceux que le joueur relira et retouchera le plus. Les lire ne doit
## pas demander de faire défiler du code d'animation.
##
## ⚠️ AUCUN CHIFFRE EN DUR DANS LE TEXTE. « quatre pions et un cavalier »
## s'interpole depuis Balance.STARTING_UNITS, la bourse depuis
## Balance.STARTING_GOLD. Une transcription se décale dès que le jeu bouge -
## c'est exactement ce qui a produit le codex faux, et ce que GuidePopup a
## déjà verrouillé.
##
## ⚠️ LA MAQUETTE ÉCRIVAIT UN AUTRE COMPTE. La frame lettre-roi-ouverte
## (510:7) dit « mon plus fidèle destrier ainsi que trois de mes gardes » et
## « ramenez-moi les quatre » : le jeu en donne QUATRE plus un, soit cinq. La
## règle du projet tranche - quand un libellé annonce autre chose que le code,
## c'est le libellé qu'on corrige. Le ton de la maquette est gardé mot pour
## mot ; ses chiffres sont recalculés.
##
## LA VOIX. Ces lettres portent le POURQUOI - le sens, l'enjeu, l'héritage - là
## où GuidePopup porte le COMMENT. Le Roi parle à la première personne, et il
## n'explique jamais une règle. Une missive qui expliquerait le pat serait
## fausse de ton.
##

const HERITAGE := "heritage"
const PREMIERE_DAME := "premiere_dame"
const PREMIERE_DEFAITE := "premiere_defaite"
const ELLE_EST_LA := "elle_est_la"

## L'ordre de la pile de courrier au Château Royal. C'est aussi l'ordre dans
## lequel elles peuvent arriver, mais rien ne l'impose : un joueur peut perdre
## avant de faire sa première Dame.
const ORDRE := [HERITAGE, PREMIERE_DAME, PREMIERE_DEFAITE, ELLE_EST_LA]

## Le nom de la lettre dans la pile. L'écran de lecture, lui, n'en montre
## aucun : la maquette ne pose que le parchemin et le texte.
const TITRES := {
	HERITAGE: "CE QUI RESTE",
	PREMIERE_DAME: "LA COURONNE",
	PREMIERE_DEFAITE: "APRÈS LE CHAMP",
	ELLE_EST_LA: "ELLE EST LÀ",
}


static func exists(key: String) -> bool:
	return TITRES.has(key)


static func title(key: String) -> String:
	return String(TITRES.get(key, ""))


## Le corps de la lettre, chiffres déjà interpolés.
##
## ⚠️ ELLES SONT COURTES, ET C'EST UNE CONTRAINTE DE L'IMAGE, pas un choix de
## style. Le parchemin fait 340 x 420 points et n'a AUCUN défilement : la zone
## de texte utile vaut 280 x 300, soit onze lignes de vingt points. La maquette
## écrit 185 caractères ; au-delà de 230 environ, le texte sort du cadre. Deux
## paragraphes, comme elle. RoyalLetter réduit la police en dernier recours -
## voir _ajuster_au_cadre - mais c'est un garde-fou, pas une permission.
static func body(key: String) -> String:
	match key:
		HERITAGE:
			# ⚠️ La troupe arrive APRÈS un deux-points, jamais en début de
			# phrase : elle est interpolée en minuscules (« quatre pions et un
			# cavalier »), et la capture a montré la faute — « c'est ce qui
			# reste. quatre pions ».
			return ("« Ce n'est pas un présent : c'est ce qui reste — %s. Les "
				+ "autres sont tombés cette nuit-là.\n\nLes %d pièces d'or du "
				+ "coffre étaient à elle. Levez une armée, et ramenez-%s-moi "
				+ "entiers. »") % [
					_troupe_de_depart(), Balance.STARTING_GOLD,
					_tous(_effectif_de_depart())]
		PREMIERE_DAME:
			return ("« Un de vos pions a traversé le champ entier, et il n'en "
				+ "est pas revenu pion. Je lui ai fait porter la couronne."
				+ "\n\nElle siège au Château Royal, à une place qui n'est pas "
				+ "la sienne. Ce n'est pas ma Dame. Mais le chemin se fait. »")
		PREMIERE_DEFAITE:
			return ("« On m'a rapporté le champ. Ne vous excusez pas : j'ai "
				+ "perdu davantage que vous, et je suis encore assis."
				+ "\n\nUne armée se reconstruit. La caserne est ouverte. "
				+ "Revenez quand vous aurez compté ce qui manque. »")
		ELLE_EST_LA:
			return ("« Je sais où ils la gardent. Une tour, tout au bout de la "
				+ "carte, et des gens qui savent déjà que vous venez."
				+ "\n\nJe ne vous demande plus de lever une armée : vous en "
				+ "avez une. Allez la chercher. »")
	return ""


# ------------------------------- INTERPOLATION -------------------------------

## « quatre pions et un cavalier », construit depuis Balance.STARTING_UNITS.
##
## Rien n'est écrit en dur, pas même le nombre de TYPES : si la dotation de
## départ gagne une tour, la phrase la mentionne toute seule.
static func _troupe_de_depart() -> String:
	var morceaux: Array[String] = []
	# On suit l'ordre de ARMY_TYPES plutôt que celui du dictionnaire : c'est
	# l'ordre de puissance du jeu, et il ne dépend pas de l'écriture du JSON.
	for type in Balance.ARMY_TYPES:
		if not Balance.STARTING_UNITS.has(type):
			continue
		var n := int(Balance.STARTING_UNITS[type])
		var nom := Balance.unit_name(type).to_lower()
		morceaux.append("%s %s%s" % [_en_lettres(n), nom, "s" if n > 1 else ""])
	if morceaux.is_empty():
		return "rien du tout"
	if morceaux.size() == 1:
		return morceaux[0]
	var dernier: String = morceaux.pop_back()
	return "%s et %s" % [", ".join(morceaux), dernier]


static func _effectif_de_depart() -> int:
	var total := 0
	for n in Balance.STARTING_UNITS.values():
		total += int(n)
	return total


## Le pronom qui reprend la troupe : « ramenez-LES-moi » au pluriel,
## « ramenez-LE-moi » si la dotation de depart tombait a une seule piece.
static func _tous(n: int) -> String:
	return "le" if n <= 1 else "les"


## Les petits nombres s'écrivent en toutes lettres dans une lettre manuscrite.
## Au-delà, on retombe sur le chiffre - mieux vaut un chiffre dans la prose
## qu'un nombre écrit faux.
const EN_LETTRES := [
	"zéro", "un", "deux", "trois", "quatre", "cinq", "six",
	"sept", "huit", "neuf", "dix", "onze", "douze",
]


static func _en_lettres(n: int) -> String:
	if n >= 0 and n < EN_LETTRES.size():
		return String(EN_LETTRES[n])
	return str(n)
