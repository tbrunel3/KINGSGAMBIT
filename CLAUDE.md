# KING'S GAMBIT — manuel de bord

Jeu mobile de stratégie fantasy inspiré des échecs, en **Godot 4.7 / GDScript**,
portrait uniquement. Le Roi a perdu sa Dame ; il reconstruit son armée et
enchaîne des batailles pour la retrouver.

Ce fichier est le manuel de l'agent qui arrive sur le projet : ce qu'est le jeu,
où vivent les règles, comment le mesurer, et les pièges déjà payés. Deux autres
documents complètent celui-ci et ne le répètent pas :

- [`README.md`](README.md) — pour un humain : lancer, jouer, régler, tester.
- [`passation_chantiers_c_d_e.md`](passation_chantiers_c_d_e.md) — **le travail
  en cours**, et le premier fichier à ouvrir. Son nom ne dit plus tout ce qu'il
  contient : la composition d'armée est **faite**, les polices et animations
  aux trois quarts, un chantier de **format d'écran** s'est ajouté, et les
  popups d'accompagnement restent. Il porte aussi les décisions déjà prises par
  le joueur — à lire avant d'y toucher, la moitié de ce qu'il demande existe
  déjà, et le rebâtir créerait des règles concurrentes.
- [`chantier_g_f.md`](chantier_g_f.md) — **le chantier en cours** : l'assemblage
  graphique et le format d'écran, menés ensemble. Il porte les cinq décisions
  prises le 23/08 (dont `expand`, qui commandait tout le reste), la mesure
  chiffrée de la dérive du village, et le plan d'attaque en six temps.
- [`passation_g_f.md`](passation_g_f.md) — la passation du même chantier :
  l'inventaire des animations, celui des écrans, les sept pièges de portage, et
  la mesure de l'incohérence des boutons de coin — six tailles pour la même
  chose. **Partout où il dit « pas tranché », c'est la spec qui fait foi.**
- [`chantier_i_missives.md`](chantier_i_missives.md) — **le chantier suivant,
  spec écrite le 23/08, pas encore commencé** : les quatre lettres scellées du
  Roi, qui portent le *pourquoi* du jeu là où `GuidePopup` porte le *comment*.
  Il contient les mesures des deux illustrations (plissures à 39,5 % et 65,4 %,
  marge intérieure 8,5 %) et la seule pièce de données manquante — le jeu n'a
  **aucun compteur de défaite**.
- [`chantier_h_boutique.md`](chantier_h_boutique.md) — la boutique : règles,
  mesures et décisions. Terminé.
- [`figma_contexte_projet.md`](figma_contexte_projet.md) — pour le designer :
  l'état du jeu vu de la maquette, et les règles de collaboration.

---

## Les cinq règles qui priment sur tout

**1. Aucune valeur de gameplay hors de [`scripts/data/balance.gd`](scripts/data/balance.gd).**
Tailles de plateau, compositions ennemies, portées, coûts, durées d'animation,
seuils : tout est là. Régler le jeu ne demande pas d'ouvrir l'éditeur.

**2. Figma apporte l'apparence, jamais les règles.** Couleurs, typographie,
illustrations, mise en page, hiérarchie, composants : ça vient de la maquette.
Ce qu'on peut faire dans le jeu, quand, et avec quel effet : ça vient de
`scripts/`. Si une frame montre un écran sans le bouton dont le gameplay a
besoin, on garde le bouton et on l'habille. Si un libellé annonce une règle
différente de celle du code, **c'est le libellé qu'on corrige**.

**3. Rien ne joue à la place du joueur.** Ni résolution automatique, ni vitesse
accélérée, ni formation composée par l'ordinateur. C'est une décision de fond,
pas un nettoyage : le cœur du jeu est que le joueur joue chaque coup. Le moteur
sait toujours tenir les deux camps (`BattleEngine.auto_mode`) — c'est ce dont
vivent les bancs, et ce code habite [`tools/battle_driver.gd`](tools/battle_driver.gd),
hors des scènes de production pour qu'il ne soit pas rebranché « juste pour
essayer ».

**4. Ancrer, ne pas positionner.** Un écran posé en coordonnées absolues calées
sur 852 points se décale dès que l'appareil en fait 880. Chaque écran se découpe
en zones ancrées — barre haute de hauteur fixe, contenu central qui prend la
place restante, bandeau bas de hauteur fixe. Cadre utile : **361 × 824**
(393 × 852 moins les marges de zone sûre).

✅ **Tous convertis** depuis le 23/08/2026. Le village était le dernier, et son
cas était particulier : ses étiquettes sont collées à des bâtiments **peints
dans l'illustration**, pas posées sur du contenu. Il se découpe donc en **deux
calques** — `DecorLayer` suit le rectangle réel du fond, `UiLayer` suit l'écran.
Mesure avant correction : **34 points de dérive** sur un écran court, et le
bouton BATAILLE à **42 points du centre**. Après : dérive nulle sur les huit
formats, vérifiée par [`tools/format_test.tscn`](tools/format_test.gd).

⚠️ **« Tous » était faux : les écrans d'INTRO n'avaient jamais été passés**, et
le joueur a vu le défaut sur la version web avant qu'un banc ne le voie. Corrigé
le 23/08/2026 — mais la leçon compte plus que le correctif, parce qu'elle
retourne le piège n°1 :

**La largeur ne descend pas sous 393, donc 393 a l'air d'une valeur sûre. Elle
ne l'est pas : elle MONTE.** En `expand`, Godot choisit l'échelle sur l'axe le
plus contraint ; dans un navigateur c'est la **hauteur** qui manque, la barre
d'URL en prenant sa part. Sur `web-393x700` le viewport fait **478 × 852**, sur
`court-360x620` il fait **495**. Les deux vignettes de `king_intro_dialogue`
étaient posées en absolu, larges de 393 en dur : **85,34 points de bande nue à
droite** sur le premier cas, **101,71** sur le second — mesurés en réintroduisant
la régression, pas estimés.

Le pivot de zoom du même écran avait le même défaut, à `(196.5, 426)` — la
moitié de 393 × 852 en dur. **Un `393` ou un `852` littéral dans du code de mise
en page est presque toujours un bug qui attend un navigateur.**

`format_test` a désormais un cas `[3] Intro` qui instancie le vrai écran et
mesure la bande nue sur les huit formats.

