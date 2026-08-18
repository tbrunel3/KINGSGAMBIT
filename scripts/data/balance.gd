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
## La Dame n'y figure pas : elle n'existe que par promotion d'un pion.
const UNIT_TYPES := [PION, CAVALIER, FOU, TOUR]

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
const DEPLOY_ROWS := 3  ## rangees de deploiement de chaque cote

## Les pieces capturees en bataille sont DEFINITIVEMENT perdues : il faut les
## recruter a nouveau. Sans filet, une armee balayee sans or restant rend la
## partie injouable.
##
## GARNISON MINIMALE : apres chaque bataille, l'armee est completee gratuitement
## jusqu'a ce plancher. Le joueur garde donc toujours de quoi rejouer une
## bataille deja gagnee pour refaire de l'or. Les pertes restent definitives
## au-dessus du plancher, la ou se joue la vraie gestion.
const GARRISON_MINIMUM := {PION: 3}

## Une bataille deja gagnee rapporte moins : on peut farmer, mais progresser
## reste plus rentable que repasser sur un terrain conquis.
const REPLAY_REWARD_RATIO := 0.4

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
		#            Nv  1  2  3  4  5  6  7  8  9 10
		"move_range": [ 1, 1, 1, 1, 2, 2, 2, 3, 3, 4],
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
		"building_name": "Dame",
		"letter": "D",
		"color": "d8a0d0",
		"move_type": "queen",
		"value": 9,
		"recruit_cost_base": 0,
		"recruit_cost_step": 0,
		# Un pion promu devient une Dame du meme niveau que lui.
		#            Nv  1  2  3  4  5  6  7  8  9 10
		"move_range": [ 2, 2, 3, 3, 4, 5, 6, 7, 8, 9],
		"capacity":   [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		"upgrade_cost": [],
		"upgrade_seconds": [],
	},
}

# ------------------------------- CHATEAU -------------------------------------
#
#  Le Roi n'est pas jouable au MVP. Le chateau porte la narration et fixe le
#  nombre de pieces deployables en bataille.

const CASTLE_DATA := {
	"name": "Chateau Royal",
	"letter": "R",
	"color": "c6a84f",
	#                Nv  1  2  3  4  5  6  7  8  9 10
	"deploy_slots": [ 6, 8, 9,10,12,13,14,15,16,18],
	"upgrade_cost":    [300, 560,  900, 1320, 1820, 2400, 3060, 3800, 4620],
	"upgrade_seconds": [120, 300,  660, 1320, 2400, 4200, 6600, 9900,14400],
}

# ------------------------------- CAMPAGNE ------------------------------------
#
#  10 batailles de test, difficulte croissante.
#  cols/rows : taille de la grille. rows vaut au moins 2 * DEPLOY_ROWS + 1.
#  enemies   : composition ennemie {type: quantite}
#  level     : niveau de TOUTES les pieces ennemies de cette bataille

## Loterie de promotion : un pion qui atteint le fond adverse devient une
## piece aleatoire plutot que toujours une Dame. Un camp reduit a des pions
## immobilises ne se retrouve plus jamais fige : la promotion apporte de la
## mobilite neuve (cavalier, fou) ou, plus rarement, toute la puissance de
## la Dame.
const PROMOTION_TYPES := [CAVALIER, FOU, DAME]

## Poids [cavalier, fou, dame] par niveau du pion promu, indexes comme les
## autres tableaux (index 0 = niveau 1). N'ont pas besoin de sommer a 100 :
## ils sont normalises au tirage. La Dame reste rare aux bas niveaux et
## devient une vraie option en fin de partie.
const PROMOTION_WEIGHTS := [
	[45, 45, 10],   # Nv.1
	[45, 45, 10],   # Nv.2
	[43, 43, 14],   # Nv.3
	[41, 41, 18],   # Nv.4
	[39, 39, 22],   # Nv.5
	[37, 37, 26],   # Nv.6
	[35, 35, 30],   # Nv.7
	[33, 33, 34],   # Nv.8
	[31, 31, 38],   # Nv.9
	[29, 29, 42],   # Nv.10
]

