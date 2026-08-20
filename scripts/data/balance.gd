extends Node
##
## ===========================================================================
##  BALANCE - toutes les valeurs d'equilibrage de King's Gambit sont ICI.
##
##  Regle du projet : aucune valeur de gameplay ne doit etre ecrite ailleurs.
##  Pour regler le jeu, ce fichier suffit - pas besoin d'ouvrir l'editeur.
## ===========================================================================
##
##  MODELE DE COMBAT
##
##  Pas de points de vie, pas de degats. Une piece est sur le plateau, ou
##  capturee. On capture en se DEPLACANT sur la case adverse, comme aux echecs.
##  Aucune attaque a distance.
##
##  Le niveau d'un batiment augmente la MOBILITE de ses pieces et la capacite
##  de la caserne. L'ecart est volontairement enorme entre le niveau 1 et le
##  niveau 10 : une tour niveau 1 avance de 2 cases, une tour niveau 10 en
##  traverse 8.
##
##  Le pion se deplace tout droit, capture en diagonale avant, et PROMEUT en
##  Dame s'il atteint le fond du plateau adverse.
##

# ------------------------------- TYPES D'UNITES ------------------------------

const PION := "pion"
const CAVALIER := "cavalier"
const FOU := "fou"
const TOUR := "tour"
const DAME := "dame"
const CASTLE := "chateau"

## Pieces recrutables, dans l'ordre d'affichage du village et du placement.
## La Dame n'y figure pas : elle ne s'achete pas, elle se gagne par promotion.
const UNIT_TYPES := [PION, CAVALIER, FOU, TOUR]

## Pieces qui composent l'armee du joueur, donc deployables en bataille. La
## Dame s'y ajoute : une fois promue ET ramenee vivante du champ de bataille,
## elle est stockee a la Tour de la Dame (village) et se redeploie ensuite
## comme n'importe quelle autre piece. C'est cette liste, et non UNIT_TYPES,
## qu'il faut parcourir des qu'on parle de l'ARMEE plutot que des CASERNES.
const ARMY_TYPES := [PION, CAVALIER, FOU, TOUR, DAME]

# ------------------------------- DEMARRAGE -----------------------------------

const STARTING_GOLD := 300
## Seul le pion est disponible au tout debut : les autres casernes sont a
## debloquer au village (voir UNLOCK_COST). Ca donne un premier combat lisible,
## et ca correspond a la seule composition qui gagne la bataille 1. 6 pions
## remplissent exactement les emplacements de deploiement du chateau niveau 1.
const STARTING_UNITS := {PION: 6}

## Batiments deja construits au demarrage. Le chateau et la caserne des pions
## sont toujours presents ; les autres apparaissent au niveau de chateau
## indique dans UNLOCK_CASTLE_LEVEL.
const STARTING_BUILDINGS := [CASTLE, PION]

## Niveau de chateau a partir duquel ce batiment apparait, gratuitement, au
## village. Absent de ce dictionnaire = deja disponible au depart.
const UNLOCK_CASTLE_LEVEL := {
	CAVALIER: 2,
	FOU: 3,
	TOUR: 4,
}

const MAX_LEVEL := 10
## Rangees de deploiement de chaque cote. A 2 plutot que 3 depuis que le
## joueur joue lui-meme chaque coup : une armee etalee sur trois rangees d'un
## plateau reduit se marche dessus et allonge le combat pour rien.
const DEPLOY_ROWS := 2

## Les pieces capturees en bataille sont DEFINITIVEMENT perdues : il faut les
## recruter a nouveau. Sans filet, une armee balayee sans or restant rend la
## partie injouable.
##
## GARNISON MINIMALE : apres chaque bataille, l'armee est completee gratuitement
## jusqu'a ce plancher. Le joueur garde donc toujours de quoi rejouer une
## bataille deja gagnee pour refaire de l'or. Les pertes restent definitives
## au-dessus du plancher, la ou se joue la vraie gestion.
const GARRISON_MINIMUM := {PION: 3}

