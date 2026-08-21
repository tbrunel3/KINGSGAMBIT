# King's Gambit — MVP Phase 1

Jeu de stratégie mobile fantasy inspiré des échecs. Le Roi a perdu sa Dame ; il
reconstruit son armée et enchaîne les batailles pour la retrouver.

Cette Phase 1 est un **MVP jouable** : la boucle complète tourne de bout en bout.
Les visuels sont des placeholders assumés — formes simples, lettres, couleurs —
et seront remplacés en Phase 2 à partir des maquettes Figma.

**Moteur : Godot 4.7** (testé sur 4.7.1 stable), GDScript, rendu `gl_compatibility`.
**Cible : iPhone portrait**, interface calée sur 393 × 852 points, safe areas gérées.

---

## Jouer

Trois façons, de la plus rapide à la plus portable.

**1. Exécutable Windows** — `build/windows/KingsGambit.exe`, un seul fichier
autonome, double-clic. Non versionné (109 Mo, au-delà de la limite de fichier
GitHub) : il se régénère avec la commande d'export plus bas.

**2. Dans Godot** — ouvre `project.godot`, puis **F5**. C'est la voie à prendre
pour modifier le jeu.

**3. Navigateur, y compris iPhone** — le dossier `docs/` contient un build web
prêt à publier. Une fois GitHub Pages activé (Settings → Pages → Branch `main`,
dossier `/docs`), le jeu est jouable à l'adresse
`https://tbrunel3.github.io/KINGSGAMBIT/`, au doigt, sans rien installer.
Le build est mono-thread et embarque un manifeste PWA : « Sur l'écran d'accueil »
depuis Safari donne une icône et un affichage plein écran en portrait.

### Le parcours à tester

**BATAILLE** → choisis une bataille → **PRÉPARER L'ARMÉE** → **Auto** (ou choisis
un type et touche les cases de ta zone) → **COMBATTRE**. Puis **tu joues chaque
coup** : touche une pièce, ses déplacements s'allument, touche la case d'arrivée —
ou fais-la glisser directement. L'IA répond avec une de ses pièces, et ainsi de
suite. Le bouton **AUTO** confie les deux camps à l'IA si tu veux juste refaire
de l'or. Retour au village, ouvre un bâtiment, recrute, lance une amélioration :
le compte à rebours continue même jeu fermé.

Mène un pion jusqu'au fond du plateau adverse et **ramène-le vivant** : il
devient une Dame, qui rejoint le **Château Royal** aux côtés du Roi et se
redéploie aux batailles suivantes.

Tu démarres avec **4 pions et un cavalier** : une armée de pions seuls est une
finale d'échecs, ce qui fait le pire des tutoriels. La Caserne des Pions et les
Écuries sont donc ouvertes d'entrée ; le Cloître et le Donjon apparaissent
gratuitement quand le Château Royal atteint le niveau requis (2 et 3).

Le **point i**, à gauche de la croix en haut de l'écran de bataille, écrit les
règles noir sur blanc : la pose et le barème des poids pendant le placement, le
tour par tour, la capture et la promotion pendant le combat.

Le bouton **MISSIONS** de la barre du haut porte le fil rouge du jeu : onze
objectifs qui se déverrouillent **en chaîne** (une mission n'apparaît que
lorsque celles de son `requires` ont été réclamées) et paient en or. Les cinq
premières se suivent une à une et forment le tutoriel — gagner, recruter,
améliorer, enchaîner, gagner proprement. Une pastille dorée sur le bouton
signale les récompenses qui attendent. Le bouton **DEV** (en haut à droite, à la place de l'ancien
RAZ) ouvre un panneau de raccourcis de test : or, déblocages, améliorations
instantanées, et **RAZ** pour effacer la sauvegarde.

### Regénérer les builds

```bash
godot --headless --path . --export-release "Windows Desktop"
```

```bash
godot --headless --path . --export-release "Web"
```

---

## Règles du jeu

Les pièces rappellent les échecs sans en respecter les règles. **Il n'y a ni
points de vie ni dégâts** : une pièce est sur le plateau, ou capturée. On capture
en se **déplaçant sur la case adverse**. Aucune attaque à distance.