**5. Ne jamais laisser un chantier sans trace.** Une fenêtre de contexte
s'épuise en plein travail, et l'agent suivant arrive à froid. **Dès que le
crédit restant ne suffit manifestement plus à finir ce qui est engagé : on
s'arrête, on commit, et on écrit la passation** — dans cet ordre, avant la
dernière goutte, pas après. Un travail à moitié fait et documenté vaut mieux
qu'un travail aux trois quarts fait dont personne ne sait où il s'est arrêté.

- **Le commit d'abord.** Même incomplet, même « en cours » — il faut que l'état
  décrit par la passation existe dans l'historique. Un message qui dit ce qui
  marche ET ce qui ne marche pas encore.
- **Puis un fichier de passation**, sur le modèle de
  [`passation_g_f.md`](passation_g_f.md) : ce qu'est le chantier, ce qui est
  fait, ce qui reste, les décisions déjà prises par le joueur, les pièges déjà
  payés avec leurs chiffres, et les mesures à relancer. Il s'adresse à une
  fenêtre qui n'a rien vu de la session.
- **Puis le lien dans ce fichier**, dans la liste d'ouverture — une passation
  que le manuel ne cite pas ne sera pas ouverte.
- **Ne jamais garder une mesure ou une décision pour la fin.** Ce qu'on vient
  d'apprendre s'écrit quand on l'apprend : c'est ce qui est perdu en premier
  quand la fenêtre se ferme d'un coup.

---

## Le jeu en un écran

Le joueur **compose son armée**, la **place** face à une formation ennemie
qu'il voit, puis **joue lui-même chaque coup**, une pièce par camp et par tour,
jusqu'à ce qu'un camp n'ait plus rien debout. Ni points de vie ni dégâts : une
pièce est sur le plateau, ou capturée. On capture en se déplaçant sur la case
adverse.

Un **anneau rouge** cercle en permanence les pièces prenables au coup suivant.
Sans points de vie, voir l'attaque arriver EST la tension du jeu — aux échecs on
ne ressent pas le danger parce que la position est mauvaise, mais parce qu'on
voit le coup venir.

Un pion mené au bout du plateau devient Dame ; **ramenée vivante**, elle rejoint
le **Château Royal** — le trône vide du début de l'histoire — et redevient
déployable. Entre deux batailles, retour au village : recruter, améliorer.

Ton : fantasy médiéval, mélancolique mais pas sombre — un royaume diminué qui se
reconstruit. Aucune violence graphique.

### Recruter fait une réserve, composer fait une armée

C'est la distinction que le jeu ne montrait nulle part, et qui donnait au
joueur l'impression que **« après le recrutement de troupe, rien ne change
ensuite »**. Il avait raison sur le ressenti et tort sur la cause : le
recrutement alimentait bien le placement, mais le vrai plafond n'a jamais été
l'effectif — c'est la **charge**. Au château Nv.1 on pose 16 de charge ; un
dixième pion n'entrait sur aucun plateau.

Ce qui manquait n'était pas un budget, c'était l'étape de **choix** :

| | Où | Quoi | Plafond |
|---|---|---|---|
| **Recruter** | village | remplit la **caserne** | la capacité du bâtiment |
| **Composer** | préparation | remplit le **déploiement** | `Balance.deploy_capacity` |
| **Placer** | placement | pose sur le plateau | *plus aucun* |

**La charge se dépense à la composition, une fois.** Le placement ne fait plus
que poser ce qui a déjà été choisi. Deux plafonds qui se ressemblent, et le
joueur ne saurait plus lequel le bloque — le garde-fou du placement reste dans
`battle.gd`, mais une composition valide le rend inatteignable.

La composition vit dans **`CampaignRun.lineup`**, un sous-ensemble du `roster` :

- **Vide = aucune composition**, et le placement retombe sur le roster entier.
  Ce n'est pas un cas d'erreur, c'est le chemin des **bancs**, qui n'ouvrent
  jamais la préparation — et c'est ce qui leur laisse mesurer la même chose
  qu'avant. `smoke_test` déclare toujours **10/10 batailles gagnables**.
- Elle **survit à la série et se réduit des pertes** : on ne recompose pas
  entre deux combats, sinon on remet un écran de décision là où le bandeau de
  série vient d'en enlever un. Au combat 2, l'écran est en lecture seule.
- **Les renforts y rentrent** (`CampaignRun._reinforce`). Sans ça, un pion
  relevé entre deux combats serait vivant et impossible à poser.
- Elle est **mémorisée par bataille** (`GameState.remember_lineup`), même
  doctrine que `DERNIÈRE FORMATION` : on rend au joueur *sa* décision, on n'en
  prend pas une à sa place — la règle 3 interdit une armée composée par
  l'ordinateur, pas une décision qu'on lui repropose.

⚠️ **La préparation n'ouvre plus la série.** Elle monte un `CampaignRun`
*provisoire* en mémoire et ne le verse qu'au départ du combat
(`_commit_lineup`). Appeler `Game.begin_run` en arrivant sur l'écran
effacerait une série entamée sur une **autre** bataille, juste parce que le
joueur est venu regarder celle-ci.

**C'est le seul écran clair du jeu.** La maquette refaite (`169:4`) est en
parchemin crème et panneaux blancs, quand la carte qui le précède et le
placement qui le suit restent en nuit et or. La rupture a été signalée puis
assumée : la règle 2 donne l'apparence à la maquette.

### La série de combats

À partir de la **deuxième** bataille, un niveau ne se gagne plus en un combat
mais en une **série** — deux d'affilée, puis trois pour les trois dernières,
sans retour au village. Seule la première reste unique : on y découvre le jeu.
La série arrive tôt parce que c'est le **deuxième** combat qui met le joueur en
danger — l'ennemi revient au complet, lui revient avec ses survivants.

**Une série ne se couronne qu'une fois.** Un combat intermédiaire gagné
n'ouvre pas d'écran de victoire : un bandeau court (`SeriesBanner`) dit où on en
est et ce qu'on a perdu, puis le placement du combat suivant s'ouvre — tout seul
après `series_banner_seconds`, ou au doigt. Le grand lettrage et le versement de
l'or restent pour la fin, et la victoire de série renvoie d'abord à la **carte**,
où le cachet suivant s'ouvre. La première série rencontrée s'explique dans un
popup montré **une seule fois** (`SeriesPopup`, `GameState.has_seen_series_warning`).

`fights` (dans `Balance.CAMPAIGN`) est **le bouton de la durée d'une séance**.
Un combat joué à la main prend cinq à dix minutes sur les grands plateaux : à
cinq combats, un niveau demandait quarante minutes d'affilée sans point de
sauvegarde — trop long pour un jeu qu'on ouvre sur un téléphone. À `1`, toute la
machinerie de série devient invisible.

