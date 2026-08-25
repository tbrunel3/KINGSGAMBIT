# KING'S GAMBIT — manuel de bord

Jeu mobile de stratégie fantasy inspiré des échecs, en **Godot 4.7 / GDScript**,
portrait uniquement. Le Roi a perdu sa Dame ; il reconstruit son armée et
enchaîne des batailles pour la retrouver.

Ce fichier est le manuel de l'agent qui arrive à froid : ce qu'est le jeu, où
vivent les règles, comment le mesurer, et les pièges déjà payés.

## Où chercher quoi

| Document | Pour qui | Ce qu'il porte |
|---|---|---|
| [`carnet/`](carnet/README.md) | **le travail en cours** | la console qui commande le travail, et la règle principale ci-dessous. **`carnet/etat.json` est la source de vérité** |
| [`README.md`](README.md) | un humain | lancer, jouer, régler, tester |
| [`passation_chantier_j.md`](passation_chantier_j.md) | l'agent suivant | les 22 retours du joueur après ses tests sur téléphone |
| [`figma_reference.md`](figma_reference.md) | **avant de toucher à un écran** | les node-ids des 24 écrans, l'inventaire des animations, le relevé des polices, les pièges d'import |
| [`figma_contexte_projet.md`](figma_contexte_projet.md) | le designer | l'état du jeu vu de la maquette, règles de collaboration |
| `figma_prompt_*.md` | le designer | les briefs, un par écran |
| [`archive/`](archive/) | mémoire | les chantiers **livrés** — leurs mesures sont remontées ici |

⚠️ **Ne pas rouvrir un chantier de `archive/` en croyant qu'il reste à faire.**
Les chantiers C, D, E, G, F, H et I sont livrés. Ce qui reste vit dans le
carnet, et nulle part ailleurs.

---

## ⚠️ LA RÈGLE PRINCIPALE, et elle prime sur l'envie d'avancer

Deux moitiés, et l'une sans l'autre est fausse :

1. **Je ne travaille pas si le joueur n'a pas lancé le travail** — le bouton
   **AU TRAVAIL !** de l'onglet *ordre de marche*. Sans lui, je ne prends aucun
   chantier du carnet de ma propre initiative.
2. **Une fois lancé, je ne m'arrête plus** : je passe sur tous les chantiers en
   boucle, sans attendre les verdicts, **jusqu'à ce qu'il ne lui reste que des
   vérifs et des retouches**. Une fiche livrée passe en `attente`, sort de
   l'ordre de marche, et l'attend.

Deux freins : le bouton **ARRÊTER LE TRAVAIL**, et le **crédit** relevé dans
`etat.json` — sous le seuil, la console dit *PASSATION REQUISE*.

⚠️ **Le crédit ne se relève pas tout seul** : je ne vois mes tokens qu'au début
d'un tour, donc je l'écris après chaque livraison, jamais pendant un chantier.

La console est en trois colonnes (Figma `13:373`, fichier
`YTypQjzEG1JG4w9QZUClVk`) : le rail des registres, les fiches, l'inspecteur.

**Deux adresses, et c'est voulu :**

- l'artefact `https://claude.ai/code/artifact/857ffdc3-e16a-485b-8651-853b31916069`
  — il se republie tout seul à chaque coche ;
- le dépôt `https://tbrunel3.github.io/KINGSGAMBIT/carnet/` via `carnet.py
  enligne` — il ne publie rien, mais **personne ne peut le supprimer**.

⚠️ **L'artefact a été supprimé DEUX fois** (la première avec la seule liste des
22 retours qui existait ; la seconde le 24/08). `carnet/etat.json` a tenu les
deux fois. **Vérifier que l'adresse répond avant de republier.**

⚠️ **Il se republie sous l'identité du joueur quand il coche** : relire la page
publiée et la reverser (`carnet.py recupere`) AVANT de republier, sinon on
écrase ses réponses. La page garde en plus un **miroir dans son navigateur**,
écrit avant chaque publication — c'est lui qui ferme la fenêtre entre sa coche
et ma relecture.

---

## ⚠️ AVANT TOUT : LE DÉPÔT EST-IL À JOUR ?

**Le 25/08/2026, ce dépôt avait 23 commits de retard sans que rien ne le dise.**
Une soirée entière poussée depuis une autre session n'avait jamais été tirée
ici. Résultat : **une journée entière refaite à l'identique, en parallèle**, et
six verdicts du joueur perdus — dont deux messages que personne n'a jamais lus.

La cause n'est pas une faute de manipulation : **être en retard ne se voit pas.**
`git status` dit « working tree clean » quand on est vingt-trois commits
derrière. Il ne parle que du disque, jamais du distant.

D'où [`tools/git_garde.py`](tools/git_garde.py), câblé dans
[`.claude/settings.json`](.claude/settings.json) :

| Garde | Quand | Ce qu'il fait |
|---|---|---|
| `debut` | au démarrage de chaque session | `git fetch`, et **dit** si on est en retard ou en avance. Silencieux si tout va bien |
| `pousse` | après **chaque** `git commit` | pousse tout de suite, pour que la fenêtre de divergence dure des minutes et non une journée |

⚠️ **`pousse` NE FORCE JAMAIS.** Une poussée refusée veut dire que quelqu'un
d'autre a travaillé : c'est une information, pas un obstacle à écraser. La
procédure est alors celle du 25/08 — mettre son travail à l'abri sur une branche
nommée, montrer la divergence au joueur, et **le laisser trancher**.

⚠️ **Le garde est VERSIONNÉ**, exception faite dans `.gitignore` (motif
`.claude/*`, pas `.claude/` — git refuse de ré-inclure un fichier dont le
dossier parent est exclu). Un garde qui ne vit que sur une machine ne protège
pas l'autre, ce qui est précisément le trou qu'il bouche.