## AURA DE LA DAME - ce que rapporte une Dame RESTEE AU VILLAGE.
##
## Le Roi a perdu sa Dame : toute la campagne consiste a la retrouver. Une
## Dame rangee a la Tour de la Dame tient la cour pendant que le Roi se bat,
## et chaque bataille rapporte cette fraction d'or en plus.
##
## Le bonus se compte par Dame AU REPOS : deployer une Dame, c'est renoncer a
## sa part pour la bataille en cours, pas au bonus des autres. C'est tout le
## choix du placement - une piece de plus sur le plateau, ou l'or qu'elle
## rapporte en restant a la maison.
##
## Exprime en fraction de la recompense plutot qu'en or fixe : +13 or sur la
## premiere bataille, +135 sur la derniere. Le bonus reste interessant du
## debut a la fin de la campagne.
const DAME_GOLD_BONUS := 0.15

## Nombre de Dames a posseder pour ameliorer la Tour de la Dame jusqu'a chaque
## niveau (indice 0 = passage au niveau 2). L'amelioration se paie en or comme
## partout ailleurs, mais elle demande EN PLUS d'avoir la collection : c'est ce
## que veut dire "cumuler des Dames permet de les ameliorer". Les Dames ne sont
## jamais consommees - une piece durement gagnee ne se sacrifie pas.
const DAME_UPGRADE_DAMES := [2, 3, 4, 5, 6, 7, 8, 9, 10]

## Une bataille deja gagnee rapporte moins : on peut farmer, mais progresser
## reste plus rentable que repasser sur un terrain conquis.
const REPLAY_REWARD_RATIO := 0.4

## Recompense de consolation en cas de defaite - cf. capture Figma 07
## (Consolation-Row), qui recompense un peu meme l'echec plutot que de
## repartir les mains vides.
const DEFEAT_CONSOLATION_RATIO := 0.1

# ------------------------------- UNITES --------------------------------------
#
#  Chaque tableau est indexe par (niveau - 1) et compte MAX_LEVEL entrees.
#  upgrade_cost et upgrade_seconds en comptent une de moins : il y a 9 paliers
#  d'amelioration pour 10 niveaux.
#
#  move_type :
#    "forward"    - avance tout droit, capture en diagonale avant (pion)
#    "jump"       - saute, ignore les pieces intermediaires (cavalier)
#    "diagonal"   - diagonales, bloque par les pieces (fou)
#    "orthogonal" - lignes et colonnes, bloque par les pieces (tour)
#    "queen"      - lignes, colonnes ET diagonales (dame, par promotion)
#
#  value sert a l'IA pour choisir quelle piece capturer en priorite. Memes
#  proportions qu'aux echecs.

