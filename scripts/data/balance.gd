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
## elle rejoint le Chateau Royal, aux cotes du Roi, et se redeploie ensuite
## comme n'importe quelle autre piece. C'est cette liste, et non UNIT_TYPES,
## qu'il faut parcourir des qu'on parle de l'ARMEE plutot que des CASERNES.
const ARMY_TYPES := [PION, CAVALIER, FOU, TOUR, DAME]

# ------------------------------- DEMARRAGE -----------------------------------

const STARTING_GOLD := 300

## L'armee du tout premier combat. Un cavalier accompagne les pions des le
## depart, et ce n'est pas un cadeau : une armee de pions seuls, c'est une
## finale de pions - la situation la plus subtile des echecs - servie en guise
## de tutoriel. Le cavalier saute, ne se bloque jamais, et apprend d'un coup
## d'oeil que toutes les pieces ne se deplacent pas pareil.
const STARTING_UNITS := {PION: 4, CAVALIER: 1}

## Batiments deja construits au demarrage. Les Ecuries en font partie, sans
## quoi le cavalier de depart n'aurait ni maison ni remplacant.
const STARTING_BUILDINGS := [CASTLE, PION, CAVALIER]

## Niveau de chateau a partir duquel ce batiment apparait, gratuitement, au
## village. Absent de ce dictionnaire = deja disponible au depart.