| Pièce | Déplacement | Nv.1 | Nv.10 |
|---|---|---|---|
| **Pion** | avance tout droit, capture en diagonale avant | 1 case, ouverture 1 | 2 cases, ouverture 4 |
| **Cavalier** | sauts, ignore les pièces du trajet | petit saut (1,1) | 7 figures, jusqu'à (3,4) |
| **Fou** | diagonales, bloqué par les pièces | 2 cases | 8 cases |
| **Tour** | lignes et colonnes, bloquée par les pièces | 2 cases | 8 cases |
| **Dame** | toutes directions — uniquement par promotion | 2 cases | 9 cases |

Le niveau d'un bâtiment débloque des **capacités**, pas seulement des chiffres.
Le pion niveau 1 avance d'une case et rien d'autre ; dès le niveau 2 il gagne le
**double pas d'ouverture** des échecs — deux cases à son tout premier coup, sans
pouvoir sauter par-dessus quoi que ce soit, puis il reprend son pas normal.
L'ouverture s'allonge encore (3 cases au Nv.5, 4 au Nv.8) et sa portée ordinaire
ne monte qu'au Nv.7. Le cavalier suit la même logique : **petit saut diagonal** au
niveau 1, le L classique au niveau 2, puis des figures de plus en plus longues. La tour et le fou
restent à 2 cases au niveau 1 : à 1 case ils seraient plus faibles qu'un pion,
incapables de riposter à une pièce postée en diagonale.

Une Tour ou un Fou s'arrête devant une pièce alliée, et s'arrête **en prenant**
la première pièce ennemie rencontrée. Un Cavalier saute par-dessus tout.

**Promotion** : un pion qui atteint le fond du plateau adverse devient
**Dame**, comme aux échecs. Elle garde le niveau du pion qui a promu — une Dame
issue d'un pion Nv.1 se déplace donc bien moins loin que celle d'un pion Nv.10.

**Si elle survit à la bataille, elle reste une Dame** : le pion quitte la
caserne et la Dame s'installe au **Château Royal**, sur le trône laissé vide au
premier écran du jeu. Elle se redéploie ensuite comme n'importe quelle autre
pièce, pour **5 de charge de déploiement** — le prix d'une Tour. Sa *valeur* reste 9 : c'est ce que voit l'IA, qui la traite comme la
pièce la plus chère du plateau. Une Dame capturée est perdue comme le pion
qu'elle était.

**L'aura de la Dame** : une Dame **laissée au village** tient la cour pendant que
le Roi se bat et rapporte **+15 % d'or** sur chaque victoire
(`Balance.DAME_GOLD_BONUS`). Le bonus se compte par Dame au repos — en déployer
une renonce à sa part pour cette bataille, pas à celle des autres. C'est tout
l'arbitrage du chip **DAME** au placement : une pièce de plus sur le plateau, ou
l'or qu'elle rapporte en restant à la maison. Au village, le château se met à
**rayonner** tant qu'une Dame au moins est là, et son halo s'élargit un peu à
chaque nouvelle.

**La Dame retrouvée** : la dernière bataille de la campagne s'appelle « La Tour
de la Dame » et en offre une à la **première victoire** (`"dame"` dans
`Balance.CAMPAIGN`). Le Roi a perdu sa Dame au premier écran du jeu ; il la
retrouve au bout de sa quête, même si aucun de ses pions n'a jamais traversé un
plateau. Sans ce filet, une promotion réussie restant un exploit rare, la moitié
du jeu resterait éteinte pour la plupart des joueurs.

**Améliorer les Dames** : elles n'ont pas de bâtiment à elles, donc pas
d'amélioration à payer séparément. Le niveau d'une Dame est **le plus faible du
niveau du Château Royal et du nombre de Dames abritées** : une seule Dame dans
un château Nv.5 reste Nv.1, trois Dames dans un château Nv.3 sont toutes Nv.3.
Il faut donc les deux — un château qui monte et une collection qui grandit — et
aucune Dame n'est jamais dépensée. Une Dame promue en pleine bataille garde, de
son côté, le niveau du pion qu'elle était.

**Les pertes sont définitives.** Une pièce capturée quitte l'armée et devra être
recrutée à nouveau. C'est ce qui donne son poids au placement — et la raison
d'être de l'écran de campagne, qui permet de rejouer une bataille déjà gagnée
pour refaire de l'or (à 40 % de la récompense). Une **garnison minimale** de
3 pions est rendue gratuitement après chaque bataille, sans quoi une armée
balayée sans or rendrait la partie impossible à reprendre.