const UNITS := {
	PION: {
		"name": "Pion",
		"building_name": "Caserne des Pions",
		"letter": "P",
		"color": "4f86c6",
		"move_type": "forward",
		"value": 1,
		"recruit_cost_base": 35,
		"recruit_cost_step": 8,  # cout = base + step * (nb deja possede)
		#
		# Le pion progresse d'abord sur son OUVERTURE, comme aux echecs : au
		# niveau 1 il avance d'une case et rien d'autre, au niveau 2 il gagne
		# le double pas du premier coup. Sa portee ordinaire, elle, ne monte
		# que tres tard - un pion qui avance de deux cases a chaque tour n'est
		# plus un pion.
		#            Nv  1  2  3  4  5  6  7  8  9 10
		"move_range": [ 1, 1, 1, 1, 1, 1, 2, 2, 2, 2],
		# Portee du TOUT PREMIER coup de la piece (cf. MovementRules._pawn).
		# Ne s'applique qu'une fois, et ne permet toujours pas de sauter
		# par-dessus quoi que ce soit.
		"first_move_range":
		              [ 1, 2, 2, 2, 3, 3, 3, 4, 4, 4],
		"capacity":   [ 8,10,12,14,16,18,20,22,24,26],
		"upgrade_cost":    [150, 300,  500,  750, 1050, 1400, 1800, 2250, 2750],
		"upgrade_seconds": [ 30,  90,  240,  600, 1200, 2400, 4200, 7200,10800],
	},
	CAVALIER: {
		"name": "Cavalier",
		"building_name": "Ecuries",
		"letter": "C",
		"color": "c96f4f",
		"move_type": "jump",
		"value": 3,
		"recruit_cost_base": 90,
		"recruit_cost_step": 18,
		# Le cavalier ne gagne pas en portee mais en FIGURES de saut : chaque
		# palier ouvre de nouveaux angles, symetrises dans les 8 sens.
		"jump_offsets": [
			[[1, 1]],                                                    # Nv.1  petit saut
			[[1, 2]],                                                    # Nv.2  le L classique
			[[1, 1], [1, 2]],                                            # Nv.3
			[[1, 1], [1, 2]],                                            # Nv.4
			[[1, 1], [1, 2], [1, 3]],                                    # Nv.5
			[[1, 1], [1, 2], [1, 3]],                                    # Nv.6
			[[1, 1], [1, 2], [1, 3], [2, 3]],                            # Nv.7
			[[1, 1], [1, 2], [1, 3], [2, 3], [1, 4]],                    # Nv.8
			[[1, 1], [1, 2], [1, 3], [2, 3], [1, 4], [2, 4]],            # Nv.9
			[[1, 1], [1, 2], [1, 3], [2, 3], [1, 4], [2, 4], [3, 4]],    # Nv.10
		],
		"capacity":   [ 4, 5, 6, 7, 8, 9,10,11,12,13],
		"upgrade_cost":    [220, 420,  680, 1000, 1380, 1820, 2320, 2880, 3500],
		"upgrade_seconds": [ 60, 180,  420,  900, 1800, 3300, 5400, 8400,12600],
	},
	FOU: {
		"name": "Fou",
		"building_name": "Cloitre",
		"letter": "F",
		"color": "8f6fc6",
		"move_type": "diagonal",
		"value": 3,
		"recruit_cost_base": 80,
		"recruit_cost_step": 15,
		#            Nv  1  2  3  4  5  6  7  8  9 10
		"move_range": [ 2, 2, 2, 3, 3, 4, 5, 6, 7, 8],
		"capacity":   [ 4, 5, 6, 7, 8, 9,10,11,12,13],
		"upgrade_cost":    [200, 390,  630,  930, 1290, 1710, 2190, 2730, 3330],
		"upgrade_seconds": [ 60, 180,  420,  900, 1800, 3300, 5400, 8400,12600],
	},
	TOUR: {
		"name": "Tour",
		"building_name": "Donjon",
		"letter": "T",
		"color": "6f9f5f",
		"move_type": "orthogonal",
		"value": 5,
		"recruit_cost_base": 110,
		"recruit_cost_step": 22,
		#            Nv  1  2  3  4  5  6  7  8  9 10
		"move_range": [ 2, 2, 2, 3, 3, 4, 5, 6, 7, 8],
		"capacity":   [ 3, 4, 5, 6, 7, 8, 9,10,11,12],
		"upgrade_cost":    [260, 500,  800, 1160, 1580, 2060, 2600, 3200, 3860],
		"upgrade_seconds": [ 90, 240,  540, 1080, 2100, 3900, 6300, 9600,14400],
	},
	DAME: {
		"name": "Dame",
		"building_name": "Tour de la Dame",
		"letter": "D",
		"color": "d8a0d0",
		"move_type": "queen",
		"value": 9,
		"recruit_cost_base": 0,
		"recruit_cost_step": 0,
		# Un pion promu devient une Dame du meme niveau que lui.
		#            Nv  1  2  3  4  5  6  7  8  9 10
		"move_range": [ 2, 2, 3, 3, 4, 5, 6, 7, 8, 9],
		# Sa valeur (9) sert a l'IA, qui doit la traiter comme la piece la plus
		# chere du plateau. Son POIDS de deploiement, lui, est celui d'une
		# Tour : au chateau Nv.1 (16 de charge), 9 aurait mange plus de la
		# moitie du budget et rendu son unique recompense impossible a jouer.
		"deploy_weight": 5,
		# La Tour de la Dame ne recrute pas - une Dame ne s'achete pas - mais
		# elle s'ameliore, a condition d'avoir la collection qui va avec
		# (cf. DAME_UPGRADE_DAMES). Capacite volontairement large : perdre une
		# Dame durement promue parce que le batiment est plein serait la pire
		# des punitions.
		"capacity":   [10,10,10,10,10,10,10,10,10,10],
		# Plus cher que le Donjon : c'est la piece la plus forte du jeu, et
		# chaque palier demande deja une Dame de plus en reserve.
		"upgrade_cost":    [300, 560,  900, 1300, 1760, 2280, 2860, 3500, 4200],
		"upgrade_seconds": [120, 300,  660, 1320, 2400, 4200, 6600, 9900,14400],
	},
}