Trois règles fixent l'enjeu ([`scripts/core/campaign_run.gd`](scripts/core/campaign_run.gd)) :

1. Les pertes ne quittent l'armée du village **qu'à la fin de la série**.
2. Entre deux combats, `Balance.RUN_REINFORCE_WEIGHT` de poids se relève parmi
   les pertes, les moins chères d'abord : **deux pions se relèvent, jamais une
   tour**. C'est ce qui empêche la spirale de la mort.
3. Un combat perdu perd la série et tout l'or promis.

L'armée ennemie est la même à chaque combat mais **ne se range pas deux fois
pareil** (tirage semé sur le numéro du combat). Une série survit à la fermeture
du jeu et reprend au combat suivant ; quitter en plein combat le fait
recommencer, avec l'effectif qu'il avait au départ.

### Les trois façons de finir sans vainqueur

Un combat qui ne se décide pas au dernier soldat debout se termine de **trois**
manières, et elles ne se règlent pas au même endroit.

**1. Le PAT** — le camp au trait n'a plus aucun coup légal. `stalemate_is_draw`
(dans `Balance.COMBAT`) décide de son issue, et **c'est le seul bouton du jeu
qui change de public** :

- `true` *(actuel)* — nul, comme aux échecs. Le camp écrasé sauve la partie.
- `false` — le camp bloqué perd, comme au shatranj. Figer l'adversaire devient
  une victoire.

⚠️ **Le pat est BEAUCOUP plus fréquent ici qu'aux échecs**, et ce n'est pas un
accident : sur cinq colonnes, les pions se bloquent nez à nez en permanence, et
un pion ne prend pas tout droit. Mesuré à `true` : **6 des 19 parties du banc
finissent nulles, bataille 1 comprise**, presque toujours parce que l'ennemi est
réduit à trois pions bloqués alors que le joueur mène largement. Ne pas toucher
à ce réglage sans relancer `smoke_test` et lire la colonne des raisons.

**2. La POSITION MORTE** — plus aucune capture n'est possible, jamais. Toujours
nulle. Un cavalier Nv.1 ne saute qu'en diagonale d'une case : il ne quitte
jamais la couleur de case où il est posé, exactement comme un fou. Deux
cavaliers Nv.1 sur des couleurs opposées se courent après indéfiniment.

`BattleEngine.capture_still_possible()` calcule les portées **sur un plateau
vide** (`MovementRules.reachable_on_empty_board`), donc sur-estimées : la
fonction peut RATER une position morte, elle ne peut pas en inventer une. Un
pion encore en vie garde toujours la position vivante — il promeut, et une Dame
atteint tout. Annoncé dans le badge, puis nul après un court délai
(`dead_position_check_after`, `dead_position_grace`). Mesuré : 10 activations au
lieu des 80 du compteur d'enlisement.

**3. L'ENLISEMENT** — plus aucune prise depuis `stalemate_rounds_manual` tours,
mais des coups restent possibles. Tranché **au matériel restant** ; à égalité
stricte, personne n'a gagné.

Au nul, les survivants rentrent, le combat ne rapporte rien, mais **la série
n'est pas rompue** : c'est un tour d'usure payé pour rien, pas une déroute. Un
nul au dernier combat achève la série sans qu'elle soit remportée. L'écran de
résultat a sa propre peau (`BattleResult.draw_skin`) et ses propres assets
(`assets/results/draw_*`, Figma 348:2) : champ de bataille gris, mot **NULLE**
gravé, plaque d'acier. Il dit aussi **pourquoi** c'est nul — sans cette phrase,
« NUL » ressemble à un bug, et c'en était un.

**Un camp ne passe jamais son tour.** `BattleAI.decide_team` joue un coup dès
qu'il en existe un, et `BattleEngine._pass_turn` signale une erreur au lieu de
passer. Le bug d'origine : l'IA restait plantée en finale (la désespérance était
coupée en dessous de quatre pièces), et le compteur de passes qui devait clore
la partie était remis à zéro par le coup du JOUEUR. 48 passes illégitimes
mesurées sur 60 parties, toutes sur les deux batailles en `AI_NOVICE`.

### La Dame : rare à faire, dure à garder

Mesure de départ ([`tools/promo_probe.tscn`](tools/promo_probe.gd)) : douze
promotions par campagne, dont six de ramassage. Trois règles, chacune sur une
cause différente :

1. **L'IA défend sa rangée du fond** — `BattleSearch.PROMOTION_THREAT`. Attention
   au calibrage : à 400 de base, la prime valait quatre pions et poussait les
   deux camps à *courir* au fond plutôt qu'à se battre ; les promotions
   doublaient au lieu de se raréfier. Une prime d'évaluation penche la balance,
   elle ne fait pas le travail de la recherche.
2. **Une Dame se mérite** : le pion doit avoir capturé au moins une fois
   (`PROMOTION_REQUIRES_CAPTURE`), la bataille doit être encore disputée
   (`PROMOTION_CONTESTED_RATIO`), et il n'y a qu'une couronne par camp et par
   bataille (`PROMOTION_ONE_PER_BATTLE`). Sinon le pion promeut quand même — il
   a traversé le plateau — mais en **Cavalier**, qui ne rejoint pas le Château
   Royal.

   *Il y a **deux** boutons, pas un.* Mesuré sur les six promotions dégradées
   d'une campagne : deux échouent seulement sur la capture, deux seulement sur
   le ratio, deux sur les deux. `PROMOTION_CONTESTED_RATIO` a l'air d'être le
   levier principal ; `PROMOTION_REQUIRES_CAPTURE` pèse autant, et il a
   l'avantage de se lire sur le pion plutôt que sur l'état du plateau.
3. **Une Dame faite en cours de série reste en ligne** jusqu'au dernier combat
   (`CampaignRun._enlist_dames`). Si elle tombe, c'est le **pion qu'elle était**
   qui manque au village.

Résultat mesuré : **8 Dames → 2**. Garde-fou : elle ne doit pas devenir
inaccessible, sinon le Château Royal et l'aura redeviennent du contenu mort —
c'est pourquoi la bataille 10 en offre une à la première victoire.

---

## L'IA : une recherche, pas des heuristiques

**Les trois niveaux de jeu sont trois PROFONDEURS de recherche**, pas trois jeux
de règles (`Balance.AI_DEPTH`, [`scripts/battle/battle_search.gd`](scripts/battle/battle_search.gd)).
Un negamax avec élagage alpha-bêta, en approfondissement itératif.