⚠️ **Un export Godot peut réécrire `project.godot`.** `--export-release` a
supprimé la section `[input_devices]` — Godot n'écrit pas les valeurs égales au
défaut. Regarder `git diff project.godot` après chaque export.

---

## Les cinq règles qui priment sur tout

**1. Aucune valeur de gameplay hors de [`scripts/data/balance.gd`](scripts/data/balance.gd).**
Tailles de plateau, compositions ennemies, portées, coûts, durées d'animation,
seuils : tout est là. Régler le jeu ne demande pas d'ouvrir l'éditeur.

**2. Figma apporte l'apparence, jamais les règles.** Couleurs, typographie,
illustrations, mise en page, composants viennent de la maquette. Ce qu'on peut
faire dans le jeu, quand, et avec quel effet vient de `scripts/`. Si une frame
montre un écran sans le bouton dont le gameplay a besoin, on garde le bouton et
on l'habille. Si un libellé annonce une règle différente de celle du code,
**c'est le libellé qu'on corrige**.

**3. Rien ne joue à la place du joueur.** Ni résolution automatique, ni vitesse
accélérée, ni formation composée par l'ordinateur. C'est une décision de fond :
le cœur du jeu est que le joueur joue chaque coup. Le moteur sait toujours tenir
les deux camps (`BattleEngine.auto_mode`) — c'est ce dont vivent les bancs, et
ce code habite [`tools/battle_driver.gd`](tools/battle_driver.gd), hors des
scènes de production pour qu'il ne soit pas rebranché « juste pour essayer ».

**4. Ancrer, ne pas positionner.** Un écran posé en coordonnées absolues calées
sur 852 points se décale dès que l'appareil en fait 880. Chaque écran se découpe
en zones ancrées — barre haute fixe, contenu central élastique, bandeau bas
fixe. Cadre utile : **361 × 824** (393 × 852 moins les marges de zone sûre).

✅ Tous les écrans sont convertis depuis le 23/08/2026, intro comprise.

⚠️ **Le piège se retend, et il est contre-intuitif : la largeur ne descend
jamais sous 393, elle MONTE.** En `canvas_items` + `expand`, Godot choisit
l'échelle sur l'axe le plus contraint ; dans un navigateur c'est la **hauteur**
qui manque, la barre d'URL en prenant sa part.

| Mesure | Valeur |
|---|---|
| Viewport réel sur `web-393x700` | **478 × 852** |
| Viewport réel sur `court-360x620` | **495** de large |
| Bande nue à droite des vignettes d'intro, avant correction | **85,34 pt** (web-393x700) et **101,71 pt** (court-360x620) |
| Pivot de zoom faux du même écran | `(196.5, 426)` — la moitié de 393 × 852 en dur |
| Dérive du village avant / après les deux calques | **34 pt → 0,00** sur les huit formats |
| Bouton BATAILLE avant / après | **42 pt hors centre → centré** |

**Un `393` ou un `852` littéral dans du code de mise en page est presque
toujours un bug qui attend un navigateur.**

Le village est le cas particulier : ses étiquettes sont collées à des bâtiments
**peints dans l'illustration**. Il se découpe donc en **deux calques** —
`DecorLayer` suit le rectangle réel du fond, `UiLayer` suit l'écran.
[`tools/format_test.tscn`](tools/format_test.gd) mesure les trois cas (fond,
village, intro) sur les huit formats.

⚠️ **Le calque de décor ne porte PAS l'échelle du fond**, il porte le *rapport*
à la référence (exactement 1,0 en 393 × 852). Lui donner l'échelle (1,22 sur un
écran court) reposerait bien les coordonnées mais rétrécirait le **texte** des
enseignes de moitié — une étiquette a une position en points ET une taille en
points, et seule la première doit suivre l'image. Les deux modes ont été rendus
côte à côte, le joueur a choisi « position seule ».

**5. Ne jamais laisser un chantier sans trace.** Une fenêtre de contexte
s'épuise en plein travail, et l'agent suivant arrive à froid. **Dès que le
crédit ne suffit manifestement plus à finir ce qui est engagé : on s'arrête, on
commit, et on écrit la passation** — dans cet ordre, avant la dernière goutte.

- **Le commit d'abord**, même incomplet, avec un message qui dit ce qui marche
  ET ce qui ne marche pas encore.
- **Puis la passation** : ce qu'est le chantier, ce qui est fait, ce qui reste,
  les décisions déjà prises par le joueur, les pièges payés avec leurs chiffres,
  et les mesures à relancer.
- **Puis le lien dans ce fichier** — une passation que le manuel ne cite pas ne
  sera pas ouverte.
- **Ne jamais garder une mesure pour la fin.** Ce qu'on vient d'apprendre
  s'écrit quand on l'apprend : c'est ce qui est perdu en premier quand la
  fenêtre se ferme d'un coup.

---

## Le jeu en un écran

Le joueur **compose son armée**, la **place** face à une formation ennemie qu'il
voit, puis **joue lui-même chaque coup**, une pièce par camp et par tour, jusqu'à
ce qu'un camp n'ait plus rien debout. Ni points de vie ni dégâts : une pièce est
sur le plateau, ou capturée. On capture en se déplaçant sur la case adverse.

Un **anneau rouge** cercle en permanence les pièces prenables au coup suivant.
Sans points de vie, voir l'attaque arriver EST la tension du jeu.

Un pion mené au bout du plateau devient Dame ; **ramenée vivante**, elle rejoint
le **Château Royal** — le trône vide du début — et redevient déployable. Entre
deux batailles, retour au village : recruter, améliorer.