# ------------------------------- CHATEAU -------------------------------------
#
#  Le Roi n'est pas jouable au MVP. Le chateau porte la narration et fixe la
#  capacite de deploiement en bataille (un budget de poids, pas un nombre de
#  pieces - voir CASTLE_DATA.deploy_capacity juste en dessous).

## deploy_capacity est un budget de POIDS, pas un nombre de pieces : chaque
## piece coute son Balance.deploy_weight() en capacite (le "sac a dos" du
## placement). Une
## armee de pions (poids 1) remplit donc le chateau a l'unite pres, mais une
## Dame (poids 9) coute autant de place que 9 pions - c'est voulu, une armee
## de pieces fortes doit rester plus petite qu'un mur de pions.
##
## Valeurs calculees, pas choisies au hasard : chaque budget est le poids
## EXACT de la formation que produisait l'ancien systeme a effectif fixe
## (l'ancien tableau, en tetes) avec l'alternance Pion/Cavalier/Fou/Tour de
## _on_auto_place (poids 1/3/3/5). L'armee par defaut - celle que pose le
## bouton AUTO et que jouent les tests - est donc EXACTEMENT inchangee ;
## seule une armee deliberement chargee en pieces fortes est desormais plus
## petite. Verifie par tools/smoke_test.gd (10/10 batailles gagnables) :
## revalider avec cet outil avant de retoucher ces chiffres.
##                    Nv   1   2   3   4   5   6   7   8   9  10
const CASTLE_DATA := {
	"name": "Chateau Royal",
	"letter": "R",
	"color": "c6a84f",
	"deploy_capacity": [ 16, 24, 25, 28, 36, 37, 40, 43, 48, 52],
	"upgrade_cost":     [300, 560,  900, 1320, 1820, 2400, 3060, 3800, 4620],
	"upgrade_seconds":  [120, 300,  660, 1320, 2400, 4200, 6600, 9900,14400],
}

# ------------------------------- NIVEAU DE JEU DE L'IA -----------------------
#
#  Le joueur joue desormais chaque coup lui-meme : une IA qui joue parfaitement
#  des la premiere bataille ne laisse aucune place a l'apprentissage. Chaque
#  bataille declare donc le niveau de jeu de l'ARMEE ENNEMIE.
#
#  Ces niveaux ne changent RIEN aux regles : ils retirent des precautions a
#  l'IA, ils ne lui donnent aucun privilege. Le camp du joueur, quand il est
#  confie au bouton AUTO, joue toujours au niveau maximum.
#
#    NOVICE   fonce. Prend tout ce qui passe, meme quand la prise lui coute
#             plus cher que ce qu'elle rapporte, et avance sans regarder si
#             la case est couverte. Se fait punir par un joueur attentif.
#    AGUERRI  compte ses echanges et prefere les cases sures, mais ne sauve
#             pas une piece deja attaquee : elle attend le coup.
#    EXPERT   joue tout : echanges, fuite des pieces menacees, pions pousses
#             uniquement la ou un allie peut reprendre.