| Niveau | Profondeur | Ce qu'elle voit |
|---|---|---|
| novice | 1 demi-coup | l'ancienne IA heuristique (`battle_ai.gd`), gardée telle quelle. Elle vérifie que sa case d'arrivée n'est pas attaquée mais ne joue jamais la réponse adverse : elle se fait fourcher |
| aguerri | 2 | la réponse immédiate. Elle ne donne plus une pièce |
| expert | 3 | sa réplique : fourchettes, enfilades, échanges à trois temps |

**Pourquoi pas Stockfish.** Le jeu n'est pas une partie d'échecs : plateaux de
5×6 à 8×9, armées quelconques, aucun roi, et la victoire consiste à capturer
toute l'armée adverse — pas à mater. Un moteur d'échecs évalue autour de la
sécurité du roi, et ses bibliothèques d'ouvertures comme ses tables de finale
sont des consultations de positions 8×8 standard : rien n'y est consultable ici.
Ce qui se transporte, et qui est déjà fait, c'est la mécanique.

### Le budget de réflexion est un piège à connaître

`Balance.AI_BUDGET_MS` borne le temps par coup. Le coût d'un coup suit le nombre
de **coups légaux** — donc à la fois les effectifs ennemis **et leur niveau**,
qui fixe les portées. Mesuré sur la dernière bataille :

| Réglage | Coups légaux | Profondeur 3 |
|---|---|---|
| 11 pièces/camp, Nv.6 | 37 | 139 ms |
| 14 pièces/camp, Nv.5 | 37 | **396 ms** — hors du budget de 250 |
| 14 pièces/camp, Nv.4 *(actuel)* | 30 | 195 ms |

Au réglage du milieu, l'IA déclarée experte retombait à la profondeur 2 sans que
rien ne le dise, et à un endroit qui dépendait de la machine. Le budget est
maintenant à 450 ms — le temps de la pause `ai_think_delay`, donc déjà payé, et
la marge pour un téléphone deux fois plus lent que la machine de mesure.

**Toucher aux effectifs ennemis ou à leur niveau, c'est toucher au niveau de jeu
réel de l'IA.**

**Relancer [`tools/ai_probe.tscn`](tools/ai_probe.gd) après toute modification
des effectifs, des portées ou de l'évaluation.**

---

## L'économie : la courbe des récompenses suit celle des coûts

Le réglage le moins intuitif du jeu, et celui qui s'est révélé faux.

Le prix des niveaux monte **géométriquement** ; les récompenses montaient
presque linéairement. Mesuré, cumul des améliorations pour atteindre le niveau
que la campagne prête au joueur, face à ce qu'elle avait versé à ce stade :

| | bataille 3 | bataille 7 | bataille 10 |
|---|---|---|---|
| demandé | 1 130 | 6 810 | 19 090 |
| versé | 930 | 2 810 | 7 030 |

Un facteur deux et demi, qui ne se rattrape pas en jouant mieux : la sonde a dû
rejouer **36 fois** une bataille déjà gagnée pour franchir la seule bataille 7.
Les récompenses vont maintenant de 150 à 5 000. **Aucun coût n'a bougé** —
c'est le rapport entre les deux qui était faux, pas les prix.

Mesure d'arrivée : **la campagne se traverse sans farmer une seule fois**, et
elle finit exactement aux niveaux qu'elle prête au joueur.

**La récompense est celle d'un COMBAT, pas d'une bataille** : une série de trois
combats paie trois fois. Huit batailles sur dix étant des séries, se tromper
là-dessus fausse le calcul d'un facteur deux à trois — ce qu'a fait la première
version de la sonde, dont la première correction des récompenses avait hérité.

⚠️ **Toucher à `upgrade_cost` sans relancer `economy_probe`, c'est rouvrir le
trou.**

Trois choses à savoir avant de retoucher ces chiffres :

- **Deux chiffres à lire, jamais un.** « Combien de replays » dit si la campagne
  est trop chère ; **« combien reste-t-il en poche à la fin »** dit si elle est
  trop généreuse. Une hausse des deux dernières récompenses a été essayée puis
  retirée : elle supprimait tout farm, mais laissait **33 593 or dormants sur
  55 530 encaissés**. Une économie dont on ne dépense que 40 % n'a plus de
  décisions dedans — c'est aussi mauvais qu'un mur, dans l'autre sens.

  *Mais lis ce chiffre en retirant la récompense de la dernière bataille* : elle
  tombe quand il n'y a plus rien à acheter, donc elle gonfle le trésor final
  sans jamais avoir été un choix. Le vrai juge est ce qui reste **avant** elle.
- **Une série demande une RÉSERVE, pas une armée.** Trois combats d'affilée sans
  retour au village : il faut de quoi remplir la charge *à chaque* combat, donc
  `charge × fights` de pièces en caserne. C'est ce que le joueur doit acheter, et
  c'est ce que la sonde n'achetait pas — elle en a conclu à tort que la dernière
  bataille était hors de portée même tout au niveau 10.
- **La sonde distingue trois échecs.** La **corvée** (plus de douze replays pour
  une bataille : franchissable mais indigne), l'**impasse** (plus d'or et plus
  aucune bataille qu'on regagne), et le **plafond** (tout au maximum et ça ne
  passe toujours pas — là, ce n'est plus l'économie, c'est le combat).

---

## Mesurer : la discipline des bancs

Le combat n'a aucune source d'aléa, mais **déterministe ne veut pas dire
représentatif**, et confondre les deux a coûté cher :

- **Un banc chronométré n'est pas une mesure.** Deux bancs lancés sur la même
  position rendaient deux verdicts différents, parce que la recherche coupe au
  temps. Les bancs posent donc `BattleAI.budget_ms = 0` — aucune limite, la
  recherche va au bout de sa profondeur. C'est ce qui les rend lents, et c'est
  le prix d'un oracle. Ils jouent alors contre une IA au moins
  aussi forte que celle du jeu, jamais plus faible : une bataille qu'un banc
  déclare gagnable l'est à coup sûr.
- **Un seul combat n'est pas une mesure non plus.** Sur la bataille 10, baisser
  le *seul* niveau ennemi donnait `NUL, NUL, PERDUE, gagnée` : baisser le niveau
  de l'adversaire faisait perdre le joueur. Un coup différent au troisième tour
  envoie la partie ailleurs. On lit donc un **taux sur plusieurs formations**
  (`tune_probe.VARIANTES`), jamais un tirage.