const UNLOCK_CASTLE_LEVEL := {
	FOU: 2,
	TOUR: 3,
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
## Dame restee au Chateau Royal tient la cour pendant que le Roi se bat,
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

## "Cumuler des Dames permet de les ameliorer" : le niveau d'une Dame est le
## plus petit du niveau du Chateau Royal et du NOMBRE de Dames abritees. Il
## faut donc les deux - un chateau qui monte, et une collection qui grandit -
## et aucune Dame n'est jamais depensee : c'est leur presence qui compte.
##
## Une Dame seule dans un chateau Nv.5 reste donc Nv.1 ; trois Dames dans un
## chateau Nv.3 sont toutes Nv.3.

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
		"building_name": "Écuries",
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
		"building_name": "Cloître des Fous",
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
		"building_name": "Donjon des Tours",
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
		# La Dame n'a pas de batiment a elle : elle vit au Chateau Royal, aux
		# cotes du Roi. C'est de la que vient toute l'histoire du jeu.
		"building_name": "Château Royal",
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
		# Nombre de Dames que le chateau peut abriter. Volontairement large :
		# perdre une Dame durement promue parce qu'il n'y a plus de place
		# serait la pire des punitions.
		"capacity":   [10,10,10,10,10,10,10,10,10,10],
		# Aucune amelioration propre : la Dame monte avec le Chateau Royal
		# (cf. GameState.dame_level).
		"upgrade_cost": [],
		"upgrade_seconds": [],
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
## la formation de reference (poids 1/3/3/5, cf. tools/battle_driver.gd).
## L'armee que jouent les bancs est donc EXACTEMENT inchangee ;
## seule une armee deliberement chargee en pieces fortes est desormais plus
## petite. Verifie par tools/smoke_test.gd (10/10 batailles gagnables) :
## revalider avec cet outil avant de retoucher ces chiffres.
##                    Nv   1   2   3   4   5   6   7   8   9  10
const CASTLE_DATA := {
	"name": "Château Royal",
	"letter": "R",
	"color": "c6a84f",
	"deploy_capacity": [ 16, 19, 21, 23, 26, 28, 30, 32, 34, 36],
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
#  l'IA, ils ne lui donnent aucun privilege. Ils ne valent que pour l'armee
#  ENNEMIE - le camp du joueur n'est jamais confie a personne.
#
#    NOVICE   ne regarde pas la reponse adverse. Elle prend ce qui passe et
#             se fait fourcher : la case ou elle pose sa tour est sure, elle
#             y va, et le cavalier prend au coup suivant. Reservee aux deux
#             premieres batailles - un joueur qui decouvre le jeu doit
#             pouvoir les gagner.
#    AGUERRI  voit la reponse immediate. Elle ne donne plus une piece.
#    EXPERT   voit sa replique : fourchettes, enfilades, echanges a trois
#             temps.
#
#  Ce ne sont plus trois jeux d'heuristiques mais trois PROFONDEURS de
#  recherche (cf. AI_DEPTH et BattleSearch). Le banc tools/ai_bench.tscn les
#  fait jouer l'une contre l'autre : chaque demi-coup supplementaire gagne les
#  six duels, dans les deux camps.

const AI_NOVICE := 0
const AI_AGUERRI := 1
const AI_EXPERT := 2

## PROFONDEUR DE RECHERCHE par niveau de jeu, en demi-coups (cf.
## BattleSearch). C'est la VRAIE echelle de difficulte du jeu.
##
## 1 = le camp joue son meilleur coup sans regarder la reponse : c'est
## l'ancienne IA, celle qui se fait fourcher. On la garde pour les premieres
## batailles - un debutant doit pouvoir gagner ses premiers combats.
## 2 = elle voit la reponse immediate. Elle ne donne plus une piece.
## 3 = elle voit sa replique, donc les fourchettes, les enfilades, et les
## echanges a trois temps.
##
## Chaque demi-coup en plus multiplie le travail : au-dela de 3, l'attente
## devient sensible au doigt sans que le jeu devienne plus interessant.
const AI_DEPTH := {
	AI_NOVICE: 1,
	AI_AGUERRI: 2,
	AI_EXPERT: 3,
}

## Temps de reflexion maximum accorde a la recherche, en millisecondes. La
## recherche s'arrete des qu'il est depasse et joue le meilleur coup de la
## derniere profondeur ACHEVEE : c'est ce qui garantit qu'une grande bataille
## ne fige jamais l'ecran, et qu'un plateau charge redescend proprement d'un
## demi-coup plutot que de faire attendre.
##
## 450 ms parce que ce temps est deja paye : en combat manuel, l'ecran marque
## une pause de `ai_think_delay` (450 ms) AVANT que l'ennemi joue, uniquement
## pour qu'on voie quelle piece bouge. Reflechir pendant ce temps-la ne coute
## rien de percu.
##
## Mesure (tools/ai_probe.tscn) sur la derniere bataille - 8x9, 14 pieces par
## camp, 30 coups legaux a l'ouverture :
##
##   profondeur 2 =    24 ms
##   profondeur 3 =   195 ms
##   profondeur 4 = 2 994 ms
##
## La quatrieme est hors de portee, et c'est pour ca que l'echelle s'arrete a
## trois.
##
## CE QUI FAIT BOUGER CE CHIFFRE, ecrit noir sur blanc parce que ca a deja
## coute : le cout d'un coup suit le nombre de COUPS LEGAUX, donc a la fois les
## effectifs et les PORTEES - c'est-a-dire le niveau des pieces.
##
##   11 pieces/camp au niveau 6 ... 37 coups ... 139 ms   (ancien reglage)
##   14 pieces/camp au niveau 5 ... 37 coups ... 396 ms   <- hors budget a 250
##   14 pieces/camp au niveau 4 ... 30 coups ... 195 ms   (reglage actuel)
##
## Au reglage du milieu, l'IA declaree EXPERTE retombait a la profondeur 2 sans
## que rien ne le dise, et a un endroit qui dependait de la machine. Toucher aux
## effectifs ENNEMIS ou a leur NIVEAU, c'est donc toucher au niveau de jeu reel
## de l'IA - relancer ai_probe apres, systematiquement.
##
## Le budget est reste a 450 alors que 250 suffirait aujourd'hui : c'est la
## marge pour un telephone deux fois plus lent que la machine de mesure.
##
## Sur un telephone lent, la coupure peut se produire malgre tout : l'IA
## redescend alors proprement d'un demi-coup, avec le meilleur coup de la
## derniere profondeur ACHEVEE. C'est une degradation, pas un bug - mais c'est
## aussi pourquoi les BANCS jouent sans limite de temps (cf. BattleAI.budget_ms).
const AI_BUDGET_MS := 450


## Profondeur de recherche de ce niveau de jeu.
func ai_depth(skill: int) -> int:
	return int(AI_DEPTH.get(skill, 1))

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
#  fights    : nombre de combats de la SERIE (cf. CampaignRun), sans retour au
#              village entre les deux.
#
#              C'EST LE BOUTON DE LA DUREE D'UNE SEANCE. Un combat joue a la
#              main prend cinq a dix minutes sur les grands plateaux : a cinq
#              combats, un niveau demandait quarante minutes d'affilee, sans
#              point de sauvegarde en cours de combat. Trop long pour un jeu
#              qu'on ouvre sur un telephone.
#
#              SEULE la premiere bataille se joue en UN combat - on y decouvre
#              le jeu - et la serie demarre des la deuxieme, jusqu'a trois a la
#              fin. Elle arrive tot parce que le DEUXIEME combat est le seul
#              endroit ou le joueur se retrouve derriere : l'ennemi revient au
#              complet, lui revient avec ses survivants. A 1, toute la
#              machinerie de serie devient invisible : le badge redit
#              PLACEMENT, la preparation annonce un seul combat, et la victoire
#              paie et debloque immediatement.
#
#  player    niveau auquel le JOUEUR est cense aborder la bataille, distinct de
#              `level` qui est celui des pieces ennemies (cf.
#              battle_player_level). Son avantage n'est plus fait de NOMBRE - il
#              l'etait, et une bataille gagnee d'avance ne se joue pas - mais de
#              QUALITE : moins de pieces, mieux equipees, face a un adversaire
#              plus nombreux et plus fruste.
#
#              L'ECART ENTRE LES DEUX SE REGLE BATAILLE PAR BATAILLE, et il n'y
#              a pas de bonne valeur unique. Mesure par tools/tune_probe.tscn,
#              cinq formations par configuration, armee variee :
#
#                bataille   ecart 0   ecart 1   ecart 2
#                    7        5/5       4/5       5/5
#                    8        4/5       5/5       5/5
#                    9        4/5       5/5       5/5
#                   10        3/5       3/5       4/5
#
#              Les batailles 7 a 9 passent partout : leur ecart declare vaut ce
#              qu'il vaut, inutile d'y toucher. La DIXIEME est la seule
#              exception - elle restait a 3/5 pour un joueur PARFAIT, et un
#              humain fait moins bien. Elle est donc la seule a creuser de deux
#              niveaux. Rappel du biais : la sonde joue les deux camps a la
#              recherche, ces taux sont des plafonds. C'est ce qui rend chaque perte
#              couteuse, et ce qui donne enfin un but aux niveaux de batiment.

## PROMOTION - part du materiel engage que l'adversaire doit encore avoir
## debout pour qu'un pion arrive au fond devienne une DAME.
##
## En dessous, la bataille est deja jouee : le pion promeut quand meme, mais
## en PROMOTION_FALLBACK, une piece intermediaire qui ne rejoint pas le
## Chateau Royal. Mesure avant la regle (tools/promo_probe.tscn) : sur douze
## promotions de campagne, six tombaient contre un adversaire sous un tiers de
## son materiel - la moitie des Dames du jeu etaient du ramassage.
##
## Regle a la moitie : une Dame doit etre une PERCEE dans une bataille encore
## indecise, pas la recompense d'un pion qui se promene une fois l'adversaire
## brise. C'est le seul bouton a tourner si les Dames redeviennent trop
## frequentes - ou trop rares.
const PROMOTION_CONTESTED_RATIO := 0.5
const PROMOTION_FALLBACK := CAVALIER

## LE SACRE ETAIT DIFFERE D'UN TOUR, ET IL NE L'EST PLUS.
##
## Un pion arrive au fond attendait le debut de son prochain tour pour recevoir
## la couronne, immobile et sans coup legal ; l'adversaire avait exactement un
## coup pour l'en empecher.
##
## MESURE AVANT DE RETIRER, sur les deux bancs, regle active puis retiree :
## promo_probe rend 4 promotions et 1 Dame dans les deux cas ; smoke_test rend
## 17 promotions sur ses 19 parties dans les deux cas. La regle ne coutait pas
## une seule Dame - son unique effet mesurable etait de decaler le sacre d'un
## tour.
##
## Ce qu'elle coutait, en revanche : elle contredit les echecs, ou la promotion
## est immediate ; elle ne laissait AUCUNE prise au joueur pendant ce tour ; et
## elle etait indevinable. Les trois autres freins (capture obligatoire,
## bataille encore disputee, une couronne par camp) gardent la Dame rare et se
## lisent, eux.

## UNE SEULE DAME PAR BATAILLE ET PAR CAMP. Les pions suivants montent en
## PROMOTION_FALLBACK. La sonde montrait des batailles a trois Dames : une
## percee est un evenement, pas une chaine de production.
const PROMOTION_ONE_PER_BATTLE := true

## LE PION DOIT AVOIR FAIT SES PREUVES : seul un pion qui a deja capture peut
## pretendre a la couronne. Un pion qui a traverse un couloir vide n'a rien
## prouve.
##
## CE FILTRE PESE AUTANT QUE LE RATIO, et ce n'etait pas l'idee recue. Mesure
## (tools/promo_probe.tscn) sur les six promotions degradees d'une campagne :
## deux echouent SEULEMENT ici, deux echouent SEULEMENT sur le ratio, et deux
## sur les deux a la fois. Il y a donc deux boutons, pas un - et celui-ci a
## l'avantage de ne rien devoir a l'etat du plateau : il se lit sur le pion.
##
## Attention en lisant la sonde : ses etiquettes suivent l'ordre des tests, donc
## "pion sans capture" masque les cas ou le ratio aurait mordu de toute facon.
const PROMOTION_REQUIRES_CAPTURE := true

## LE TRONE PLUTOT QUE LA RANGEE : nombre de colonnes CENTRALES du fond adverse
## ou la couronne se gagne. 0 = toute la rangee.
##
## Laisse a 0 pour l'instant : sur un plateau de cinq colonnes, reduire la
## cible a une ou deux cases fait double emploi avec le sacre qui prend un
## tour - les deux transforment la meme case en zone de tir, et cumulees elles
## rendent la couronne inatteignable. A n'ouvrir que si les mesures montrent
## que la Dame reste trop frequente.
const PROMOTION_THRONE_WIDTH := 0

## SERIE - poids que le joueur recupere ENTRE deux combats d'une meme serie.
##
## Un budget de poids (cf. deploy_weight), pas un nombre de pieces, et depense
## sur les pertes les moins cheres d'abord : concretement, deux pions se
## relevent entre deux batailles, jamais une tour. Sans ce filet la serie est
## une spirale - un mauvais premier combat rend le troisieme injouable ; avec
## lui, l'usure reste reelle mais rattrapable, et ce sont les pieces lourdes
## perdues qui font mal.
const RUN_REINFORCE_WEIGHT := 2

## Combien de combats NULS une serie tolere avant de s'achever.
##
## Un nul ne consomme plus le combat : on le rejoue, avec ses survivants et
## les blesses releves. C'est coherent avec "un nul ne rompt pas la serie" -
## un tour d'usure paye pour rien n'a aucune raison de faire avancer le
## compteur de combats.
##
## ⚠️ MAIS SANS PLAFOND, ON NE PEUT PLUS JAMAIS PERDRE UNE SERIE PAR NUL.
## Le pat est frequent ici - 6 des 19 parties du banc, bataille 1 comprise -
## et rejouer indefiniment le meme combat serait un moyen de ne jamais rien
## risquer. Au troisieme nul, la serie s'acheve sans etre remportee.
##
## Decision du joueur le 24/08/2026, apres avoir vu un nul renvoyer au premier
## combat de la serie.
const RUN_DRAWS_ALLOWED := 3

#  reward    LA RECOMPENSE EST CELLE D'UN COMBAT, PAS D'UNE BATAILLE. Une serie
#              de trois combats paie donc trois fois cette valeur (cf.
#              CampaignRun.record_victory, et l'ecran de preparation qui annonce
#              "Recompense de la serie"). Huit batailles sur dix etant des
#              series, se tromper la-dessus fausse tout le calcul d'un facteur
#              deux a trois - c'est exactement l'erreur qu'a faite la premiere
#              version de la sonde economique.
#
#              LA COURBE SUIT CELLE DES COUTS, et c'est tout ce qu'il faut
#              retenir en y touchant.
#
#              Elle ne le faisait pas. Les recompenses montaient presque
#              lineairement - 90, 120, 160... 900, soit 3 590 or pour toute la
#              campagne - pendant que le prix des niveaux monte
#              GEOMETRIQUEMENT. Mesure (tools/economy_probe.tscn), cumul des
#              ameliorations pour atteindre le niveau que la campagne prete au
#              joueur :
#
#                bataille 3 ....  1 130 or     campagne versee a ce stade :   930
#                bataille 5 ....  3 300 or                                  1 650
#                bataille 7 ....  6 810 or                                  2 810
#                bataille 9 ... 11 970 or                                   5 110
#                bataille 10 .. 19 090 or                                   7 030
#
#              Un facteur deux et demi a l'arrivee, et ca ne se rattrape pas en
#              jouant mieux. La sonde, qui sous-estimait alors les revenus, a du
#              rejouer 36 fois une bataille deja gagnee pour franchir la seule
#              bataille 7. Ce n'etait pas de la difficulte, c'etait de la
#              corvee.
#
#              La courbe actuelle est calee pour que le cumul verse AVANT une
#              bataille couvre ce qu'elle demande, avec une marge pour les
#              recrues.
#
#              CE QUI RESTE EN POCHE A LA FIN EST LE VRAI JUGE. Une campagne
#              qu'on traverse sans jamais farmer mais en finissant avec 60 % de
#              son or intact n'a plus aucune decision dedans : l'or ne se
#              choisit plus, il s'accumule. Mesure a viser - la traversee sans
#              farm obligatoire, ET un tresor de fin modeste. Une hausse des
#              deux dernieres recompenses a ete essayee puis retiree pour cette
#              raison : elle laissait 33 593 or dormants sur 55 530 encaisses.
#              A lire en RETIRANT la recompense de la derniere bataille : elle
#              tombe quand il n'y a plus rien a acheter, donc elle gonfle le
#              tresor final sans avoir jamais ete un choix.
#
#              MESURE DE REFERENCE de la courbe actuelle (economy_probe) - c'est
#              a ce tableau qu'il faut comparer apres toute retouche :
#
#                encaisse ............ 41 430   (dont 1 680 de missions)
#                depense ............. 21 937
#                reste ............... 19 493   dont 15 000 de recompense finale
#                surplus reel .........  4 493
#                replays obligatoires .      0
#                niveaux atteints ..... Ch6 P6 C6 F6 T6 - exactement `player: 6`
#
#              Les deux signaux de sante sont la : aucun farm impose, et un
#              surplus mince une fois la derniere prime mise de cote. Le farm redevient un choix - accelerer - au lieu d'un
#              passage oblige. Toucher a `upgrade_cost` sans relancer la sonde,
#              c'est rouvrir le trou.

const CAMPAIGN := [
	{"id": 1,  "name": "L'Orée du Bois",     "cols": 5, "rows": 6, "reward": 150,  "level": 1, "player": 1, "ai": AI_NOVICE, "fights": 1, "enemies": {PION: 4}},
	{"id": 2,  "name": "Le Gué de Pierre",   "cols": 5, "rows": 6, "reward": 250, "level": 1, "player": 1, "ai": AI_NOVICE, "fights": 2, "enemies": {PION: 3, FOU: 1}},
	{"id": 3,  "name": "La Route du Sel",    "cols": 6, "rows": 7, "reward": 400, "level": 2, "player": 2, "ai": AI_AGUERRI, "fights": 2, "enemies": {PION: 4, CAVALIER: 1, TOUR: 1}},
	{"id": 4,  "name": "Les Champs Brûlés",  "cols": 6, "rows": 7, "reward": 600, "level": 2, "player": 2, "ai": AI_AGUERRI, "fights": 2, "enemies": {PION: 5, FOU: 1, CAVALIER: 1}},
	{"id": 5,  "name": "Le Pont Noir",       "cols": 6, "rows": 8, "reward": 900, "level": 2, "player": 3, "ai": AI_AGUERRI, "fights": 2, "enemies": {PION: 6, TOUR: 1, FOU: 1}},
	{"id": 6,  "name": "La Carrière",        "cols": 6, "rows": 8, "reward": 1200, "level": 3, "player": 3, "ai": AI_AGUERRI, "fights": 2, "enemies": {PION: 6, CAVALIER: 1, TOUR: 1}},
	{"id": 7,  "name": "Les Marches Grises", "cols": 7, "rows": 8, "reward": 1600, "level": 3, "player": 4, "ai": AI_EXPERT, "fights": 2, "enemies": {PION: 7, FOU: 1, CAVALIER: 1, TOUR: 1}},
	{"id": 8,  "name": "Le Col du Corbeau",  "cols": 7, "rows": 8, "reward": 2000, "level": 4, "player": 4, "ai": AI_EXPERT, "fights": 3, "enemies": {PION: 8, TOUR: 2, CAVALIER: 1}},
	{"id": 9,  "name": "Les Ruines Hautes",  "cols": 7, "rows": 9, "reward": 2800, "level": 4, "player": 5, "ai": AI_EXPERT, "fights": 3, "enemies": {PION: 8, FOU: 2, TOUR: 1, CAVALIER: 1}},
	# "dame" : Dames offertes a la PREMIERE victoire seulement (cf.
	# battle.gd > _show_result). Le Roi a perdu sa Dame au premier ecran du
	# jeu ; il la retrouve au bout de sa campagne, meme si aucun de ses pions
	# n'a jamais traverse un plateau. Sans ce filet, la moitie du jeu - Tour
	# de la Dame, aura, ameliorations - reste eteinte pour la plupart des
	# joueurs : une promotion reussie reste un exploit rare.
	{"id": 10, "name": "La Tour de la Dame", "cols": 8, "rows": 9, "reward": 5000, "level": 4, "player": 6, "ai": AI_EXPERT, "dame": 1, "fights": 3, "enemies": {PION: 9, FOU: 2, TOUR: 2, CAVALIER: 1}},
]

# ------------------------------- MISSIONS ------------------------------------
#
#  Les missions sont le fil qui guide le joueur : elles repondent en
#  permanence a la seule question qui compte au village - "et maintenant, je
#  fais quoi ?". Elles remplacent un tutoriel, qu'on oublie apres trois
#  ecrans, et paient en OR, la monnaie que le jeu utilise deja.
#
#  Elles se DEVERROUILLENT EN CHAINE : une mission n'apparait que lorsque
#  celles listees dans "requires" ont ete reclamees. Le joueur decouvre donc
#  le jeu dans l'ordre ou il est fait pour etre decouvert, sans jamais voir
#  un objectif qu'il ne peut pas encore atteindre.
#
#  Champs :
#    id        identifiant stable, utilise dans la sauvegarde
#    text      libelle affiche
#    goal      compteur suivi (cf. GameState.mission_progress)
#    target    valeur a atteindre
#    gold      recompense
#    requires  missions a avoir reclamees avant que celle-ci apparaisse
#
#  Compteurs disponibles :
#    battles_won      batailles gagnees (rejouer une bataille compte)
#    units_recruited  pieces recrutees au village
#    upgrades         ameliorations de batiment terminees
#    flawless_wins    victoires sans perdre une seule piece
#    captures         pieces ennemies capturees, toutes batailles confondues
#    promotions       pions menes au bout du plateau
#    dames            Dames actuellement au repos au Chateau Royal
#    castle_level     niveau du Chateau Royal
#    campaign         1 quand la campagne est terminee, 0 sinon

const MISSIONS := [
	# --- Les cinq premieres SONT le tutoriel : elles se suivent une a une.
	{"id": "first_win", "text": "Remporte ta première bataille",
		"goal": "battles_won", "target": 1, "gold": 180, "requires": []},
	{"id": "recruit", "text": "Recrute une pièce au village",
		"goal": "units_recruited", "target": 1, "gold": 120, "requires": ["first_win"]},
	{"id": "upgrade", "text": "Améliore un bâtiment",
		"goal": "upgrades", "target": 1, "gold": 240, "requires": ["recruit"]},
	{"id": "three_wins", "text": "Remporte 3 batailles",
		"goal": "battles_won", "target": 3, "gold": 360, "requires": ["upgrade"]},
	{"id": "flawless", "text": "Gagne sans perdre une seule piece",
		"goal": "flawless_wins", "target": 1, "gold": 420, "requires": ["three_wins"]},

	# --- Puis deux branches en parallele : la guerre et le royaume.
	{"id": "captures", "text": "Capture 20 pièces ennemies",
		"goal": "captures", "target": 20, "gold": 480, "requires": ["flawless"]},
	{"id": "promotion", "text": "Mène un pion jusqu'au bout du plateau",
		"goal": "promotions", "target": 1, "gold": 660, "requires": ["flawless"]},
	{"id": "castle3", "text": "Porte le Château Royal au niveau 3",
		"goal": "castle_level", "target": 3, "gold": 780, "requires": ["upgrade"]},

	# --- Le bout du chemin.
	{"id": "dame", "text": "Ramène une Dame vivante au village",
		"goal": "dames", "target": 1, "gold": 900, "requires": ["promotion"]},
	{"id": "two_dames", "text": "Abrite 2 Dames au Château Royal",
		"goal": "dames", "target": 2, "gold": 1200, "requires": ["dame"]},
	{"id": "campaign", "text": "Termine la campagne",
		"goal": "campaign", "target": 1, "gold": 1500, "requires": ["castle3", "captures"]},
]


func mission(id: String) -> Dictionary:
	for m in MISSIONS:
		if String(m["id"]) == id:
			return m
	return {}


# ------------------------------- MOUVEMENT -----------------------------------
#
#  LES DUREES D'ANIMATION, TOUTES AU MEME ENDROIT.
#
#  ⚠️ Elles n'y etaient pas, et la regle 1 le demandait depuis le debut. Vingt-
#  deux constantes de duree vivaient dans huit fichiers d'ecran : ZOOM_SECONDS
#  dans village.gd, ENTRY_DURATION dans modal.gd, OPEN_DURATION dans
#  mission_popup.gd... C'est pour ca que "ralentir toutes les transitions",
#  demande par le joueur apres son test du 23/08, n'etait pas un geste mais
#  huit.
#
#  `scale` est LE bouton. Il multiplie toutes les durees ci-dessous :
#    1.0  les valeurs telles quelles
#    1.4  tout dure 40 % de plus
#  Le joueur trouvait le jeu "trop rapide, on voit des sautes de frame" : les
#  valeurs de base ont donc DEJA ete rallongees par rapport a ce qu'elles
#  etaient, et `scale` reste la pour ajuster sans y revenir.
#
#  Ne pas y mettre les durees qui ne sont pas des transitions : la frappe
#  lettre par lettre du Roi ou le zoom ambiant de 14 s de l'intro sont de la
#  mise en scene, pas du rythme de navigation.

const MOTION := {
	"scale": 1.0,

	# --- Le voile de transition entre deux ecrans (cf. ScreenVeil).
	# Etait absent : chaque ecran fondait dans son coin, et le changement de
	# scene lui-meme n'avait aucun fondu - d'ou la coupure franche vers le
	# chateau, et l'image non peinte qu'on apercevait derriere.
	"veil_cover": 0.30,
	"veil_reveal": 0.34,
	# Temps laisse au nouvel ecran pour se construire et peindre sa premiere
	# image AVANT qu'on leve le voile. Sans lui, castle_screen se montrait
	# pendant qu'il chargeait encore son fond : le joueur voyait du gris.
	"veil_settle": 0.12,

	# --- L'INTRO : LE ROI SE REDRESSE.
	# La maquette a DEUX illustrations pour le meme plan - le Roi accable, la
	# main sur la tete, et le Roi redresse qui parle. Le jeu n'en avait qu'une,
	# la seconde, et le joueur l'a vu : "je vois seulement la deuxieme image de
	# l'ecran figma". L'approche montre la premiere, le contact fond vers la
	# seconde. Mesure : les deux frames sont cadrees a l'IDENTIQUE (echelle
	# 1,000, decalage nul, releve sur les deux exports), donc c'est bien un
	# fondu de POSE et pas un changement de plan.
	#
	# 1,4 s : assez long pour qu'on voie le Roi relever la tete, assez court
	# pour que le dialogue n'attende pas apres lui - la bulle part a 0,5 s et
	# les deux se recouvrent.
	"intro_pose": 1.4,
	# Le degrade du bas n'existe PAS sur l'ecran d'approche (frame 410:35 :
	# un vignetage haut, rien en bas - on voit le sol). Il arrive avec le
	# dialogue, pour porter la bulle et le bouton.
	"intro_gradient": 0.8,

	# --- Le zoom du village vers un batiment.
	# Etait a 0,35 s : trop court pour qu'on suive le mouvement de l'oeil.
	"village_zoom": 0.55,

	# --- Le zoom de la carte sur le cachet tape, avant la preparation.
	# La carte avait son propre fondu au noir EN PLUS : il faisait doublon avec
	# le voile global et noircissait deux fois de suite. Seul le zoom reste.
	"map_zoom": 0.50,

	# --- L'entree d'une modale (Modal.open).
	"modal_entry": 0.45,
	"modal_dim": 0.18,

	# --- Les ecrans qui montent leur contenu par blocs.
	"panel_entry": 0.42,
	"card_entry": 0.34,
	"card_stagger": 0.07,

	# --- LE RETOUR A L'APPUI. Le joueur : "aucun bouton ne reagit quand on
	# appuie dessus". Ce n'est pas une transition entre ecrans, c'est la reponse
	# du doigt - et c'est le seul endroit du jeu ou la duree doit rester COURTE
	# quoi qu'il arrive : un bouton qui met un tiers de seconde a s'enfoncer ne
	# se lit plus comme un bouton, il se lit comme une lenteur.
	#
	# ⚠️ ELLES NE SUIVENT PAS `scale`, exprès. `scale` sert a ralentir la
	# navigation ; l'applique ici et un `scale` de 1.4 rendrait chaque appui
	# mou. Voir UiTheme.press_feedback, qui les lit en direct.
	"press_in": 0.06,
	"press_out": 0.13,

	# --- LE COMPTEUR D'OR. "L'or saute au lieu de monter."
	# C'est la duree d'un GROS gain ; les petits sont raccourcis a la
	# proportion de l'ecart (cf. village._maj_or). Celle-ci suit `scale` :
	# c'est de la mise en scene, pas une reponse au doigt.
	"gold_count": 0.55,
}

## De combien un controle rapetisse sous le doigt. 4 %, mesure a l'oeil sur un
## bouton de 48 points : en dessous ca ne se voit pas, au-dessus le libelle
## commence a "sauter" a chaque appui.
const PRESS_SCALE := 0.96


## Duree d'animation `key`, mise a l'echelle par MOTION.scale.
##
## Passer par cette fonction plutot que de lire MOTION directement : c'est ce
## qui fait que `scale` s'applique partout sans exception.
static func motion(key: String) -> float:
	return float(MOTION.get(key, 0.3)) * float(MOTION["scale"])


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
	# Temps pendant lequel le mot COMBATTEZ barre le plateau au lancement du
	# combat, une fois qu'il a fini de surgir. Ce n'est pas de la decoration :
	# c'est un delai avant que le joueur puisse jouer son premier coup, et
	# c'est pour ca qu'il est reglable ici plutot qu'ecrit dans l'ecran.
	# Releve sur 05_Bataille_Combat (433:3) : 0,45 s de maintien entre une
	# irruption de 0,25 s et une disparition de 0,60 s.
	"opening_word_seconds": 0.45,
	# Enlisement : nombre de TOURS COMPLETS sans la moindre prise avant de
	# trancher aux pieces restantes. Compte en tours et non en activations,
	# sinon une grande armee declencherait le verdict avant meme le contact.
	# Plus genereux qu'en resolution automatique : un joueur humain a le droit
	# de manoeuvrer longuement sans prendre la moindre piece.
	"stalemate_rounds": 8,
	"stalemate_rounds_manual": 20,
	# Plafond des BANCS, ou les deux camps sont joues par l'IA : quelle que
	# soit la taille de l'armee, 30 secondes de jeu simule sans la moindre
	# prise suffisent a trancher. Ce plafond n'a aucun sens quand c'est un
	# humain qui joue - il reflechit - donc il ne s'applique pas en partie
	# (cf. BattleEngine.auto_mode).
	"stalemate_seconds_cap": 30,
	# POSITION MORTE - plus aucune capture n'est possible, jamais (cf.
	# BattleEngine.capture_still_possible). Deux cavaliers Nv.1 sur des
	# couleurs de cases opposees ne se toucheront jamais : attendre les 80
	# activations du compteur d'enlisement pour l'annoncer est une punition
	# gratuite.
	#
	# On ne cherche la position morte qu'apres quelques activations sans prise
	# (le calcul parcourt le plateau pour chaque piece), puis on laisse un
	# court delai avant de trancher : le joueur doit LIRE l'annonce, pas se
	# faire couper net.
	"dead_position_check_after": 4,
	"dead_position_grace": 6,
	# PAT - le camp au trait n'a plus aucun coup legal. Deux ecoles, et le
	# choix se fait manette en main, pas au banc :
	#
	#   true  (echecs)   le pat fait NUL. Le camp ecrase sauve la partie -
	#                    c'est la ressource du pat, que tout joueur d'echecs
	#                    connait. Mesure : 6 parties de banc sur 19 finissent
	#                    nulles, bataille 1 comprise. Sur un plateau de cinq
	#                    colonnes les pions se bloquent nez a nez sans arret,
	#                    donc le pat y est BEAUCOUP plus frequent qu'aux
	#                    echecs.
	#   false (shatranj) le camp bloque PERD. Figer l'adversaire devient une
	#                    victoire. Plus lisible pour qui ne vient pas des
	#                    echecs, et le nul reste reserve a la position morte -
	#                    le seul cas ou personne ne peut plus rien.
	#
	# Une seule valeur separe les deux jeux : ne pas la coder en dur ailleurs.
	"stalemate_is_draw": true,
	# Duree du bandeau entre deux combats d'une serie (cf. SeriesBanner). Le
	# joueur peut le couper au doigt : cette valeur ne fixe que l'attente
	# MAXIMALE de quelqu'un qui ne touche a rien.
	"series_banner_seconds": 2.4,
	"max_activations": 1200,   # garde-fou absolu
}

# ------------------------------- BOUTIQUE ------------------------------------
#
#  Une DEUXIEME monnaie, les gemmes, et une seule chose a acheter avec :
#  du TEMPS D'AMELIORATION. Pas d'or, pas de pieces, pas de rarete neuve.
#
#  POURQUOI LE TEMPS, ET RIEN D'AUTRE. C'est le seul contenu qui ne touche
#  aucun chiffre mesure - ni upgrade_cost, ni les recompenses, ni les 10/10
#  de smoke_test. Et c'est la vraie friction du jeu : 47,5 heures d'attente
#  cumulees pour tout monter au niveau 10, dont 11,1 h rien que pour le
#  Chateau Royal, le batiment qui commande la charge de deploiement.
#
#  Un coffre a PIECES aurait plafonne sur la capacite des casernes et, pour le
#  Legendaire, offert une Dame - ce qui detruirait l'histoire du jeu : sa
#  rarete est un resultat mesure (8 ramenees a 2), pas un accident. Un coffre
#  a OR aurait rouvert le trou que economy_probe a mis des heures a fermer.
#
#  LE ROBINET COMMANDE TOUT LE RESTE. Les prix ci-dessous n'ont de sens que si
#  une campagne produit de l'ordre de 1000 gemmes. En dessous, la boutique est
#  une vitrine fermee ; au-dessus, le plus gros pack d'or s'achete trois fois
#  et l'economie mesuree se rouvre. Les valeurs de free_chests sont donc a
#  MESURER (tools/shop_probe.tscn), pas a croire.
#
#  Detail de la spec : chantier_h_boutique.md

const SHOP := {
	# Le robinet. Les gemmes ne s'achetent pas (aucun store n'existe) : elles
	# se ramassent ici. Une seule piste par cle, un seul coffre en attente a
	# la fois - sans ce plafond, partir une semaine rendrait 168 coffres.
	# ROBINET DIVISE PAR DEUX, sur decision du joueur, apres mesure.
	#
	# A 8 et 25 gemmes, une campagne en produisait 1584 - de quoi acheter
	# 11 h 52 d'acceleration pour 4 h 55 d'attente reelle, soit 241 %. Les
	# minuteries cessaient d'etre une contrainte pour qui ramasse ses coffres.
	# A 4 et 12, le rapport retombe autour de 120 % : la boutique couvre
	# l'attente sans la pulveriser.
	"free_chests": {
		"horaire":      {"seconds":  3600, "gems":  4},
		"trois_heures": {"seconds": 10800, "gems": 12},
	},
	# Coffres achetes : des SECONDES d'amelioration, pas un tirage. Il n'y a
	# aucune source d'alea dans ce jeu, et un coffre a probabilites serait la
	# premiere.
	#
	# seconds < 0 : termine TOUTES les ameliorations en cours. Ce n'est pas
	# une fantaisie, c'est de l'arithmetique - la plus longue amelioration du
	# jeu dure 4 h et l'Epique en donne deja 3 h pour 400 gemmes. Un
	# Legendaire qui n'en finirait qu'une seule couterait 1000 gemmes pour
	# moins de temps que deux Epiques : strictement domine, donc jamais
	# achete.
	# `id` sert de clef (ASCII, comparable, sauvegardable) ; `name` est ce que
	# le joueur lit. Deriver l'un de l'autre par capitalize() perdait l'accent
	# d'"Epique".
	"chests": [
		{"id": "commun",     "name": "Commun",     "gems":   50, "seconds":   900},
		{"id": "rare",       "name": "Rare",       "gems":  150, "seconds":  3600},
		{"id": "epique",     "name": "Épique",     "gems":  400, "seconds": 10800},
		# Descendu de 1000 a 600 EN MEME TEMPS que le robinet : a 1000, il
		# depassait tout ce qu'une campagne produit desormais (792 gemmes) et
		# devenait litteralement inachetable. Un coffre qu'on ne peut jamais
		# s'offrir n'est pas un objet de desir, c'en est un de frustration.
		{"id": "legendaire", "name": "Légendaire", "gems":  600, "seconds":    -1},
	],
	# Section OR. Les prix en gemmes sont ceux de la maquette ; les montants
	# d'or sont RECALIBRES. Le pack dessine a 25000 valait plus que le cumul
	# d'ameliorations demande a la bataille 10 (19090) : il ne desequilibrait
	# pas l'economie, il proposait de sauter la campagne.
	#
	# PROVISOIRE jusqu'a economy_probe.
	# MESURE, pas choisi. La premiere version (500 / 2200 / 6000) passait le
	# garde-fou de smoke_test, qui ne regarde qu'UN pack - mais shop_probe a
	# montre que le budget ENTIER d'une campagne (~1600 gemmes) achetait alors
	# 15 500 or, soit 39 % de ce que verse la campagne. Le trou economique se
	# rouvrait par la somme, pas par le pack.
	#
	# Deuxieme defaut de cette version : le petit pack rendait 10 or/gemme et
	# le gros 7,5. Un pack qui grossit doit devenir MEILLEUR, sinon c'est un
	# piege pour qui ne fait pas le calcul.
	"gold_packs": [
		{"gems":  50, "gold":  150},   # 3,00 or/gemme
		{"gems": 200, "gold":  700},   # 3,50
		{"gems": 600, "gold": 3000},   # 5,00 - descendu de 800 avec le robinet,
		                               # meme raison que le Legendaire
	],
	# Section GEMMES. Dessinee, inerte : Godot n'a pas de facturation native
	# et le build web ne peut rien vendre. gem_packs_enabled les rallumera le
	# jour d'un export mobile signe.
	"gem_packs": [
		{"gems":  100, "price": "0,99 €"},
		{"gems":  500, "price": "4,99 €"},
		{"gems": 2500, "price": "19,99 €"},
	],
	"gem_packs_enabled": false,
}

# ------------------------------- ACCESSEURS ----------------------------------
#
#  Passer par ces fonctions plutot que de lire les dictionnaires directement :
#  les niveaux y sont bornes une seule fois, au meme endroit.

func unit_name(type: String) -> String:
	if type == CASTLE:
		return CASTLE_DATA["name"]
	return UNITS[type]["name"]


## Article defini de la piece, pour les libelles qui la nomment ("LA TOUR").
## Deux pieces sur six sont feminines : l'ecrire une fois ici evite de le
## redecouvrir a chaque ecran qui compose une phrase.
func unit_article(type: String) -> String:
	return "la" if type == TOUR or type == DAME else "le"


## "1 Pion", "4 Pions" - le jeu ecrivait "4 Pion" partout ou il comptait des
## pieces (pertes, blesses releves, bandeau de serie). Le pluriel se decide ici
## plutot que dans chaque ecran : il y en avait deja trois.
func unit_count(type: String, count: int) -> String:
	var name := unit_name(type)
	return "%d %s%s" % [count, name, "s" if count > 1 else ""]


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


func jump_offsets(type: String, level: int) -> Array:
	var value: Variant = _at_level(UNITS[type].get("jump_offsets", []), level)
	return [] if value == null else value


## "1 case" ou "3 cases". Le jeu ecrivait "case(s)", ce qui se voit et se lit
## mal - le nombre est connu au moment ou la phrase se construit.
func _cases(n: int) -> String:
	return "%d case%s" % [n, "s" if n > 1 else ""]


## Le nom d'une figure de saut. Les deux premieres ont un nom d'echiquier, et
## il vaut mieux que des coordonnees : "saut en L" dit a un joueur ce que
## "1x2" ne lui dira jamais. Au-dela, aucune figure n'a de nom recu, alors on
## donne les cases - c'est ce que la maquette fait aussi ("2+1 cases").
func _jump_name(dx: int, dy: int) -> String:
	var petit := mini(dx, dy)
	var grand := maxi(dx, dy)
	if petit == 1 and grand == 1:
		return "saut diagonal"
	if petit == 1 and grand == 2:
		return "saut en L"
	return "saut %d+%d cases" % [grand, petit]


## Description lisible du deplacement, affichee dans le popup de batiment.
func move_description(type: String, level: int) -> String:
	match move_type(type):
		"orthogonal":
			return "lignes et colonnes, %s" % _cases(move_range(type, level))
		"diagonal":
			return "diagonales, %s" % _cases(move_range(type, level))
		"queen":
			return "toutes directions, %s" % _cases(move_range(type, level))
		"jump":
			# Les FIGURES elles-memes, pas leur nombre. Le cavalier passe du
			# petit saut diagonal (1x1) au L classique (1x2) en montant au
			# niveau 2 : deux sauts tres differents, mais toujours UNE figure.
			# A n'en dire que le compte, l'ecran d'amelioration affichait la
			# meme phrase avant et apres, et masquait donc le seul gain reel de
			# ce palier.
			var noms: Array = []
			for figure in jump_offsets(type, level):
				noms.append(_jump_name(int(figure[0]), int(figure[1])))
			return ", ".join(noms)
		_:
			var reach := move_range(type, level)
			var opening := first_move_range(type, level)
			if opening > reach:
				return "en avant %s, %d au premier coup, capture en diagonale" % [
					_cases(reach), opening]
			return "en avant %s, capture en diagonale" % _cases(reach)


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


## Dames offertes par la premiere victoire sur cette bataille. Zero partout
## sauf au bout de la campagne.
func battle_dame_reward(battle: Dictionary) -> int:
	return int(battle.get("dame", 0))


## Niveau de jeu de l'armee ennemie pour cette bataille. Une bataille qui ne
## le declare pas joue au maximum : mieux vaut une IA trop forte qu'une IA
## distraite par oubli.
func battle_ai_skill(battle: Dictionary) -> int:
	return int(battle.get("ai", AI_EXPERT))


## Niveau auquel le joueur est CENSE aborder cette bataille, pour les bancs.
##
## Distinct de "level", qui est celui des pieces ennemies. Les deux etaient
## confondus tant que l'avantage du joueur etait fait de NOMBRE ; ils se
## separent des lors qu'il est fait de QUALITE - moins de pieces, mieux
## equipees, face a un adversaire plus nombreux et plus fruste.
##
## Une bataille qui ne declare rien suppose les deux camps au meme niveau.
func battle_player_level(battle: Dictionary) -> int:
	return int(battle.get("player", battle.get("level", 1)))


func battle_count() -> int:
	return CAMPAIGN.size()


## Nombre de combats de la serie pour cette bataille. Une bataille qui ne le
## declare pas se joue en un seul combat.
func battle_fights(battle: Dictionary) -> int:
	return maxi(1, int(battle.get("fights", 1)))


# ------------------------------- BOUTIQUE ------------------------------------

## Coffre achete, par son identifiant. Rend un dictionnaire vide si l'id est
## inconnu : l'appelant teste is_empty() plutot que de piocher a l'aveugle.
func shop_chest(id: String) -> Dictionary:
	for chest in SHOP["chests"]:
		if chest["id"] == id:
			return chest
	return {}


## Coffre gratuit, par sa piste ("horaire" ou "trois_heures").
func free_chest(id: String) -> Dictionary:
	return SHOP["free_chests"].get(id, {})


## Les deux pistes de coffres gratuits, dans l'ordre d'affichage.
func free_chest_ids() -> Array:
	return SHOP["free_chests"].keys()