Un combat se termine quand un camp n'a plus de pièce. Si les deux armées ne
peuvent plus s'atteindre (20 tours complets sans la moindre prise en jeu manuel,
8 en résolution automatique), la victoire va au camp qui conserve le plus de
matériel, à la valeur des pièces — **l'égalité parfaite revient au joueur** dès
lors qu'il a joué ses coups lui-même : perdre une bataille de plusieurs minutes
sur un match nul est une punition que personne ne comprend. Un camp qui n'a aucun coup légal passe son
tour ; deux passes d'affilée et le match est tranché de la même façon.

### Le niveau de jeu de l'IA

Chaque bataille déclare celui de l'**armée ennemie** (`ai` dans
`Balance.CAMPAIGN`). Ces niveaux ne changent aucune règle : ils retirent des
précautions à l'IA, ils ne lui donnent aucun privilège.

| Niveau | Batailles | Ce qu'elle fait |
|---|---|---|
| **Novice** | 1 à 3 | Fonce. Prend tout ce qui passe, même à perte, et avance sans regarder qui couvre la case |
| **Aguerri** | 4 à 7 | Compte ses échanges, préfère les cases sûres, mais ne sauve pas une pièce déjà attaquée |
| **Expert** | 8 à 10 | Joue tout : échanges, fuite des pièces menacées, pions poussés seulement là où un allié peut reprendre |

Le camp du joueur, quand le bouton **AUTO** le confie à l'IA, joue toujours au
niveau Expert : la résolution automatique doit montrer ce que le placement vaut.

### Jouer son tour

Le combat est **tour par tour, une pièce par camp**, comme aux échecs : tu
déplaces une pièce, l'IA répond avec une des siennes. Rien ne tourne pendant que
tu réfléchis.

Deux gestes, tous deux au doigt :

- **Taper** une pièce l'allume — pastilles bleues sur les cases libres où elle
  peut aller, anneaux dorés autour des pièces qu'elle peut prendre. Taper une de
  ces cases joue le coup.
- **Glisser** la pièce jusqu'à sa case fait la même chose d'un seul geste ; la
  case survolée s'allume en or quand le coup est légal.

Le dernier coup joué reste surligné : sur un petit écran, c'est ce qui permet de
voir ce que l'adversaire vient de faire. Pendant le placement, les mêmes gestes
servent à poser (tape), retirer (tape sur une pièce posée) et repositionner
(glisse — deux pièces qui se croisent échangent leur case).

---

## Où régler le jeu

**Tout l'équilibrage est dans un seul fichier : [`scripts/data/balance.gd`](scripts/data/balance.gd).**

| Section | Contenu |
|---|---|
| `UNITS` | mobilité, capacité, valeur, coût de recrutement, coût et durée d'amélioration — **sur 10 niveaux** |
| `CASTLE_DATA` | pièces déployables par niveau de château, coûts et durées |
| `CAMPAIGN` | les 10 batailles : taille de grille, composition ennemie, niveau, récompense |
| `COMBAT` | durées d'animation, seuil d'enlisement, garde-fou d'activations |
| `GARRISON_MINIMUM`, `REPLAY_REWARD_RATIO` | filet de sécurité et rentabilité du farm |
| `UNLOCK_CASTLE_LEVEL` | niveau de château auquel Écuries / Cloître / Donjon apparaissent gratuitement |

Les tableaux sont indexés par niveau : ajouter un niveau = ajouter une valeur à
chaque tableau de la pièce, et augmenter `MAX_LEVEL`. Le banc de test vérifie que
les tailles concordent et que la mobilité ne recule jamais d'un niveau au suivant.

L'habillage (couleurs, arrondis, marges) est isolé dans
[`scripts/ui/ui_theme.gd`](scripts/ui/ui_theme.gd) — le seul fichier à remplacer
pour brancher la direction artistique définitive.

---

## Architecture

Principe directeur : **la logique de jeu ne connaît pas l'affichage**. Tous les
fichiers de `scripts/battle/` sont des objets purs, sans aucun nœud Godot. Ils
sont donc simulables en headless — c'est ce qui permet de jouer les 10 batailles
en une seconde dans le banc de test.