- **Un banc doit jouer la forme réelle du jeu.** `smoke_test` et `tune_probe`
  jouent *un* combat ; huit batailles sur dix sont des **séries** de deux ou
  trois, où l'ennemi revient entier et le joueur avec ses survivants. C'est la
  définition même de la difficulté du jeu, et aucun des deux ne la mesurait.
  `series_probe` existe pour ça.
- **La politique d'un banc fait partie de la mesure.** La sonde économique s'est
  trompée quatre fois de suite, et chaque fois elle accusait le jeu : elle
  n'achetait que le moins cher (donc jamais le château), ne comptait qu'un
  combat par série, entrait dans une série de trois combats sans réserve, et une
  « correction » de ma part lui a fait acheter de la capacité là où il fallait
  de la qualité. **Le réflexe utile est de relire l'instrument avant de toucher
  aux chiffres du jeu** — les quatre fois, le défaut était là.

| Banc | La question à laquelle il répond | Durée |
|---|---|---|
| `tools/smoke_test.tscn` | est-ce que tout tient encore debout ? (données, économie, règles, série, 10 batailles, écrans) | ~70 s |
| `tools/format_test.tscn` | la géométrie tient-elle sur les huit formats ? **Le seul banc de format qui rende des CHIFFRES** — `resolutions` rend des images, et une image ne casse pas un banc quand elle régresse. Trois cas : le fond, le village, l'intro | ~3 s |
| `tools/hitbox_debug.tscn` | où tombent les zones de clic du village ? (les rectangles sont relevés à l'œil ; aucun banc numérique ne peut dire s'ils couvrent le bon bâtiment) | court |
| `tools/ui_test.tscn` | est-ce que les vrais boutons répondent ? (le codex dit-il encore la vérité, la composition borne-t-elle le placement, la série s'enchaîne-t-elle sans écran de victoire ?) | court |
| `tools/ai_probe.tscn` | combien coûte un coup à chaque profondeur ? | ~7 s |
| `tools/ai_bench.tscn` | est-ce que chercher plus loin fait gagner ? *(mesuré : chaque demi-coup gagne les six duels, dans les deux camps)* | long |
| `tools/tune_probe.tscn` | de combien de niveaux le joueur doit-il dominer ? | ~45 min |
| `tools/series_probe.tscn` | une **série** se joue-t-elle jusqu'au bout, et quel bouton la débloque ? | long |
| `tools/economy_probe.tscn` | la campagne verse-t-elle de quoi se traverser ? | **plusieurs heures** |
| `tools/promo_probe.tscn` | combien de Dames une campagne produit-elle ? | ~3 min |
| `tools/debug_battle.tscn` | pourquoi cette bataille tourne mal ? (trace coup par coup) | court |
| `tools/screenshot.tscn` | à quoi ressemblent les écrans ? (PNG dans `tools/screenshots/`) | ~1 min |
| `tools/resolutions.tscn` | qu'est-ce qui déborde sur les autres téléphones ? | court |

```bash
godot --headless --path . tools/smoke_test.tscn
```

**Godot ne réimporte pas un asset remplacé** quand on lance le jeu en ligne de
commande. Après avoir écrasé un PNG ou un TTF :

```bash
godot --headless --path . --import
```

---

## Import Figma V2

Fichier : `rqEdH4O2R21TuUFv7OUlF7`. Les écrans se lisent avec `get_design_context`
en passant le node-id ci-dessous (le compte connecté a un siège Full, aucun droit
à demander).

⚠️ **Le fichier a TROIS pages, et c'est la DERNIÈRE qui fait foi.**
`get_metadata` sans `nodeId` n'en annonce qu'une ; les autres se découvrent par
`figma.root.children` via `use_figma`. Le designer a rangé le 23/08 tous les
écrans dans une page neuve — **les node-ids des versions précédentes sont
morts**, et un relevé fait sur les anciennes pages parle d'un fichier périmé.

| Page | node-id | Ce qu'elle porte |
|---|---|---|
| **`MAINPROJECT`** | **`410:2`** | **la bibliothèque à jour** — 20 écrans rangés en 7 sections. On travaille ici, et nulle part ailleurs |
| `Écrans triés` | `248:2` | les copies qui portent les **timelines que les originaux n'ont pas**, et le retour du designer `294:2` |
| `KINGS GAMBIT` | `0:1` | la page d'origine : images sources, planche de composants `2:1224`, pièces SVG `32:2`, `KINGSGAMBIT_COIN` `114:2`, `LOGO_STUDIOBNL` `116:573` |

### Les 20 écrans de `MAINPROJECT`

| Section | Écran | node-id | État |
|---|---|---|---|
| 🎬 Intro `420:2` | splash-screen | `410:3` | fait |
| | king-intro-before-dialogue | `410:35` | fait |
| | king-intro-dialogue | `410:71` | fait |
| 🏘️ Navigation `420:3` | village-avec-dame | `410:153` | fait — **corrigé le 23/08** : les quatre casernes portent enfin les noms du jeu, plus la pastille de gemmes et les entrées Boutique / Codex |
| | village-sans-dame | `410:196` | fait (le même écran sans les halos) |
| | chateau-royal-avec-dame | `410:233` | fait — écran plein, remplace la modale |
| | chateau-royal-sans-dame | `410:286` | fait |
| 🗺️ Campagne `420:4` | 02_Campagne | `410:342` | fait — parchemin défilant de 2300 points |
| ⚔️ Combat `420:5` | preparation-bataille-v2 | `410:7227` | fait — l'écran de composition, et le **seul écran clair du jeu** |
| | 04_Bataille_Placement | `410:667` | fait — entrée animée portée |
| | 05_Bataille_Combat | `410:3764` | fait |
| | popup-combat-phase | `410:7190` | fait — c'est le **bandeau de série** ; son entrée a été portée le 23/08, elle était jusque-là calquée à la main sur l'écran de résultat et deux fois trop rapide |
| 🏆 Résultats `420:6` | 06_Bataille_Victoire | `410:5121` | fait — écran plein |
| | 07-bataille-defaite | `410:5430` | fait (même écran repeint en rouge) |
| | 07-bataille-nulle | `410:5551` | fait — peau d'acier, `BattleResult.draw_skin` |
| 📋 Popups `420:7` | mission-popup | `410:5664` | fait — ses **deux** animations sont séparées : l'ouverture, et la réclamation |
| | 09-popup-batiment | `410:7342` | fait — *le code couvre les quatre états dans une seule scène (`building_popup.gd`)*, et leur entrée commune vit dans `Modal` |
| | 10-popup-batiment-verrouille | `410:7488` | fait — cerclé d'or comme la maquette le demande |
| | 11-popup-amelioration | `410:7629` | fait |
| | confirm-upgrade-modal | `410:7769` | fait — `confirm_upgrade.tscn` |
| | 12-popup-donjon-tours | `492:2` | ajouté par le designer pour le prototype Make |
| | **13-popup-guide-pat** | **`499:2`** | **chantier E** — première maquette posée par l'intégration, à retoucher |
| | **14-popup-guide-composition** | **`500:2`** | **chantier E** — idem |
| | **15-popup-guide-aura-dame** | **`500:55`** | **chantier E** — idem |
| | **16-popup-guide-temps-reel** | **`500:108`** | **chantier E** — idem |
| 📖 Codex & Shop `420:8` | codex-popup-v3 | `410:6525` | fait — la v3 réécrit les données, la v1 décrivait un autre jeu (voir ci-dessous) |
| | shop-screen | `410:7061` | fait — cascade d'ouverture et dix illustrations posées le 23/08 — corrigé le 23/08 : légende des quatre coffres, section OR recalibrée, euros grisés, **bloc de coffres gratuits dessiné**. Règles dans [`chantier_h_boutique.md`](chantier_h_boutique.md) |

⚠️ **Deux écrans que la bibliothèque n'a PAS repris** et qui n'existent que sur
les anciennes pages : `preparation-bataille-10-v3` (`330:2`, la préparation plus
le bandeau de la Dame captive) et la planche `12-composants`. Le code de la
bataille 10 s'appuie sur le premier (`battle_prep._build_stake_band`) : ne pas
conclure qu'il a disparu du jeu parce qu'il a disparu de la page.

Inventaire relevé sur la page d'origine `0:1` (`get_metadata`, 47 nœuds de
premier niveau) : **rien d'autre n'y est un écran**. Le reste sont les images
sources posées à côté des frames, et toutes sont déjà en jeu sauf deux, qui
n'appartiennent à aucune frame :