const AI_NOVICE := 0
const AI_AGUERRI := 1
const AI_EXPERT := 2

# ------------------------------- CAMPAGNE ------------------------------------
#
#  10 batailles de test, difficulte croissante.
#  cols/rows : taille de la grille. rows vaut au moins 2 * DEPLOY_ROWS + 1.
#  ai        : niveau de jeu de l'armee ennemie (cf. AI_NOVICE juste au-dessus).
#
#  Plateaux VOLONTAIREMENT PETITS (5x7 a 8x9) : depuis que le joueur joue
#  chaque coup lui-meme, chaque case en plus est un tour de trajet en plus
#  avant le contact. Une case doit aussi rester assez grande pour un doigt -
#  sur les 360 points de large de la vue, 5 colonnes font 72 points de cote,
#  8 colonnes encore 45.
#  enemies   : composition ennemie {type: quantite}
#  level     : niveau de TOUTES les pieces ennemies de cette bataille

const CAMPAIGN := [
	{"id": 1,  "name": "L Oree du Bois",     "cols": 5, "rows": 7, "reward": 90,  "level": 1, "ai": AI_NOVICE, "enemies": {PION: 3}},
	{"id": 2,  "name": "Le Gue de Pierre",   "cols": 5, "rows": 7, "reward": 120, "level": 1, "ai": AI_NOVICE, "enemies": {PION: 2, FOU: 1}},
	{"id": 3,  "name": "La Route du Sel",    "cols": 6, "rows": 7, "reward": 160, "level": 2, "ai": AI_NOVICE, "enemies": {PION: 3, CAVALIER: 1, TOUR: 1}},
	{"id": 4,  "name": "Les Champs Brules",  "cols": 6, "rows": 7, "reward": 200, "level": 2, "ai": AI_AGUERRI, "enemies": {PION: 3, FOU: 1, CAVALIER: 1}},
	{"id": 5,  "name": "Le Pont Noir",       "cols": 6, "rows": 8, "reward": 260, "level": 3, "ai": AI_AGUERRI, "enemies": {PION: 4, TOUR: 1, FOU: 1}},
	{"id": 6,  "name": "La Carriere",        "cols": 6, "rows": 8, "reward": 320, "level": 3, "ai": AI_AGUERRI, "enemies": {PION: 4, CAVALIER: 1, TOUR: 1}},
	{"id": 7,  "name": "Les Marches Grises", "cols": 7, "rows": 8, "reward": 400, "level": 4, "ai": AI_AGUERRI, "enemies": {PION: 4, FOU: 1, CAVALIER: 1}},
	{"id": 8,  "name": "Le Col du Corbeau",  "cols": 7, "rows": 8, "reward": 500, "level": 4, "ai": AI_EXPERT, "enemies": {PION: 5, TOUR: 2, CAVALIER: 1}},
	{"id": 9,  "name": "Les Ruines Hautes",  "cols": 7, "rows": 9, "reward": 640, "level": 5, "ai": AI_EXPERT, "enemies": {PION: 5, FOU: 2, TOUR: 1, CAVALIER: 1}},
	{"id": 10, "name": "La Tour de la Dame", "cols": 8, "rows": 9, "reward": 900, "level": 6, "ai": AI_EXPERT, "enemies": {PION: 6, FOU: 2, TOUR: 2, CAVALIER: 1}},
]

# ------------------------------- COMBAT --------------------------------------
#
#  Le combat se joue au tour par tour : le joueur deplace UNE piece, l'IA
#  repond avec UNE piece, et ainsi de suite. Les durees ci-dessous ne
#  concernent que l'affichage - elles ne changent jamais l'issue d'un coup.