Ton : fantasy médiéval, mélancolique mais pas sombre — un royaume diminué qui se
reconstruit. Aucune violence graphique.

### Recruter fait une réserve, composer fait une armée

| | Où | Quoi | Plafond |
|---|---|---|---|
| **Recruter** | village | remplit la **caserne** | la capacité du bâtiment |
| **Composer** | préparation | remplit le **déploiement** | `Balance.deploy_capacity` |
| **Placer** | placement | pose sur le plateau | *plus aucun* |

Le joueur trouvait qu'« après le recrutement, rien ne change ». Il avait raison
sur le ressenti et tort sur la cause : le plafond n'a jamais été l'effectif, c'est
la **charge** — au château Nv.1 on pose 16 de charge, et un dixième pion n'entrait
sur aucun plateau. Ce qui manquait était l'étape de **choix**. Poids de
déploiement : Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5.

**La charge se dépense à la composition, une fois.** Le garde-fou du placement
reste dans `battle.gd`, mais une composition valide le rend inatteignable.

La composition vit dans **`CampaignRun.lineup`**, un sous-ensemble du `roster` :

- **Vide = aucune composition**, et le placement retombe sur le roster entier. Ce
  n'est pas un cas d'erreur, c'est le chemin des **bancs**, qui n'ouvrent jamais
  la préparation — et c'est ce qui leur laisse mesurer la même chose qu'avant.
  `smoke_test` déclare toujours **10/10 batailles gagnables**.
- Elle **survit à la série et se réduit des pertes** : au combat 2 l'écran est en
  lecture seule. On ne recompose pas entre deux combats, sinon on remet un écran
  de décision là où le bandeau de série vient d'en enlever un.
- **Les renforts y rentrent** (`CampaignRun._reinforce`) : sans ça, un pion relevé
  entre deux combats serait vivant et impossible à poser.
- Elle est **mémorisée par bataille** (`GameState.remember_lineup`) : la règle 3
  interdit une armée composée par l'ordinateur, pas une décision qu'on repropose.

⚠️ **La préparation n'ouvre plus la série.** Elle monte un `CampaignRun`
*provisoire* et ne le verse qu'au départ du combat (`_commit_lineup`). Appeler
`Game.begin_run` en arrivant sur l'écran effacerait une série entamée sur une
**autre** bataille, juste parce que le joueur est venu regarder celle-ci.

⚠️ **La charge d'un combat se lit sur la SÉRIE, jamais sur le château.** Elle est
**gelée** à l'ouverture (`CampaignRun.capacity`) : sinon, améliorer le Château au
milieu d'une série augmentait la charge des combats suivants pendant que l'armée
ennemie revenait identique — ce qui annule toute l'usure dont vit la série.
`GameState.combat_capacity()` porte la règle ; `battle.gd` et `battle_prep.gd` en
ont chacun leur copie locale (`_capacity()`), et **les trois doivent rester
d'accord**.

**C'est le seul écran clair du jeu** — parchemin crème et panneaux blancs, quand
la carte qui le précède et le placement qui le suit restent en nuit et or. La
rupture a été signalée puis assumée : règle 2.

### La série de combats

À partir de la **deuxième** bataille, un niveau se gagne en une **série** — deux
combats d'affilée, trois pour les trois dernières, sans retour au village. Seule
la première reste unique : on y découvre le jeu. La série arrive tôt parce que
c'est le **deuxième** combat qui met en danger : l'ennemi revient au complet, le
joueur avec ses survivants.

**Une série ne se couronne qu'une fois.** Un combat intermédiaire gagné n'ouvre
pas d'écran de victoire : un bandeau court (`SeriesBanner`) dit où on en est et ce
qu'on a perdu, puis le placement suivant s'ouvre — après `series_banner_seconds`
ou au doigt. Le grand lettrage et l'or restent pour la fin, et la victoire de
série renvoie d'abord à la **carte**. La première série s'explique dans un popup
montré **une seule fois** (`SeriesPopup`, `GameState.has_seen_series_warning`).

`fights` (dans `Balance.CAMPAIGN`) est **le bouton de la durée d'une séance**. Un
combat à la main prend cinq à dix minutes sur les grands plateaux : à cinq
combats, un niveau demandait quarante minutes sans point de sauvegarde. À `1`,
toute la machinerie de série devient invisible.

Trois règles fixent l'enjeu ([`campaign_run.gd`](scripts/core/campaign_run.gd)) :

1. Les pertes ne quittent l'armée du village **qu'à la fin de la série**.
2. Entre deux combats, `Balance.RUN_REINFORCE_WEIGHT` de poids se relève parmi les
   pertes, les moins chères d'abord : **deux pions se relèvent, jamais une tour**.
   C'est ce qui empêche la spirale de la mort.
3. Un combat perdu perd la série et tout l'or promis.

L'armée ennemie est la même à chaque combat mais **ne se range pas deux fois
pareil** (tirage semé sur le numéro du combat). Une série survit à la fermeture du
jeu ; quitter en plein combat le fait recommencer avec l'effectif du départ.

### Les trois façons de finir sans vainqueur

**1. Le PAT** — plus aucun coup légal pour le camp au trait. `stalemate_is_draw`
(`Balance.COMBAT`) décide, et **c'est le seul bouton du jeu qui change de
public** : à `true` *(actuel)* c'est nul et le camp écrasé sauve la partie ; à
`false` le camp bloqué perd, comme au shatranj, et figer l'adversaire devient une
victoire.