```
project.godot            portrait, stretch canvas_items, 4 autoloads

scripts/
  data/balance.gd        [autoload Balance]     toutes les valeurs de réglage
  core/save_manager.gd   [autoload SaveManager] lecture/écriture JSON dans user://
  core/game_state.gd     [autoload Game]        or, armée, niveaux, progression
  core/router.gd         [autoload Router]      changement de scène + contexte

  battle/battle_unit.gd     une pièce en combat (données pures)
  battle/grid_model.gd      occupation du plateau, zones de déploiement
  battle/movement_rules.gd  déplacements et prises, par type de pièce
  battle/battle_ai.gd       décision d'une activation
  battle/battle_engine.gd   boucle tour par tour, émet des événements
  battle/grid_view.gd       rendu de la grille, flèches d'aperçu, entrées tactiles

  ui/ui_theme.gd         palette et styles (placeholder)
  ui/safe_area.gd        marges d'encoche iPhone

scenes/
  village/village.tscn        village, or, bâtiments, bouton bataille
  village/building_popup.tscn recrutement et amélioration
  battle/campaign.tscn        liste des batailles, rejouables comprises
  battle/battle_prep.tscn     briefing avant combat
  battle/battle.tscn          placement, combat et résultat (une seule scène)

tools/
  smoke_test.tscn        banc de test headless
  ui_test.tscn           appuie sur les vrais boutons du jeu
  debug_battle.tscn      trace une bataille coup par coup
  screenshot.tscn        génération des captures
  resolutions.tscn       le même écran rendu à cinq définitions de téléphone
```

### Vérifier la mise à l'échelle

```bash
godot --path . tools/resolutions.tscn
```

Rend le village, la campagne, la préparation et le placement en 393×852,
360×800, 375×812, 412×915 et 430×932, et enregistre une capture par
combinaison dans `tools/screenshots/echelle/`. C'est la façon la plus rapide de
voir ce qui déborde : le jeu est calé sur 393×852, et en `stretch/aspect =
expand` un téléphone d'un autre format ne redimensionne pas, il **révèle** de la
hauteur en plus (873 points sur un 360×800). Tout ce qui est posé en
coordonnées absolues s'y décale.

### Le point important : moteur et vitesse

Deux entrées pour un même chemin de résolution : `BattleEngine.play_move(unit,
cell)` joue le coup choisi par le joueur, `BattleEngine.step()` demande à l'IA de
choisir **et** de jouer celui du camp courant. Les deux retournent la liste des
événements correspondants (`move`, `capture`, `promotion`, `pass`, `end`), que la
vue rejoue ensuite avec des délais.

Conséquence : **x1, x2, x4 ne modifient jamais le résultat d'un combat.** Ils ne
touchent que les durées d'affichage — et donc uniquement la réponse de l'IA et la
résolution automatique, puisque le reste du temps c'est le joueur qui décide
quand le coup part.

### Trois choix à connaître

- **Une seule scène de bataille**, à trois phases (placement → combat → résultat).
  L'état du placement n'a ainsi jamais à transiter entre deux scènes.
- **Les données d'équilibrage sont des dictionnaires GDScript**, pas des
  ressources `.tres` : éditables dans n'importe quel éditeur de texte, lisibles
  en diff Git, modifiables sans ouvrir Godot.
- **Les améliorations sont stockées comme un timestamp Unix de fin.** Le temps
  passe donc normalement jeu fermé.

---

## Tests

```bash
godot --headless --path . tools/smoke_test.tscn
```

Vérifie la cohérence des tableaux de `balance.gd`, l'économie, le retrait des
pertes, les règles de pièces sur des plateaux montés à la main (le pion ne prend
pas devant lui, la tour ne traverse pas, la promotion se déclenche), puis simule
les 10 batailles et charge les quatre écrans.

```bash
godot --headless --path . tools/ui_test.tscn
```

Appuie sur les vrais boutons : ouvrir un bâtiment, recruter, améliorer, jouer une
bataille du placement à la récompense. 26 vérifications.

```bash
godot --headless --path . tools/debug_battle.tscn
```

Rejoue une bataille coup par coup en imprimant le plateau et chaque activation.
À sortir dès qu'une bataille tourne mal : c'est cette trace qui a révélé que le
fou se faisait prendre gratuitement plutôt que d'accepter un échange perdant.

### Équilibrage vérifié

