extends Node
##
## ===========================================================================
##  BALANCE - toutes les valeurs d'equilibrage de King's Gambit sont ICI.
##
##  Regle du projet : aucune valeur de gameplay ne doit etre ecrite ailleurs.
##  Pour regler le jeu, ce fichier suffit - pas besoin d'ouvrir l'editeur.
## ===========================================================================
##

# ------------------------------- TYPES D'UNITES ------------------------------

const PION := "pion"
const CAVALIER := "cavalier"
const FOU := "fou"
const TOUR := "tour"
const CASTLE := "chateau"

## Ordre d'affichage dans le village et dans le panneau de placement.
const UNIT_TYPES := [PION, CAVALIER, FOU, TOUR]

# ------------------------------- DEMARRAGE -----------------------------------

const STARTING_GOLD := 300
const STARTING_UNITS := {PION: 4, CAVALIER: 1, FOU: 1, TOUR: 1}

const MAX_LEVEL := 3
const DEPLOY_ROWS := 3  ## rangees de deploiement de chaque cote

# ------------------------------- UNITES --------------------------------------
#
#  levels[] est indexe par (niveau - 1). Ajouter un niveau = ajouter une entree
#  ici, plus une entree dans upgrade_cost / upgrade_seconds / capacity.
#
#  move_type :
#    "forward"    - avance surtout tout droit (pion)
#    "jump"       - saute, ignore les unites intermediaires (cavalier)
#    "diagonal"   - diagonales, bloque par les unites (fou)
#    "orthogonal" - lignes et colonnes, bloque par les unites (tour)
#
#  attack_range est mesure en distance de Tchebychev (le max des ecarts en
#  colonne et en rangee), sans ligne de vue. Choix MVP : simple a comprendre
#  et a debugger.

const UNITS := {
	PION: {
		"name": "Pion",
		"building_name": "Caserne des Pions",
		"letter": "P",
		"color": "4f86c6",
		"move_type": "forward",
		"recruit_cost_base": 35,
		"recruit_cost_step": 8,      # cout = base + step * (nb deja possede)
		"capacity": [8, 12, 18],     # nb max d'unites possedees, par niveau
		"upgrade_cost": [150, 420],  # niveau 1 vers 2, puis 2 vers 3
		"upgrade_seconds": [30, 180],
		"levels": [
			{"hp": 22, "damage": 6, "move_range": 1, "attack_range": 1},
			{"hp": 30, "damage": 8, "move_range": 2, "attack_range": 1},
			{"hp": 40, "damage": 11, "move_range": 2, "attack_range": 2},
		],
	},
	CAVALIER: {
		"name": "Cavalier",
		"building_name": "Ecuries",
		"letter": "C",
		"color": "c96f4f",
		"move_type": "jump",
		"recruit_cost_base": 90,
		"recruit_cost_step": 25,
		"capacity": [4, 6, 9],
		"upgrade_cost": [220, 600],
		"upgrade_seconds": [60, 300],
		"levels": [
			# jump_offsets : deplacements en L autorises (dx, dy), symetrises
			# automatiquement dans les 8 sens. Ignorent les unites du trajet.
			{"hp": 34, "damage": 11, "attack_range": 1, "jump_offsets": [[1, 2]]},
			{"hp": 44, "damage": 14, "attack_range": 1, "jump_offsets": [[1, 2], [1, 3]]},
			{"hp": 56, "damage": 18, "attack_range": 2, "jump_offsets": [[1, 2], [1, 3], [2, 3]]},
		],
	},
	FOU: {
		"name": "Fou",
		"building_name": "Cloitre",
		"letter": "F",
		"color": "8f6fc6",
		"move_type": "diagonal",
		"recruit_cost_base": 80,
		"recruit_cost_step": 20,
		"capacity": [4, 6, 9],
		"upgrade_cost": [200, 560],
		"upgrade_seconds": [60, 300],
		"levels": [
			{"hp": 26, "damage": 13, "move_range": 2, "attack_range": 2},
			{"hp": 34, "damage": 17, "move_range": 3, "attack_range": 2},
			{"hp": 44, "damage": 22, "move_range": 4, "attack_range": 3},
		],
	},
	TOUR: {
		"name": "Tour",
		"building_name": "Donjon",
		"letter": "T",
		"color": "6f9f5f",
		"move_type": "orthogonal",
		"recruit_cost_base": 110,
		"recruit_cost_step": 30,
		"capacity": [3, 5, 7],
		"upgrade_cost": [260, 700],
		"upgrade_seconds": [90, 420],
		"levels": [
			{"hp": 48, "damage": 12, "move_range": 2, "attack_range": 2},
			{"hp": 62, "damage": 16, "move_range": 3, "attack_range": 2},
			{"hp": 80, "damage": 21, "move_range": 4, "attack_range": 3},
		],
	},
}