⚠️ **Le pat est BEAUCOUP plus fréquent ici qu'aux échecs** : sur cinq colonnes les
pions se bloquent nez à nez en permanence, et un pion ne prend pas tout droit.
Mesuré à `true` : **6 des 19 parties du banc finissent nulles, bataille 1
comprise**, presque toujours parce que l'ennemi est réduit à trois pions bloqués
alors que le joueur mène largement. Ne pas toucher à ce réglage sans relancer
`smoke_test` et lire la colonne des raisons.

**2. La POSITION MORTE** — plus aucune capture possible, jamais. Toujours nulle.
Un cavalier Nv.1 ne saute qu'en diagonale d'une case : il ne quitte jamais la
couleur où il est posé, exactement comme un fou, et deux cavaliers Nv.1 sur des
couleurs opposées se courent après indéfiniment.
`BattleEngine.capture_still_possible()` calcule les portées **sur un plateau
vide** (`MovementRules.reachable_on_empty_board`), donc sur-estimées : elle peut
RATER une position morte, elle ne peut pas en inventer une. Un pion en vie garde
la position vivante — il promeut, et une Dame atteint tout. Annoncé dans le badge,
puis nul après un délai (`dead_position_check_after`, `dead_position_grace`).
Mesuré : **10 activations au lieu des 80** du compteur d'enlisement.

**3. L'ENLISEMENT** — plus aucune prise depuis `stalemate_rounds_manual` tours,
mais des coups restent possibles. Tranché **au matériel restant** ; à égalité
stricte, personne n'a gagné.

Au nul, les survivants rentrent, le combat ne rapporte rien, mais **la série n'est
pas rompue** : un tour d'usure payé pour rien, pas une déroute.

⚠️ **Un nul REJOUE le combat, il ne le consomme pas** — corrigé le 24/08/2026 sur
signalement du joueur. Avant, un nul au dernier combat achevait la série :
`finish_run` effaçait la partie, et **« REPRENDRE LA SÉRIE » en rouvrait une neuve
au combat 1**. Le libellé promettait de reprendre, le code recommençait.

**Le plafond est ce qui l'empêche de devenir un abri.** Sans lui, bloquer la
position permettrait de retenter indéfiniment sans rien risquer — et le pat est
fréquent, 6 des 19 parties. Au troisième nul (`Balance.RUN_DRAWS_ALLOWED`), la
série s'achève sans être remportée. Le compteur vit dans `CampaignRun.draws` et
survit à la sauvegarde.

L'écran de résultat a sa peau (`BattleResult.draw_skin`) et ses assets
(`assets/results/draw_*`, Figma `410:5551`). Il dit aussi **pourquoi** c'est nul —
sans cette phrase, « NUL » ressemble à un bug, et c'en était un.

**Un camp ne passe jamais son tour.** `BattleAI.decide_team` joue dès qu'un coup
existe, et `BattleEngine._pass_turn` signale une erreur au lieu de passer. Le bug
d'origine : l'IA restait plantée en finale (la désespérance était coupée en
dessous de quatre pièces), et le compteur de passes qui devait clore la partie
était remis à zéro par le coup du JOUEUR. **48 passes illégitimes sur 60
parties**, toutes sur les deux batailles en `AI_NOVICE`.

### La Dame : rare à faire, dure à garder

Mesure de départ ([`promo_probe`](tools/promo_probe.gd)) : **douze promotions par
campagne, dont six de ramassage**. Trois règles, chacune sur une cause différente :

1. **L'IA défend sa rangée du fond** — `BattleSearch.PROMOTION_THREAT`.
   ⚠️ **À 400 de base**, la prime valait quatre pions et poussait les deux camps à
   *courir* au fond plutôt qu'à se battre : les promotions doublaient au lieu de
   se raréfier. Une prime d'évaluation penche la balance, elle ne fait pas le
   travail de la recherche.
2. **Une Dame se mérite** : le pion doit avoir capturé au moins une fois
   (`PROMOTION_REQUIRES_CAPTURE`), la bataille doit être encore disputée
   (`PROMOTION_CONTESTED_RATIO`), et il n'y a qu'une couronne par camp et par
   bataille (`PROMOTION_ONE_PER_BATTLE`). Sinon le pion promeut quand même — il a
   traversé le plateau — mais en **Cavalier**, qui ne rejoint pas le Château Royal.
   *Il y a **deux** boutons, pas un* : sur les six promotions dégradées d'une
   campagne, **deux échouent seulement sur la capture, deux seulement sur le
   ratio, deux sur les deux**. `PROMOTION_REQUIRES_CAPTURE` pèse autant que le
   ratio, et il a l'avantage de se lire sur le pion plutôt que sur le plateau.
3. **Une Dame faite en cours de série reste en ligne** jusqu'au dernier combat
   (`CampaignRun._enlist_dames`). Si elle tombe, c'est le **pion qu'elle était**
   qui manque au village.

Résultat mesuré : **8 Dames → 2**. Garde-fou : elle ne doit pas devenir
inaccessible, sinon le Château Royal et l'aura redeviennent du contenu mort —
d'où la Dame offerte à la première victoire sur la bataille 10.

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

**Pourquoi pas Stockfish.** Plateaux de 5×6 à 8×9, armées quelconques, aucun roi,
et la victoire consiste à capturer toute l'armée adverse — pas à mater. Un moteur
d'échecs évalue autour de la sécurité du roi, et ses bibliothèques d'ouvertures
comme ses tables de finale consultent des positions 8×8 standard : rien n'y est
consultable ici. Ce qui se transporte, et qui est déjà fait, c'est la mécanique.

### ⚠️ Le budget de réflexion est un piège à connaître

`Balance.AI_BUDGET_MS` borne le temps par coup. Le coût suit le nombre de **coups
légaux** — donc à la fois les effectifs ennemis **et leur niveau**, qui fixe les
portées. Mesuré sur la dernière bataille :