- **La Dame captive** — la pièce derrière des barreaux, dans une arche de
  pierre. C'est l'image centrale de l'histoire. Récupérée dans
  `assets/story/dame_captive.png`, et **désormais affichée** : elle est le
  bandeau d'enjeu de la préparation de la **bataille 10**, la seule que
  `Balance.CAMPAIGN` fasse déclarer `dame` (cf.
  `battle_prep._build_stake_band`). Les neuf autres batailles gardent l'écran
  exactement tel qu'il était.
  *Attention en la ré-exportant* : l'export du nœud arrive avec le fond gris du
  canvas (alpha entièrement opaque) ; c'est l'image SOURCE qu'il faut prendre,
  la seule vraiment détourée. Le PNG du dépôt (800 × 1259, alpha propre) a été
  reversé dans la maquette pour que la frame Figma ne montre pas, elle non
  plus, un fond opaque.
- **Une carte de campagne illustrée** (nœud `209:423`) — **vérifié, et le
  verdict est non.** C'est un `RECTANGLE` à remplissage image : les numéros
  d'étape sont peints DANS le raster, pas sur un calque qu'on masque. Elle ne
  couvre en plus que les batailles 6 à 10. Le jeu trace ses cachets par-dessus
  la carte, et ce sont eux qui disent verrouillé / disponible / gagné : un
  parchemin qui porte déjà ses numéros fige la progression. Il faudrait une
  RE-GÉNÉRATION sans les pastilles, pas un ré-export — c'est demandé dans
  [`figma_prompt_codex.md`](figma_prompt_codex.md). `parchment_map.jpg` reste
  en place jusque-là.

Deux écrans existent dans le jeu **sans avoir jamais été dessinés** : l'écran de
match nul (fabriqué en repeignant la victoire en acier) et la boutique, dont les
règles ne sont pas fixées.

### Le codex décrivait un autre jeu — refait, pas porté

`codex-popup` (194:4) est une encyclopédie défilante de 4 537 points, et sa
forme est bonne : plaque de titre, puces de filtre par pièce, une carte par
pièce, un tableau par niveau, puis les bâtiments et les règles. **Son contenu
contredisait le jeu de bout en bout** :

| Le codex écrit | Le jeu |
|---|---|
| des colonnes **PV** et **ATK** par niveau | ni points de vie ni dégâts — une pièce est debout ou capturée |
| « Charge inflige +50 % de dégâts », « Soigne les alliés adjacents de 10 PV/tour » | aucun soin, aucun dégât |
| « champ quadrillé de 8 cases sur 11 » | de 5×6 à 8×9 |
| « commandes de vitesse ×1, ×2, ×4 » | retirées : rien ne joue à la place du joueur |
| « défaite si votre Roi est vaincu » | il n'y a pas de Roi sur le plateau |
| huit bâtiments (Donjon de Fer, Cathédrale, Académie militaire, Chapelle de soins) | cinq : le Château et quatre casernes |

Le porter tel quel aurait mis des règles fausses sous les yeux du joueur, et
c'est précisément ce que la règle « la maquette apporte l'apparence, jamais les
règles » interdit. **La mise en page a été gardée, les données refaites** :
`codex-popup-v3` (321:2) dans la maquette, [`scenes/village/codex_popup.gd`](scenes/village/codex_popup.gd)
en jeu, et le brief qui manquait dans [`figma_prompt_codex.md`](figma_prompt_codex.md).

**Le codex en jeu ne transcrit rien : il se REGENERE depuis `Balance` à chaque
ouverture.** Mobilité par niveau (`move_description`), capacité de caserne,
coût de recrutement et son pas, prix d'amélioration, poids de déploiement,
tailles de plateau relevées sur `CAMPAIGN`, longueur des séries lue sur
`fights`. Une transcription se décale dès que le jeu bouge — c'est exactement
ce qui avait produit le codex faux. `ui_test` vérifie d'ailleurs qu'aucun des
mots de l'ancienne version (`PV`, `ATK`, `Roque`, `Cathédrale`…) n'y est
revenu.

Trois pièges payés en le portant :

