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
un type et touche les cases vertes) → **COMBATTRE**. Le combat se joue seul,
passe en **x4**. Retour au village, ouvre un bâtiment, recrute, lance une
amélioration : le compte à rebours continue même jeu fermé.

Seule la Caserne des Pions est disponible au tout début. Écuries, Cloître et
Donjon apparaissent gratuitement quand le Château Royal atteint le niveau
requis (2, 3 et 4). Le bouton **DEV** (en haut à droite, à la place de l'ancien
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
| **Pion** | avance tout droit, capture en diagonale avant | 1 case | 4 cases |
| **Cavalier** | sauts, ignore les pièces du trajet | petit saut (1,1) | 7 figures, jusqu'à (3,4) |
| **Fou** | diagonales, bloqué par les pièces | 2 cases | 8 cases |
| **Tour** | lignes et colonnes, bloquée par les pièces | 2 cases | 8 cases |
| **Dame** | toutes directions — uniquement par promotion | 2 cases | 9 cases |

Le cavalier démarre avec un **petit saut diagonal** et n'obtient le L classique
qu'au niveau 2, puis des figures de plus en plus longues. La tour et le fou
restent à 2 cases au niveau 1 : à 1 case ils seraient plus faibles qu'un pion,
incapables de riposter à une pièce postée en diagonale.

Une Tour ou un Fou s'arrête devant une pièce alliée, et s'arrête **en prenant**
la première pièce ennemie rencontrée. Un Cavalier saute par-dessus tout.

**Promotion** : un pion qui atteint le fond du plateau adverse devient
**Dame**, comme aux échecs, **le temps du combat seulement**. Elle garde le
niveau du pion qui a promu — une Dame issue d'un pion Nv.1 se déplace donc
bien moins loin que celle d'un pion Nv.10. De retour au village, elle
redevient le pion qu'elle était.

**Les pertes sont définitives.** Une pièce capturée quitte l'armée et devra être
recrutée à nouveau. C'est ce qui donne son poids au placement — et la raison
d'être de l'écran de campagne, qui permet de rejouer une bataille déjà gagnée
pour refaire de l'or (à 40 % de la récompense). Une **garnison minimale** de
3 pions est rendue gratuitement après chaque bataille, sans quoi une armée
balayée sans or rendrait la partie impossible à reprendre.

Un combat se termine quand un camp n'a plus de pièce. Si les deux armées ne
peuvent plus s'atteindre (8 tours complets sans la moindre prise), la victoire
va au camp qui conserve le plus de matériel, à la valeur des pièces.

### Aperçu des ouvertures

Pendant le placement, une flèche part de chaque pièce vers la case où elle irait
à sa première activation — vertes pour les tiennes, rouges pour l'ennemi, dorées
quand c'est une prise. Chaque pièce est évaluée indépendamment : ce sont les
intentions d'ouverture, pas la séquence exacte du combat.

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
```

### Le point important : moteur et vitesse

`BattleEngine.step()` résout **une activation complète** et retourne la liste des
événements correspondants (`move`, `capture`, `promotion`, `end`). La vue les
rejoue ensuite avec des délais.

Conséquence : **x1, x2, x4 et Pause ne modifient jamais le résultat d'un combat.**
Ils ne touchent que les durées d'affichage. Une bataille est entièrement
déterminée par le placement.

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
- Grille de taille variable par bataille (6×8 à 9×12), zones de déploiement
- Placement au clic, retrait, Auto, Réinitialiser, limite liée au château
- **Aperçu des premiers déplacements** pendant le placement
- Combat automatique tour par tour, capture par déplacement, sans points de vie
- 5 types de déplacement, mobilité liée au niveau, **promotion en Dame**
  (pion → Dame du même niveau, le temps du combat)
- **Pertes définitives** avec garnison minimale de sécurité
- IA modulaire : prise la plus rentable, refus des mauvais échanges, avancée
  sur case sûre quand c'est possible
- Contrôles x1 / x2 / x4 / Pause sans effet sur les règles
- Victoire/défaite, or crédité, bataille suivante débloquée, pertes affichées
- Sauvegarde JSON locale + bouton de remise à zéro
- Trois outils de développement : tests headless, test d'interface, captures

## Reste à faire — Phase 2 (visuelle)

- Remplacer les placeholders par les assets Figma : sprites de pièces, décor du
  village, fond de plateau, icônes de bâtiments
- Drag & drop au placement (le clic-puis-case reste en secours)
- Animations de capture et de promotion dignes de ce nom
- Sons et retours haptiques
- Carte de campagne illustrée à la place de la liste
- Mise en scène narrative du Roi et de la Dame
- Export iOS

### Limites connues du MVP

- La pause ne s'applique qu'entre deux activations, pas au milieu d'une animation.
- Le Roi n'est pas une pièce jouable : le château fixe le nombre de pièces
  déployables.
- L'IA ne raisonne qu'à un coup : elle évite une reprise immédiate, mais ne voit
  pas plus loin.
- Aucune migration de sauvegarde : changer `SAVE_VERSION` repart de zéro.