| Réglage | Coups légaux | Profondeur 3 |
|---|---|---|
| 11 pièces/camp, Nv.6 | 37 | 139 ms |
| 14 pièces/camp, Nv.5 | 37 | **396 ms** — hors du budget de 250 |
| 14 pièces/camp, Nv.4 *(actuel)* | 30 | 195 ms |

Au réglage du milieu, l'IA déclarée experte retombait à la profondeur 2 sans que
rien ne le dise, et à un endroit qui dépendait de la machine. Le budget est
maintenant à **450 ms** — le temps de la pause `ai_think_delay`, donc déjà payé,
et la marge pour un téléphone deux fois plus lent que la machine de mesure.

**Toucher aux effectifs ennemis ou à leur niveau, c'est toucher au niveau de jeu
réel de l'IA.** Relancer [`tools/ai_probe.tscn`](tools/ai_probe.gd) après toute
modification des effectifs, des portées ou de l'évaluation.

---

## L'économie : la courbe des récompenses suit celle des coûts

Le réglage le moins intuitif du jeu, et celui qui s'est révélé faux. Le prix des
niveaux monte **géométriquement** ; les récompenses montaient presque
linéairement. Cumul des améliorations pour atteindre le niveau que la campagne
prête au joueur, face à ce qu'elle avait versé à ce stade :

| | bataille 3 | bataille 7 | bataille 10 |
|---|---|---|---|
| demandé | 1 130 | 6 810 | 19 090 |
| versé | 930 | 2 810 | 7 030 |

Un facteur deux et demi, qui ne se rattrape pas en jouant mieux : la sonde a dû
rejouer **36 fois** une bataille déjà gagnée pour franchir la seule bataille 7.
Les récompenses vont maintenant **de 150 à 5 000**. **Aucun coût n'a bougé** —
c'est le rapport entre les deux qui était faux, pas les prix. Mesure d'arrivée :
la campagne se traverse **sans farmer une seule fois**, et finit exactement aux
niveaux qu'elle prête au joueur.

⚠️ **La récompense est celle d'un COMBAT, pas d'une bataille** : une série de
trois combats paie trois fois. Huit batailles sur dix étant des séries, se
tromper là-dessus fausse le calcul d'un facteur deux à trois — ce qu'a fait la
première version de la sonde.

⚠️ **Toucher à `upgrade_cost` sans relancer `economy_probe`, c'est rouvrir le
trou.** Trois choses à savoir avant de retoucher ces chiffres :

- **Deux chiffres à lire, jamais un.** « Combien de replays » dit si la campagne
  est trop chère ; **« combien reste-t-il en poche à la fin »** dit si elle est
  trop généreuse. Une hausse des deux dernières récompenses a été essayée puis
  retirée : elle supprimait tout farm, mais laissait **33 593 or dormants sur
  55 530 encaissés**. Une économie dont on ne dépense que 40 % n'a plus de
  décisions dedans. *Mais lis ce chiffre en retirant la récompense de la dernière
  bataille* : elle tombe quand il n'y a plus rien à acheter, donc elle gonfle le
  trésor final sans avoir jamais été un choix. Le vrai juge est ce qui reste
  **avant** elle.
- **Une série demande une RÉSERVE, pas une armée.** Trois combats d'affilée sans
  retour au village : il faut `charge × fights` de pièces en caserne. C'est ce
  que le joueur doit acheter, et ce que la sonde n'achetait pas — elle en a
  conclu à tort que la dernière bataille était hors de portée même tout au Nv.10.
- **La sonde distingue trois échecs** : la **corvée** (plus de douze replays pour
  une bataille — franchissable mais indigne), l'**impasse** (plus d'or et plus
  aucune bataille qu'on regagne), et le **plafond** (tout au maximum et ça ne
  passe toujours pas — là, ce n'est plus l'économie, c'est le combat).

---

## Mesurer : la discipline des bancs

Le combat n'a aucune source d'aléa, mais **déterministe ne veut pas dire
représentatif**, et confondre les deux a coûté cher :

- **Un banc chronométré n'est pas une mesure.** Deux bancs sur la même position
  rendaient deux verdicts différents, parce que la recherche coupe au temps. Les
  bancs posent donc `BattleAI.budget_ms = 0` — aucune limite. C'est ce qui les
  rend lents, et c'est le prix d'un oracle. Ils jouent contre une IA au moins
  aussi forte que celle du jeu, jamais plus faible : une bataille qu'un banc
  déclare gagnable l'est à coup sûr.
- **Un seul combat n'est pas une mesure non plus.** Sur la bataille 10, baisser
  le *seul* niveau ennemi donnait `NUL, NUL, PERDUE, gagnée` : baisser le niveau
  de l'adversaire faisait perdre le joueur. On lit un **taux sur plusieurs
  formations** (`tune_probe.VARIANTES`), jamais un tirage.
- **Un banc doit jouer la forme réelle du jeu.** `smoke_test` et `tune_probe`
  jouent *un* combat ; huit batailles sur dix sont des **séries**. C'est la
  définition même de la difficulté du jeu. `series_probe` existe pour ça.
- **La politique d'un banc fait partie de la mesure.** La sonde économique s'est
  trompée quatre fois de suite, et chaque fois elle accusait le jeu : elle
  n'achetait que le moins cher (donc jamais le château), ne comptait qu'un combat
  par série, entrait dans une série de trois sans réserve, et une « correction »
  de ma part lui a fait acheter de la capacité là où il fallait de la qualité.
  **Le réflexe utile est de relire l'instrument avant de toucher aux chiffres du
  jeu** — les quatre fois, le défaut était là.