Le banc de test simule un joueur au niveau de la bataille qu'il affronte. Les 10
batailles sont franchissables, avec des pertes réelles à chaque fois.

Deux compositions sont testées par bataille — une armée variée et une armée de
pions — et il en faut une qui passe. Exiger qu'une composition unique gagne
partout nierait l'intérêt du choix d'armée : contre trois pions, ce sont les
pions qui répondent, et la bataille 1 le démontre.

```
Bataille  1  L Oree du Bois     Nv.1  armee variee    6 vs  3  ->  defaite
Bataille  1  L Oree du Bois     Nv.1  armee pions     6 vs  3  ->  VICTOIRE   4 perdues
Bataille  5  Le Pont Noir       Nv.3  armee variee    9 vs  6  ->  VICTOIRE   3 perdues
Bataille 10  La Tour de la Dame Nv.6  armee variee   13 vs 13  ->  VICTOIRE   8 perdues

Premiere partie (armee de depart, sans recrutement) : 6 vs 3 -> VICTOIRE
```

Le dernier cas est le plus important : il joue la toute première bataille avec
l'armée de départ exacte, sans un seul recrutement. C'est lui qui a détecté que
le premier combat du jeu était perdu.

---

## Fait en Phase 1

- Projet Godot 4 lançable, portrait iPhone, safe areas
- Village : château, 4 bâtiments, compteur d'or, bouton bataille
- Casernes débloquées progressivement : seul le pion au départ, Écuries /
  Cloître / Donjon apparaissent gratuitement aux niveaux 2 / 3 / 4 du château
- Économie : or unique, recrutement au coût croissant, capacité par bâtiment
- 10 niveaux d'amélioration par bâtiment, avec durée réelle et **timer qui
  continue jeu fermé**
- Écran de campagne : batailles débloquées, rejouables à récompense réduite
- Écran de préparation : composition ennemie, récompense, armée disponible
- Grille de taille variable par bataille (5×6 à 8×9), zones de déploiement
- Placement au doigt : poser, retirer, **repositionner en glissant**, Auto,
  Réinitialiser, limite de charge liée au château ; chips de tous les types de
  l'armée, silhouette grisée pour ce qu'on ne possède pas encore
- **Combat joué coup par coup contre l'IA** : une pièce par camp et par tour,
  sélection à la tape ou **glisser-déposer**, coups légaux surlignés, dernier
  coup adverse mis en évidence
- Bouton **AUTO** : l'IA joue les deux camps jusqu'au bout (farm d'or)
- 5 types de déplacement, mobilité liée au niveau, **promotion en Dame**
- **Point i** sur l'écran de bataille : règles, gestes et barème des poids,
  adaptés à la phase en cours
- **La Dame au Château Royal** : une Dame ramenée vivante s'installe auprès du
  Roi, redéployable, et rapporte +15 % d'or par bataille tant qu'elle y reste ;
  le château se met alors à rayonner, fenêtres allumées
- **Pertes définitives** avec garnison minimale de sécurité
- **IA à trois niveaux de jeu**, déclarés par bataille : novice (1-3), aguerri
  (4-7), expert (8-10) — prise la plus rentable, refus des mauvais échanges,
  refus de laisser une pièce en prise sans défense, course à la promotion
- Contrôles x1 / x2 / x4 sans effet sur les règles
- Victoire/défaite, or crédité, bataille suivante débloquée, pertes affichées
- Sauvegarde JSON locale + bouton de remise à zéro
- Trois outils de développement : tests headless, test d'interface, captures

## Reste à faire — Phase 2 (visuelle)

- Remplacer les placeholders par les assets Figma : sprites de pièces, décor du
  village, fond de plateau, icônes de bâtiments
- Animations de capture et de promotion dignes de ce nom
- Sons et retours haptiques
- Carte de campagne illustrée à la place de la liste
- Mise en scène narrative du Roi et de la Dame
- Export iOS

### Limites connues du MVP

- L'IA choisit son coup un tour à l'avance, sans anticiper la réponse : elle ne
  voit pas les fourchettes ni les pièces clouées.
- Le Roi n'est pas une pièce jouable : le château fixe le nombre de pièces
  déployables.
- L'IA ne raisonne qu'à un coup : elle évite une reprise immédiate, mais ne voit
  pas plus loin.
- Aucune migration de sauvegarde : changer `SAVE_VERSION` repart de zéro.