1. **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` sur tout libellé.** Les quatre
   colonnes du tableau se partageaient donc la largeur à parts égales — 67
   unités chacune, mesuré — et la mobilité, seule colonne à en avoir besoin, se
   repliait sur quatre lignes pendant que « 8 » occupait 67 unités. Toute
   colonne à largeur fixe doit repasser explicitement en `SIZE_FILL`.
2. **Le codex ne tient pas dans une modale.** `Modal` ne défile pas ; le codex
   fait 5 549 points. C'est un écran plein avec `ScrollContainer`, comme la
   préparation de bataille — d'où `Router.goto_codex()`.
3. **Les six puces de filtre ne tiennent pas dans 361 points** (404 dans la
   maquette d'origine, ROI compris). La rangée défile horizontalement, et le
   rembourrage des puces est passé de 14 à 10 côté maquette.

### Les animations : le relevé complet, et où elles se cachent

⚠️ **Le relevé ne se fait pas sur la page principale.** Les timelines vivent en
grande partie sur les **copies** de la page « Écrans triés » (`248:2`), pas sur
les originaux. Un relevé fait sur les seize frames de la page principale
concluait « deux écrans animés » — il en manquait quatre, dont la plus riche du
fichier. Passer `get_motion_context` en `recursive` sur **les deux pages**.

Relevé complet (22 frames interrogées) :

| Frame | Timeline | État |
|---|---|---|
| `123:32` king-intro-dialogue | 3 s, 6 nœuds | porté (`king_intro_dialogue.gd`) |
| `169:136` king-intro-before-dialogue | 2,5 s, 1 nœud | porté |
| `348:2` / `343:126` bataille-nulle *(copies identiques)* | 3 s, 7 nœuds | porté (`battle_result._animate_entry`, les trois peaux) |
| `248:406` **préparation** | 2 s, 12 nœuds | porté (`battle_prep._animate_entry`) |
| `248:493` **placement** | 3 s, **17 nœuds** | ⚠️ **PAS porté** — la plus riche du fichier |
| `287:308` placement 2 boutons | 2 s, 1 nœud | pas porté — un fondu au noir |

Tout le reste — campagne, village, château, combat, victoire, défaite, codex,
popups de bâtiment, boutique, mission-popup — n'a **aucune** donnée de mouvement.

**`248:493` est le morceau qui reste** : la grille qui zoome de 1,08, le badge
de tour qui tombe de −80 px avec rebond, le HUD qui glisse de +70 px, le bandeau
qui monte de +200 px, les quatre puces qui éclosent en ressort l'une après
l'autre, et une lueur verte pulsée sur COMBATTRE.

**Pourquoi `287:308` rendait noir à l'export** — la question était ouverte
depuis deux sessions : la frame contient un nœud `Fade-From-Black`, un
rectangle noir plein écran à l'opacité 1 qui s'efface sur les 25 premiers % de
la timeline. L'export statique capture l'image 0, donc le voile. Ce n'est pas un
bug de Figma, et il n'y a rien à réparer.

**La boucle est un artefact d'aperçu**, pas une intention : Figma rejoue
l'entrée en rond faute de savoir qu'elle ne se joue qu'une fois. Ce qui compte,
ce sont les décalages, les durées et les courbes.

**Deux pièges de portage, payés :**

1. **Ne jamais animer la `position` d'un enfant de conteneur.** Le tween se bat
   avec la mise en page — c'est ce qui avait collé le bandeau de série en haut
   de l'écran. `battle_result._slide_in` peut le faire parce que ses blocs ne
   sont PAS dans un conteneur ; `battle_prep` ne le peut pas, et n'y reprend
   donc que les **opacités et les échelles** (que la maquette anime aussi).
   Poser `pivot_offset` **après** la mise en page, jamais à la construction.
2. **Une animation d'entrée rend les bancs de capture menteurs.** Une capture
   prise quatre images après l'instanciation photographie un écran à moitié
   apparu — la préparation ressortait quasiment vide, et j'ai d'abord accusé la
   mise en page. `screenshot.tscn` et `resolutions.tscn` sautent maintenant à la
   fin des tweens (`_finish_animations`, via `get_processed_tweens().custom_step`).
   **Tout nouvel outil de capture doit faire pareil.**

### Quatre pièges d'import, déjà payés

1. **Les halos de la maquette sont des ellipses floutées** (`feGaussianBlur`), et
   Godot n'applique pas les filtres SVG : importés tels quels, ils ne s'allument
   pas. Les reproduire en `GradientTexture2D` radial avec un `CanvasItemMaterial`
   en `BLEND_MODE_ADD` (cf. `village.gd`).
2. **Un PNG exporté depuis Figma n'est pas détouré** : `download_assets` rend le
   nœud *avec le fond de la frame derrière lui*. Redécouper l'alpha après coup
   (cf. `assets/campaign/`), ou ne prendre en image que ce qui porte un filtre
   SVG et redessiner le reste au trait.
3. **Un label ne peut pas être rempli d'un dégradé** sans un shader par glyphe.
   `UiTheme.gold_label()` garde l'or médian à plat, avec l'ombre portée — à 9-19
   points la différence ne se voit pas.
4. **Les polices viennent de la maquette, et le relevé se refait.**
   `assets/fonts` en contient **six** : Inter (variable, tout le jeu),
   **Poppins SemiBold et Bold** (les enseignes), Comic Relief (la voix du Roi),
   Jaro (retirée de l'usage, voir plus bas), Lora (`font_title`, deux usages).

   ⚠️ **Un relevé de polices vieillit.** Celui qui concluait « tout le fichier
   est en Inter, il n'y a rien à faire » portait sur les **anciennes pages** ;
   depuis la réorganisation en `MAINPROJECT`, **Poppins est apparue**. Relevé
   refait, sur les ~600 nœuds de texte de la page :

   | Police | Occurrences | Où |
   |---|---|---|
   | Inter, 6 graisses | 589 | partout |
   | **Poppins Bold 16 / SemiBold 14** | **14** | les deux frames du **village** : les cinq noms de bâtiments, Château Royal, Missions, Codex |
   | ~~Jua Regular 13~~ | 2 | `07-bataille-nulle` — **abandonnée**, voir ci-dessous |
   | Comic Relief | 1 | la voix du Roi, déjà embarquée |

   **Poppins est embarquée**, décision du joueur : « tu utilises les polices de
   Figma, point final ». Pesée avant de décider, comme le veut la règle —
   **SemiBold 150 Ko + Bold 151 Ko = 302 Ko**, l'ordre de grandeur de Lora
   (212 Ko pour deux usages). `UiTheme.font_display()` rend désormais Poppins
   Bold et `font_display_medium()` la SemiBold.

   **Jaro tenait ce rôle et ne sert plus.** Elle n'était référencée qu'aux
   trois endroits que la maquette passe en Poppins. Le fichier reste dans le
   dépôt, sans référence.

   ✅ **Jua est tranchée : abandonnée, c'est la MAQUETTE qu'on corrige.**
   Décision du joueur le 23/08/2026. 2,1 Mo pour **deux mots de 13 points** sur
   le seul écran de match nul — le tiers du poids de toutes les autres polices
   réunies. C'était le seul endroit où « les polices de Figma, point final » se
   heurtait à une mesure, et la mesure a gagné.

   **Aucun code n'a changé** : Jua n'était ni embarquée ni référencée, le jeu
   rendait déjà « ROYAUME » et « CAMPAGNE » en Inter. La correction est
   demandée au designer sur `07-bataille-nulle`.

### Là où la maquette dit autre chose que le jeu

Le jeu gagne, on reprend seulement l'habillage :

1. **Taille du plateau** — la maquette annonce 8×11 cases. Les plateaux vont de
   5×6 à 8×9, pour qu'une case reste cliquable au pouce (45 à 72 points).
2. **« Déploiement : 12/15 unités »**, devenu **« Points: 0/15 »** sur la
   maquette refaite — c'est un **budget de poids**, pas un effectif ni des
   points (Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5). Les écrans disent
   « Charge : 7/16 ».
3. **Noms des bâtiments** — Atelier / Académie / Chapelle / Cathédrale n'existent
   pas. Le jeu a Caserne des Pions, Écuries, Cloître des Fous, Donjon des Tours.
   Les Dames n'ont pas de bâtiment : elles vivent au Château Royal.
4. **Carte de campagne** — la maquette montre neuf cachets et coiffe le médaillon
   d'un « Bientôt disponible ». Le jeu compte **dix** batailles : le médaillon
   EST la bataille 10, et le libellé disparaît.

---

## Repères visuels

**Plaque royale** — la brique de la V2, `scenes/ui/components/royal_plate.gd`.
Rectangle arrondi, dégradé bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé
d'un trait d'or `#ffe680`, doublé d'un filet d'or fin. Tout en sort : panneaux,
cartes d'unité, bannières, boutons, badges de bataille, HUD. Tracée au polygone
coloré par sommet plutôt qu'en `StyleBoxFlat` — StyleBoxFlat ne sait pas remplir
en dégradé, et c'est le dégradé qui donne son relief à la plaque.