const COMBAT := {
	"step_delay": 0.30,        # pause entre deux activations en resolution auto
	"move_duration": 0.22,     # duree de l'animation de deplacement
	"capture_duration": 0.18,  # temps ou la piece capturee reste visible
	"promotion_duration": 0.45,  # temps d'affichage du badge de promotion
	# Temps de "reflexion" affiche avant que l'IA joue son coup, en mode
	# manuel. Purement cosmetique : sans lui, la reponse adverse est si
	# instantanee qu'on ne voit pas quelle piece a bouge.
	"ai_think_delay": 0.45,
	# Enlisement : nombre de TOURS COMPLETS sans la moindre prise avant de
	# trancher aux pieces restantes. Compte en tours et non en activations,
	# sinon une grande armee declencherait le verdict avant meme le contact.
	# Plus genereux qu'en resolution automatique : un joueur humain a le droit
	# de manoeuvrer longuement sans prendre la moindre piece.
	"stalemate_rounds": 8,
	"stalemate_rounds_manual": 20,
	# Chrono de blocage de la resolution AUTOMATIQUE uniquement : quelle que
	# soit la taille de l'armee, 30 secondes reelles (a vitesse x1) sans la
	# moindre prise suffisent a trancher. Ce plafond n'a aucun sens quand
	# c'est un humain qui joue - il reflechit - donc il ne s'applique pas en
	# mode manuel (cf. BattleEngine.auto_mode).
	"stalemate_seconds_cap": 30,
	"max_activations": 1200,   # garde-fou absolu
}

const SPEEDS := [1.0, 2.0, 4.0]

# ------------------------------- ACCESSEURS ----------------------------------
#
#  Passer par ces fonctions plutot que de lire les dictionnaires directement :
#  les niveaux y sont bornes une seule fois, au meme endroit.

func unit_data(type: String) -> Dictionary:
	return UNITS.get(type, {})


func unit_name(type: String) -> String:
	if type == CASTLE:
		return CASTLE_DATA["name"]
	return UNITS[type]["name"]


func building_name(type: String) -> String:
	if type == CASTLE:
		return CASTLE_DATA["name"]
	return UNITS[type]["building_name"]


func unit_color(type: String) -> Color:
	if type == CASTLE:
		return Color(CASTLE_DATA["color"])
	return Color(UNITS[type]["color"])


func unit_letter(type: String) -> String:
	if type == CASTLE:
		return CASTLE_DATA["letter"]
	return UNITS[type]["letter"]


func move_type(type: String) -> String:
	return String(UNITS[type]["move_type"])


## Valeur d'une piece pour l'IA : elle capture en priorite la plus chere et
## refuse les echanges perdants (cf. BattleAI). Ne PAS s'en servir comme cout
## de placement - c'est deploy_weight() qui le donne.
func unit_value(type: String) -> int:
	return int(UNITS[type].get("value", 1))


## Cout d'une piece dans le sac a dos du placement (cf.
## CASTLE_DATA.deploy_capacity) : une piece plus forte prend plus de place.
##
## Par defaut c'est sa valeur, ce qui garde le barème d'origine intact
## (Pion 1, Cavalier 3, Fou 3, Tour 5) ; seule la Dame declare un poids a
## part, moins lourd que sa valeur ne le laisserait croire.
func deploy_weight(type: String) -> int:
	return int(UNITS[type].get("deploy_weight", unit_value(type)))


## Lecture d'un tableau indexe par niveau, avec bornage.
func _at_level(values: Array, level: int) -> Variant:
	if values.is_empty():
		return null
	return values[clampi(level - 1, 0, values.size() - 1)]


func move_range(type: String, level: int) -> int:
	var value: Variant = _at_level(UNITS[type].get("move_range", []), level)
	return 0 if value == null else int(value)


## Portee du tout premier coup de la piece. Vaut sa portee ordinaire si le
## type n'a pas d'ouverture particuliere : seul le pion en a une aujourd'hui.
func first_move_range(type: String, level: int) -> int:
	var value: Variant = _at_level(UNITS[type].get("first_move_range", []), level)
	return move_range(type, level) if value == null else int(value)