| Banc | La question à laquelle il répond | Durée |
|---|---|---|
| `tools/smoke_test.tscn` | est-ce que tout tient encore debout ? (données, économie, règles, série, 10 batailles, écrans) | ~70 s |
| `tools/format_test.tscn` | la géométrie tient-elle sur les huit formats ? **Le seul banc de format qui rende des CHIFFRES** — `resolutions` rend des images, et une image ne casse pas un banc quand elle régresse. Trois cas : fond, village, intro | ~3 s |
| `tools/ui_test.tscn` | est-ce que les vrais boutons répondent ? (le codex dit-il encore la vérité, la composition borne-t-elle le placement, la série s'enchaîne-t-elle sans écran de victoire ?) | court |
| `tools/hitbox_debug.tscn` | où tombent les zones de clic du village ? (relevées à l'œil ; aucun banc numérique ne peut dire si elles couvrent le bon bâtiment) | court |
| `tools/ai_probe.tscn` | combien coûte un coup à chaque profondeur ? | ~7 s |
| `tools/ai_bench.tscn` | est-ce que chercher plus loin fait gagner ? *(mesuré : chaque demi-coup gagne les six duels, dans les deux camps)* | long |
| `tools/tune_probe.tscn` | de combien de niveaux le joueur doit-il dominer ? | ~45 min |
| `tools/series_probe.tscn` | une **série** se joue-t-elle jusqu'au bout, et quel bouton la débloque ? | long |
| `tools/economy_probe.tscn` | la campagne verse-t-elle de quoi se traverser ? | **plusieurs heures** |
| `tools/shop_probe.tscn` | la boutique tient-elle ses prix et ses coffres ? | court |
| `tools/promo_probe.tscn` | combien de Dames une campagne produit-elle ? | ~3 min |
| `tools/debug_battle.tscn` | pourquoi cette bataille tourne mal ? (trace coup par coup) | court |
| `tools/screenshot.tscn` | à quoi ressemblent les écrans ? (PNG dans `tools/screenshots/`) | ~1 min |
| `tools/resolutions.tscn` | qu'est-ce qui déborde sur les autres téléphones ? (16 familles d'écrans × 8 formats) | court |
| `tools/generate_theme.tscn` | *(générateur, pas un banc)* régénère les ressources de thème | court |

```bash
godot --headless --path . tools/smoke_test.tscn
```

**Godot ne réimporte pas un asset remplacé** quand on lance le jeu en ligne de
commande. Après avoir écrasé un PNG ou un TTF :

```bash
godot --headless --path . --import
```

### ⚠️ Les quatre façons dont un banc peut mentir

1. **`screenshot.tscn` en `--headless` n'écrit AUCUN fichier, et ne le dit pas.**
   Il démarre, ne rend pas une ligne, sort avec le code 0, et les PNG gardent
   leur date de la veille. Payé le 24/08 : une capture vieille d'un jour lue
   comme fraîche. Il lui faut une **fenêtre** :

   ```bash
   godot --path . tools/screenshot.tscn
   ```

   **Vérifier l'horodatage des PNG avant de conclure sur une capture.**
2. **Une `SCRIPT ERROR` tue la coroutine sans incrémenter un seul échec.** Un
   `find_child` sur un nœud disparu a fait sauter quatre assertions de `ui_test`,
   et le banc a conclu « toutes les interactions répondent correctement ». **Une
   erreur de script dans la sortie d'un banc vert est un échec** — rien ne les
   compte.
3. **Un usage-après-libération SEGFAULTE**, il ne rend pas d'erreur propre. Un
   `queue_free()` posé trop tôt sur le village a tué le banc à la fin de son
   premier cas — mais un essai sur deux allait jusqu'au bout. **Un banc qui ne
   tombe pas deux fois au même endroit lit de la mémoire libérée ; ce n'est pas
   un caprice de machine.**
4. **Une animation d'entrée rend les bancs de capture menteurs.** Une capture
   prise quatre images après l'instanciation photographie un écran à moitié
   apparu — la préparation ressortait quasiment vide, et j'ai d'abord accusé la
   mise en page. Le popup de bâtiment, lui, n'arrive qu'à la fin du zoom : un
   banc qui regarde trois images après le clic conclut que le bouton ne répond
   pas. `screenshot`, `resolutions` et `ui_test` sautent maintenant à la fin des
   tweens (`_finish_animations`, via `get_processed_tweens().custom_step`).
   **Tout nouvel outil de capture doit faire pareil.**

⚠️ **`tools/screenshots/` porte un `.gdignore`, et il DOIT survivre à un clone
neuf.** Sans lui Godot importe les 128 captures comme des textures de jeu :
**44 Mo de cache d'import et plus de cinq minutes de démarrage**. D'où le motif
en deux temps dans `.gitignore` (`tools/screenshots/*` puis
`!tools/screenshots/.gdignore`) — git ne descend pas dans un dossier ignoré.

---

## Figma : les trois avertissements qui restent ici

**La référence complète — node-ids des 24 écrans, inventaire des animations,
relevé des polices, quatre pièges d'import — est dans
[`figma_reference.md`](figma_reference.md).** Elle est sortie du manuel parce
qu'elle ne sert qu'aux sessions d'intégration ; l'ouvrir avant de toucher à un
écran.

Fichier : `rqEdH4O2R21TuUFv7OUlF7`.

⚠️ **Le fichier a TROIS pages, et c'est la DERNIÈRE qui fait foi.**
`get_metadata` sans `nodeId` n'en annonce qu'une ; les autres se découvrent par
`figma.root.children` via `use_figma`. Le designer a rangé le 23/08 tous les
écrans dans **`MAINPROJECT`** (`410:2`) — **les node-ids des versions
précédentes sont morts**, et un relevé fait sur les anciennes pages parle d'un
fichier périmé.

⚠️ **Un relevé de polices ou d'animations VIEILLIT.** Deux relevés ont déjà
conclu à tort — « tout le fichier est en Inter » (Poppins est apparue depuis) et
« deux écrans animés » (il y en a onze, dont un à 24 nœuds). Passer
`get_motion_context` en `recursive` sur **les deux pages**, section par section :
il refuse une page entière.

⚠️ **Un PNG exporté depuis Figma n'est PAS détouré.** `download_assets` rend le
nœud *avec le fond de la frame derrière lui*, alpha entièrement opaque — même en
JPG, où `parchment_map.jpg` avait **30 pixels de barre brune cuits dans chaque
bord**. Redécouper l'alpha après coup, toujours.

### Là où la maquette dit autre chose que le jeu

Le jeu gagne, on reprend seulement l'habillage :

1. **Taille du plateau** — la maquette annonce 8×11 cases. Les plateaux vont de
   5×6 à 8×9, pour qu'une case reste cliquable au pouce (45 à 72 points).
2. **« Points: 0/15 »** — c'est un **budget de poids**, pas un effectif ni des
   points. Les écrans disent « Charge : 7/16 ».
3. **Noms des bâtiments** — Atelier / Académie / Chapelle / Cathédrale n'existent
   pas. Le jeu a Caserne des Pions, Écuries, Cloître des Fous, Donjon des Tours.
   Les Dames n'ont pas de bâtiment : elles vivent au Château Royal.
4. **Carte de campagne** — la maquette montre neuf cachets et coiffe le médaillon
   d'un « Bientôt disponible ». Le jeu compte **dix** batailles : le médaillon EST
   la bataille 10, et le libellé disparaît.

---

## Repères visuels

**Plaque royale** — la brique de la V2, `scenes/ui/components/royal_plate.gd`.
Rectangle arrondi, dégradé bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé
d'un trait d'or `#ffe680`, doublé d'un filet d'or fin. Tout en sort : panneaux,
cartes d'unité, bannières, boutons, badges, HUD. Tracée au polygone coloré par
sommet plutôt qu'en `StyleBoxFlat` — StyleBoxFlat ne sait pas remplir en dégradé,
et c'est le dégradé qui donne son relief à la plaque.

| Rôle | Hex |
|---|---|
| Fond général / panels | `#161926` · `#262c3f` |
| Bordure | `#3d4f6b` |
| Texte principal / atténué | `#e6ecf5` · `#8fa0b8` |
| Or | `#ffd11a` · `#ffd700` · `#ffe580` |
| Accent joueur (bleu) | `#268cd9` · `#4f86c6` |
| Danger / ennemi | `#c65f5f` · `#b5514f` |
| Succès | `#339940` · `#5fb37a` |

Typographie : **Inter** partout (Black 32 px pour les titres de section, Bold
11-19 px pour les boutons et noms, Semi Bold 10-15 px pour les labels, Regular
8-14 px pour le corps).

**Boutons de coin** : un seul composant, `corner_button.gd` — il y avait **six
tailles pour la même chose**, il en reste deux. ⚠️ Le village met ses deux
boutons **côte à côte**, c'est la bataille qui les empile, parce que sa barre
haute porte le badge de tour.

Pièces : 18 SVG dans `assets/pieces/` — `bleu/` (joueur), `rouge/` (ennemi),
`absent/` (silhouette grisée). Ce sont les assets finaux, jamais à remplacer par
des placeholders.

---

## Le format d'écran : cinq pièges, tous payés

Le joueur a signalé « des dégradés bizarres » sur son téléphone. Il a fallu
quatre hypothèses fausses avant la bonne.

**1. La largeur en unités de jeu ne descend JAMAIS sous 393.** Une fenêtre de
360 × 800 donne un viewport de **393 × 873** : c'est la HAUTEUR qui varie d'un
téléphone à l'autre, pas la largeur. Un écran qui « casse en 360 de large » casse
en réalité parce qu'il suppose une hauteur.

**2. Un `Control` ordinaire enfant d'un `ScrollContainer` ne s'étire pas.** Il
garde sa taille minimale. `campaign.gd` mesurait la largeur disponible sur ce
`Content` : il lisait donc toujours 393, quelle que soit la fenêtre, et la carte
ne s'élargissait jamais. **Mesurer sur le `ScrollContainer`**, pas sur son
contenu. Ce faux négatif a coûté deux corrections inutiles.

**3. Un dégradé approximé par des bandes RAYE sur un autre format.** `EdgeFades`
empilait **24 rectangles**. Les bords de bande sont arrondis au point près
*avant* que l'étirement ne les multiplie par un facteur non entier : les arrondis
tombent entre deux pixels et le dégradé se met à rayer. Il dessine maintenant de
vraies textures `GradientTexture2D`, que le GPU interpole en continu. **Ne jamais
revenir à un empilement de bandes.** Au passage, un fondu en points absolus mange
une part croissante d'un écran court : `EdgeFades.MAX_SHARE` le borne à **9 %** du
côté.

**4. Un export Figma emporte le fond de la frame — même en JPG.**
`parchment_map.jpg` avait **30 pixels de barre brune cuits dans chaque bord**.
Aucune correction de mise en page ne pouvait les enlever, et ce sont eux que le
joueur voyait. L'image a été recadrée (**786 → 726** de large) et le parchemin
passé en étirement exact — en `KEEP_ASPECT_COVERED`, le nouveau rapport l'aurait
rogné en hauteur et **tous les cachets auraient glissé**.

**5. ⚠️ Le piège de l'instrument, le pire des cinq.** `resolutions.tscn` testait
cinq définitions… qui ont **toutes le même format** (0,45 à 0,46). Il ne mesurait
que la largeur, et ne pouvait structurellement pas voir un problème de format.
Trois tailles hors format ont été ajoutées (`web-393x700`, `court-360x620`,
`tres-long-430x1080`) : **ce sont celles-là qu'il faut regarder en premier.**

---

## Le tactile : appuyer n'est pas toucher

**Tout le jeu écoute la SOURIS.** Il n'y a pas un seul `InputEventScreenTouch` ni
`InputEventScreenDrag` dans le dépôt. Ça marche au doigt grâce à
`pointing/emulate_mouse_from_touch`, désormais **écrit explicitement** dans la
section `[input_devices]` de `project.godot` — il était laissé à son défaut, donc
vrai par accident et écrit nulle part.

⚠️ **Son coût est réel : un second doigt produit un SECOND appui émulé.** Il
repassait par `_begin_press` et tuait le glissement en cours — paume, doigt qui
traîne, et le geste mourait. C'est réglé dans `grid_view._pointer_down`.

### Le bug des cachets — corrigé le 23/08/2026

`campaign_seal` émettait `pressed` sur l'événement **enfoncé**, et
`campaign._on_node_pressed` enchaîne `_play_transition()`. **Poser le doigt sur un
cachet partait en bataille avant d'avoir bougé** — or la carte est un parchemin de
**2 300 points** qu'on fait défiler, et elle porte dix cachets alignés sur toute
sa hauteur, exactement là où le pouce se pose.

Il fallait **deux** corrections, et l'une sans l'autre ne servait à rien :

1. l'appui n'arme que le geste ; c'est le **relâchement** qui décide, et seulement
   s'il retombe à moins de `TAP_SLOP` (**12 pt**) du point de départ ;
2. `mouse_filter` passe de `STOP` à **`PASS`**. En `STOP`, Godot arrête la
   propagation des événements de bouton vers les parents : le `ScrollContainer` ne
   voyait jamais le geste, et corriger le point 1 seul n'aurait rien fait défiler.

`ui_test` a un cas `[12]` qui pose, glisse, relâche. Son `_press()` sait
désormais échouer (`_pressable()` refuse un contrôle invisible, en
`MOUSE_FILTER_IGNORE`, désactivé ou de taille nulle) et `_envoyer()` choisit
entre le signal `gui_input` et la méthode virtuelle `_gui_input()` en inspectant
les méthodes du script — **émettre le signal n'appelle pas la virtuelle**, et
c'est ce qui faisait qu'il n'appuyait sur rien pour la moitié des contrôles.

### Ce qui reste, et qui n'est PAS fait

- **Le seuil de glissement du combat n'a pas été mesuré au doigt** — mais il n'est
  probablement pas en cause. `grid_view._DRAG_THRESHOLD` vaut **8,0 points**, ce
  qui est exactement le *touch slop* standard d'Android (`ViewConfiguration`,
  8 dp). Ne pas le changer sur une intuition : le combat s'en sort d'autant mieux
  que la sélection se fait sur l'**appui** (`cell_pressed` → `_select_unit`), donc
  un appui tremblé sélectionne quand même. S'il faut y toucher, il faudra un
  relevé sur appareil, pas un raisonnement.