| Rôle | Hex |
|---|---|
| Fond général / panels | `#0f111a` · `#161926` · `#262c3f` |
| Bordure | `#3d4f6b` |
| Texte principal / atténué | `#e6ecf5` · `#8fa0b8` |
| Or | `#ffd11a` · `#ffd700` · `#ffe580` |
| Accent joueur (bleu) | `#268cd9` · `#4f86c6` |
| Danger / ennemi | `#c65f5f` · `#b5514f` |
| Succès | `#339940` · `#5fb37a` |

Typographie : **Inter** partout (Black 32 px pour les titres de section, Bold
11-19 px pour les boutons et noms, Semi Bold 10-15 px pour les labels, Regular
8-14 px pour le corps).

Pièces : 18 SVG dans `assets/pieces/` — `bleu/` (joueur), `rouge/` (ennemi),
`absent/` (silhouette grisée). Ce sont les assets finaux, jamais à remplacer par
des placeholders.

---

## Le format d'écran : quatre pièges, tous payés

Le joueur a signalé « des dégradés bizarres » sur son téléphone. Il a fallu
quatre hypothèses fausses avant la bonne. Les voici toutes, parce que chacune
est un piège qui se retendra.

**1. La largeur en unités de jeu ne descend JAMAIS sous 393.** En étirement
`canvas_items` + `expand`, Godot choisit l'échelle sur le plus contraint des
deux axes puis agrandit le viewport. Une fenêtre de 360 × 800 donne un
viewport de **393 × 873** : c'est la HAUTEUR qui varie d'un téléphone à
l'autre, pas la largeur. Un écran qui « casse en 360 de large » casse en
réalité parce qu'il suppose une hauteur.

**2. Un `Control` ordinaire enfant d'un `ScrollContainer` ne s'étire pas.** Il
garde sa taille minimale. `campaign.gd` mesurait la largeur disponible sur ce
`Content` : il lisait donc toujours 393, quelle que soit la fenêtre, et la
carte ne s'élargissait jamais. **Mesurer sur le `ScrollContainer`**, pas sur
son contenu. Ce faux négatif a coûté deux corrections inutiles.

**3. Un dégradé approximé par des bandes RAYE sur un autre format.**
`EdgeFades` empilait 24 rectangles. Les bords de bande sont arrondis au point
près *avant* que l'étirement ne les multiplie par un facteur qui n'est pas
entier : les arrondis tombent entre deux pixels et le dégradé se met à rayer.
Il dessine maintenant de vraies **textures** `GradientTexture2D`, que le GPU
interpole en continu. **Ne jamais revenir à un empilement de bandes.** Au
passage, un fondu en points absolus mange une part croissante d'un écran
court : `EdgeFades.MAX_SHARE` le borne à 9 % du côté.

**4. Un export Figma emporte le fond de la frame — même en JPG.** Le piège est
déjà documenté pour l'alpha des PNG ; `parchment_map.jpg` en était une autre
victime, avec **30 pixels de barre brune cuits dans chaque bord**. Aucune
correction de mise en page ne pouvait les enlever, et ce sont eux que le
joueur voyait. L'image a été recadrée (786 → 726 de large) et le parchemin
passé en étirement exact — en `KEEP_ASPECT_COVERED`, le nouveau rapport
l'aurait rogné en hauteur et **tous les cachets auraient glissé**.

⚠️ **Et le piège de l'instrument, le pire des cinq.** `resolutions.tscn`
testait cinq définitions… qui ont **toutes le même format** (0,45 à 0,46). Il
ne mesurait que la largeur, et ne pouvait structurellement pas voir un
problème de format. Trois tailles hors format ont été ajoutées
(`web-393x700`, `court-360x620`, `tres-long-430x1080`) : **ce sont celles-là
qu'il faut regarder en premier.**

---

## Contraintes techniques

- Godot 4.7, `gl_compatibility`, portrait uniquement.
- Référence 393 × 852 points, `stretch mode canvas_items` / `expand`.
- Safe areas iPhone (encoche haut, barre gestuelle bas) à respecter.
- Exports PNG avec alpha ; pas de flou lourd, pas de particules complexes.
- Repli si la fidélité au pixel prime un jour : passer `window/stretch/aspect`
  de `expand` à `keep` dans `project.godot` — zone de jeu toujours 393 × 852
  exactement, avec des bandes noires sur les écrans plus allongés.