## Dames a posseder pour ameliorer la Tour de la Dame depuis ce niveau.
## 0 quand le batiment est deja au maximum.
func dames_required(current_level: int) -> int:
	if current_level < 1 or current_level - 1 >= DAME_UPGRADE_DAMES.size():
		return 0
	return int(DAME_UPGRADE_DAMES[current_level - 1])


func jump_offsets(type: String, level: int) -> Array:
	var value: Variant = _at_level(UNITS[type].get("jump_offsets", []), level)
	return [] if value == null else value


## Description lisible du deplacement, affichee dans le popup de batiment.
func move_description(type: String, level: int) -> String:
	match move_type(type):
		"orthogonal":
			return "lignes et colonnes, %d cases" % move_range(type, level)
		"diagonal":
			return "diagonales, %d cases" % move_range(type, level)
		"queen":
			return "toutes directions, %d cases" % move_range(type, level)
		"jump":
			return "saut, %d figures" % jump_offsets(type, level).size()
		_:
			var reach := move_range(type, level)
			var opening := first_move_range(type, level)
			if opening > reach:
				return "en avant %d case(s), %d au premier coup, capture en diagonale" % [
					reach, opening]
			return "en avant %d case(s), capture en diagonale" % reach


## Vrai si ce batiment n'existe pas au depart et apparait plus tard.
func is_unlockable(type: String) -> bool:
	return UNLOCK_CASTLE_LEVEL.has(type)


## Niveau de chateau requis pour que ce batiment apparaisse. 1 si deja present
## au depart (chateau, pion).
func unlock_castle_level(type: String) -> int:
	return int(UNLOCK_CASTLE_LEVEL.get(type, 1))


## Cout du prochain recrutement : augmente avec le nombre deja possede.
func recruit_cost(type: String, owned: int) -> int:
	var d: Dictionary = UNITS[type]
	return int(d["recruit_cost_base"]) + int(d["recruit_cost_step"]) * owned


## Nombre maximum de pieces de ce type que le batiment peut abriter.
func capacity(type: String, level: int) -> int:
	return int(_at_level(UNITS[type]["capacity"], level))


func max_level(type: String) -> int:
	if type == CASTLE:
		return CASTLE_DATA["deploy_capacity"].size()
	return UNITS[type]["capacity"].size()


## Cout de l'amelioration depuis le niveau courant. -1 si deja au maximum.
func upgrade_cost(type: String, current_level: int) -> int:
	var costs: Array = CASTLE_DATA["upgrade_cost"] if type == CASTLE else UNITS[type]["upgrade_cost"]
	if current_level - 1 >= costs.size() or current_level < 1:
		return -1
	return int(costs[current_level - 1])


## Duree de l'amelioration en secondes. -1 si deja au maximum.
func upgrade_seconds(type: String, current_level: int) -> int:
	var times: Array = CASTLE_DATA["upgrade_seconds"] if type == CASTLE else UNITS[type]["upgrade_seconds"]
	if current_level - 1 >= times.size() or current_level < 1:
		return -1
	return int(times[current_level - 1])


## Capacite de deploiement en bataille (poids total des pieces posables),
## fixee par le niveau du chateau. Voir CASTLE_DATA.deploy_capacity.
func deploy_capacity(castle_level: int) -> int:
	return int(_at_level(CASTLE_DATA["deploy_capacity"], castle_level))


## Donnees d'une bataille par son numero (1 = premiere bataille).
func battle(id: int) -> Dictionary:
	for b in CAMPAIGN:
		if int(b["id"]) == id:
			return b
	return {}


## Niveau de jeu de l'armee ennemie pour cette bataille. Une bataille qui ne
## le declare pas joue au maximum : mieux vaut une IA trop forte qu'une IA
## distraite par oubli.
func battle_ai_skill(battle: Dictionary) -> int:
	return int(battle.get("ai", AI_EXPERT))


func battle_count() -> int:
	return CAMPAIGN.size()