# ------------------------------- CHATEAU -------------------------------------
#
#  Le Roi n'est pas jouable au MVP. Le chateau porte la narration et fixe le
#  nombre d'unites deployables en bataille.

const CASTLE_DATA := {
	"name": "Chateau Royal",
	"letter": "R",
	"color": "c6a84f",
	"deploy_slots": [6, 10, 14],
	"upgrade_cost": [300, 800],
	"upgrade_seconds": [120, 600],
}

# ------------------------------- CAMPAGNE ------------------------------------
#
#  10 batailles de test, difficulte croissante.
#  cols/rows : taille de la grille. rows vaut au moins 2 * DEPLOY_ROWS + 1.
#  enemies   : composition ennemie {type: quantite}
#  level     : niveau de TOUTES les unites ennemies de cette bataille

const CAMPAIGN := [
	{"id": 1,  "name": "L Oree du Bois",     "cols": 6, "rows": 8,  "reward": 90,  "level": 1, "enemies": {PION: 3}},
	{"id": 2,  "name": "Le Gue de Pierre",   "cols": 6, "rows": 8,  "reward": 120, "level": 1, "enemies": {PION: 4, FOU: 1}},
	{"id": 3,  "name": "La Route du Sel",    "cols": 7, "rows": 9,  "reward": 160, "level": 1, "enemies": {PION: 4, CAVALIER: 1, TOUR: 1}},
	{"id": 4,  "name": "Les Champs Brules",  "cols": 7, "rows": 9,  "reward": 200, "level": 1, "enemies": {PION: 5, FOU: 2, CAVALIER: 1}},
	{"id": 5,  "name": "Le Pont Noir",       "cols": 7, "rows": 10, "reward": 260, "level": 2, "enemies": {PION: 4, TOUR: 2, FOU: 1}},
	{"id": 6,  "name": "La Carriere",        "cols": 8, "rows": 10, "reward": 320, "level": 2, "enemies": {PION: 6, CAVALIER: 2, TOUR: 1}},
	{"id": 7,  "name": "Les Marches Grises", "cols": 8, "rows": 11, "reward": 400, "level": 2, "enemies": {PION: 5, FOU: 3, CAVALIER: 2}},
	{"id": 8,  "name": "Le Col du Corbeau",  "cols": 8, "rows": 11, "reward": 500, "level": 2, "enemies": {PION: 6, TOUR: 3, CAVALIER: 2}},
	{"id": 9,  "name": "Les Ruines Hautes",  "cols": 9, "rows": 12, "reward": 640, "level": 3, "enemies": {PION: 6, FOU: 2, TOUR: 2, CAVALIER: 2}},
	{"id": 10, "name": "La Tour de la Dame", "cols": 9, "rows": 12, "reward": 900, "level": 3, "enemies": {PION: 7, FOU: 3, TOUR: 2, CAVALIER: 2}},
]

# ------------------------------- COMBAT --------------------------------------
#
#  Ces durees ne concernent QUE l'affichage. Le resultat d'un combat est
#  identique quelle que soit la vitesse choisie par le joueur.

const COMBAT := {
	"step_delay": 0.30,        # pause entre deux activations
	"move_duration": 0.22,     # duree de l'animation de deplacement
	"attack_duration": 0.20,   # duree du flash d'attaque
	"stalemate_limit": 24,     # activations sans degats avant de trancher
	"max_activations": 400,    # garde-fou absolu
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


## Statistiques d'une unite d'un type et d'un niveau donnes.
func unit_stats(type: String, level: int) -> Dictionary:
	var levels: Array = UNITS[type]["levels"]
	var index := clampi(level - 1, 0, levels.size() - 1)
	return levels[index]


## Cout du prochain recrutement : augmente avec le nombre deja possede.
func recruit_cost(type: String, owned: int) -> int:
	var d: Dictionary = UNITS[type]
	return int(d["recruit_cost_base"]) + int(d["recruit_cost_step"]) * owned


## Nombre maximum d'unites de ce type que le batiment peut abriter.
func capacity(type: String, level: int) -> int:
	var caps: Array = UNITS[type]["capacity"]
	return int(caps[clampi(level - 1, 0, caps.size() - 1)])


func max_level(type: String) -> int:
	if type == CASTLE:
		return CASTLE_DATA["deploy_slots"].size()
	return UNITS[type]["levels"].size()


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


## Nombre d'unites deployables en bataille, fixe par le niveau du chateau.
func deploy_slots(castle_level: int) -> int:
	var slots: Array = CASTLE_DATA["deploy_slots"]
	return int(slots[clampi(castle_level - 1, 0, slots.size() - 1)])


## Donnees d'une bataille par son numero (1 = premiere bataille).
func battle(id: int) -> Dictionary:
	for b in CAMPAIGN:
		if int(b["id"]) == id:
			return b
	return {}


func battle_count() -> int:
	return CAMPAIGN.size()