const CAMPAIGN := [
	{"id": 1,  "name": "L Oree du Bois",     "cols": 6, "rows": 8,  "reward": 90,  "level": 1, "enemies": {PION: 3}},
	{"id": 2,  "name": "Le Gue de Pierre",   "cols": 6, "rows": 8,  "reward": 120, "level": 1, "enemies": {PION: 2, FOU: 1}},
	{"id": 3,  "name": "La Route du Sel",    "cols": 7, "rows": 9,  "reward": 160, "level": 2, "enemies": {PION: 4, CAVALIER: 1, TOUR: 1}},
	{"id": 4,  "name": "Les Champs Brules",  "cols": 7, "rows": 9,  "reward": 200, "level": 2, "enemies": {PION: 4, FOU: 1, CAVALIER: 1}},
	{"id": 5,  "name": "Le Pont Noir",       "cols": 7, "rows": 10, "reward": 260, "level": 3, "enemies": {PION: 4, TOUR: 1, FOU: 1}},
	{"id": 6,  "name": "La Carriere",        "cols": 8, "rows": 10, "reward": 320, "level": 3, "enemies": {PION: 5, CAVALIER: 1, TOUR: 1}},
	{"id": 7,  "name": "Les Marches Grises", "cols": 8, "rows": 11, "reward": 400, "level": 4, "enemies": {PION: 6, FOU: 1, CAVALIER: 1}},
	{"id": 8,  "name": "Le Col du Corbeau",  "cols": 8, "rows": 11, "reward": 500, "level": 4, "enemies": {PION: 6, TOUR: 3, CAVALIER: 2}},
	{"id": 9,  "name": "Les Ruines Hautes",  "cols": 9, "rows": 12, "reward": 640, "level": 5, "enemies": {PION: 6, FOU: 2, TOUR: 2, CAVALIER: 2}},
	{"id": 10, "name": "La Tour de la Dame", "cols": 9, "rows": 12, "reward": 900, "level": 6, "enemies": {PION: 6, FOU: 3, TOUR: 2, CAVALIER: 2}},
]

# ------------------------------- COMBAT --------------------------------------
#
#  Ces durees ne concernent QUE l'affichage. Le resultat d'un combat est
#  identique quelle que soit la vitesse choisie par le joueur.

const COMBAT := {
	"step_delay": 0.30,        # pause entre deux activations
	"move_duration": 0.22,     # duree de l'animation de deplacement
	"capture_duration": 0.18,  # temps ou la piece capturee reste visible
	"promotion_duration": 0.45,  # temps d'affichage du resultat de la loterie
	# Enlisement : nombre de TOURS COMPLETS sans la moindre prise avant de
	# trancher aux pieces restantes. Compte en tours et non en activations,
	# sinon une grande armee declencherait le verdict avant meme le contact.
	"stalemate_rounds": 8,
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


## Valeur d'une piece pour l'IA : elle capture en priorite la plus chere.
func unit_value(type: String) -> int:
	return int(UNITS[type].get("value", 1))


## Lecture d'un tableau indexe par niveau, avec bornage.
func _at_level(values: Array, level: int) -> Variant:
	if values.is_empty():
		return null
	return values[clampi(level - 1, 0, values.size() - 1)]


func move_range(type: String, level: int) -> int:
	var value: Variant = _at_level(UNITS[type].get("move_range", []), level)
	return 0 if value == null else int(value)


func jump_offsets(type: String, level: int) -> Array:
	var value: Variant = _at_level(UNITS[type].get("jump_offsets", []), level)
	return [] if value == null else value


func promotion_weights(level: int) -> Array:
	return _at_level(PROMOTION_WEIGHTS, level)


## Tire au sort le resultat de la promotion d'un pion de ce niveau.
func roll_promotion(level: int) -> String:
	var weights: Array = promotion_weights(level)
	var total := 0
	for w in weights:
		total += int(w)
	var roll := randi_range(1, total)
	var cumulative := 0
	for i in range(PROMOTION_TYPES.size()):
		cumulative += int(weights[i])
		if roll <= cumulative:
			return PROMOTION_TYPES[i]
	return PROMOTION_TYPES[PROMOTION_TYPES.size() - 1]


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
			return "en avant %d case(s), capture en diagonale" % move_range(type, level)


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
		return CASTLE_DATA["deploy_slots"].size()
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


## Nombre de pieces deployables en bataille, fixe par le niveau du chateau.
func deploy_slots(castle_level: int) -> int:
	return int(_at_level(CASTLE_DATA["deploy_slots"], castle_level))


## Donnees d'une bataille par son numero (1 = premiere bataille).
func battle(id: int) -> Dictionary:
	for b in CAMPAIGN:
		if int(b["id"]) == id:
			return b
	return {}


func battle_count() -> int:
	return CAMPAIGN.size()