- **Aucun banc ne joue un geste dans le combat.** `[12]` ne couvre que la carte.
- **Les quatre autres `ScrollContainer`** (préparation, codex, boutique,
  showcase) n'ont pas été audités : c'est le même patron de conflit qui peut s'y
  cacher dès qu'un enfant cliquable est en `MOUSE_FILTER_STOP`. *(C'est la fiche
  `d3` du carnet.)*

---

## Le piège des autoloads : ne jamais y nommer un écran

⚠️ **Un autoload qui référence une classe d'interface tire TOUT le graphe des
écrans au démarrage, et le jeu ne se lance plus.** Payé le 24/08/2026 : ajouter
`ConfirmLeave.ask(...)` dans `Router.goto_village()` a suffi. Le nom de classe est
résolu à l'ANALYSE, donc le chargement des autoloads s'est mis à tirer `Modal`,
`UiTheme` et leurs scènes de composants — et plus rien ne démarrait.

**Le symptôme est trompeur** : ce n'est pas une erreur, c'est un blocage. Les
bancs n'affichaient même plus leur première ligne, et la sortie ne montrait que du
bruit de fermeture. Chercher la cause dans le test était une impasse.

Le correctif : `load("res://…/confirm_leave.gd")` **au moment de l'appel**. Un
routeur ne doit rien savoir des écrans avant d'en avoir besoin.

---

## Contraintes techniques

- Godot 4.7, `gl_compatibility`, portrait uniquement.
- Référence 393 × 852 points, `stretch mode canvas_items` / `expand`.
- Safe areas iPhone (encoche haut, barre gestuelle bas) à respecter.
- Exports PNG avec alpha ; pas de flou lourd, pas de particules complexes.
- Repli si la fidélité au pixel prime un jour : passer `window/stretch/aspect` de
  `expand` à `keep` dans `project.godot` — zone de jeu toujours 393 × 852
  exactement, avec des bandes noires sur les écrans plus allongés.
- Le build web (39 Mo de wasm + 17 Mo de pck) est publié depuis la branche
  `gh-pages`, jamais depuis `main`. ⚠️ **`.git` pèse 191 Mo à cause de ces builds
  commités une quinzaine de fois** ; les purger demanderait une réécriture
  d'historique et un force-push, que le garde-fou interdit.
