# KING'S GAMBIT — manuel de bord

Jeu mobile de stratégie fantasy inspiré des échecs, en **Godot 4.7 / GDScript**,
portrait uniquement. Le Roi a perdu sa Dame ; il reconstruit son armée et
enchaîne des batailles pour la retrouver.

Ce fichier est le manuel de l'agent qui arrive sur le projet : ce qu'est le jeu,
où vivent les règles, comment le mesurer, et les pièges déjà payés. Deux autres
documents complètent celui-ci et ne le répètent pas :

- [`README.md`](README.md) — pour un humain : lancer, jouer, régler, tester.
- [`figma_contexte_projet.md`](figma_contexte_projet.md) — pour le designer :
  l'état du jeu vu de la maquette, et les règles de collaboration.

---

## Les quatre règles qui priment sur tout

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
(393 × 852 moins les marges de zone sûre). Convertis : `battle.tscn`,
`campaign.tscn`. Restent à convertir : village, préparation.

---

## Le jeu en un écran

Le joueur **place son armée** face à une formation ennemie qu'il voit, puis
**joue lui-même chaque coup**, une pièce par camp et par tour, jusqu'à ce qu'un
camp n'ait plus rien debout. Ni points de vie ni dégâts : une pièce est sur le
plateau, ou capturée. On capture en se déplaçant sur la case adverse.

Un **anneau rouge** cercle en permanence les pièces prenables au coup suivant.
Sans points de vie, voir l'attaque arriver EST la tension du jeu — aux échecs on
ne ressent pas le danger parce que la position est mauvaise, mais parce qu'on
voit le coup venir.

Un pion mené au bout du plateau devient Dame ; **ramenée vivante**, elle rejoint
le **Château Royal** — le trône vide du début de l'histoire — et redevient
déployable. Entre deux batailles, retour au village : recruter, améliorer.

Ton : fantasy médiéval, mélancolique mais pas sombre — un royaume diminué qui se
reconstruit. Aucune violence graphique.

### La série de combats

À partir de la **deuxième** bataille, un niveau ne se gagne plus en un combat
mais en une **série** — deux d'affilée, puis trois pour les trois dernières,
sans retour au village. Seule la première reste unique : on y découvre le jeu.
La série arrive tôt parce que c'est le **deuxième** combat qui met le joueur en
danger — l'ennemi revient au complet, lui revient avec ses survivants.

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

### Le match nul

Une bataille enlisée se tranche au matériel restant — mais **à égalité stricte,
personne n'a gagné**. Le camp qui mène garde sa victoire. Au nul, les survivants
rentrent, le combat ne rapporte rien, mais **la série n'est pas rompue** : c'est
un tour d'usure payé pour rien, pas une déroute. Un nul au dernier combat achève
la série sans qu'elle soit remportée. L'écran de résultat a une troisième peau
(`BattleResult.draw_skin`) : le décor de la victoire, en acier, sans confettis.

### La Dame : rare à faire, dure à garder

Mesure de départ ([`tools/promo_probe.tscn`](tools/promo_probe.gd)) : douze
promotions par campagne, dont six de ramassage. Trois règles, chacune sur une
cause différente :

1. **L'IA défend sa rangée du fond** — `BattleSearch.PROMOTION_THREAT`. Attention
   au calibrage : à 400 de base, la prime valait quatre pions et poussait les
   deux camps à *courir* au fond plutôt qu'à se battre ; les promotions
   doublaient au lieu de se raréfier. Une prime d'évaluation penche la balance,
   elle ne fait pas le travail de la recherche.
2. **Une Dame ne se gagne que dans une bataille encore disputée**
   (`Balance.PROMOTION_CONTESTED_RATIO`). En dessous, le pion promeut quand même
   — il a traversé le plateau — mais en **Cavalier**, qui ne rejoint pas le
   Château Royal. *C'est le seul bouton à tourner si les Dames redeviennent trop
   fréquentes ou trop rares.*
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

## Mesurer : la discipline des bancs

Le combat n'a aucune source d'aléa, mais **déterministe ne veut pas dire
représentatif**, et confondre les deux a coûté cher :

- **Un banc chronométré n'est pas une mesure.** Deux bancs lancés sur la même
  position rendaient deux verdicts différents, parce que la recherche coupe au
  temps. Les bancs posent donc `BattleAI.budget_ms = 0` — aucune limite, la
  recherche va au bout de sa profondeur. Ils jouent alors contre une IA au moins
  aussi forte que celle du jeu, jamais plus faible : une bataille qu'un banc
  déclare gagnable l'est à coup sûr.
- **Un seul combat n'est pas une mesure non plus.** Sur la bataille 10, baisser
  le *seul* niveau ennemi donnait `NUL, NUL, PERDUE, gagnée` : baisser le niveau
  de l'adversaire faisait perdre le joueur. Un coup différent au troisième tour
  envoie la partie ailleurs. On lit donc un **taux sur plusieurs formations**
  (`tune_probe.VARIANTES`), jamais un tirage.

| Banc | La question à laquelle il répond | Durée |
|---|---|---|
| `tools/smoke_test.tscn` | est-ce que tout tient encore debout ? (données, économie, règles, série, 10 batailles, écrans) | ~70 s |
| `tools/ui_test.tscn` | est-ce que les vrais boutons répondent ? | court |
| `tools/ai_probe.tscn` | combien coûte un coup à chaque profondeur ? | ~7 s |
| `tools/ai_bench.tscn` | est-ce que chercher plus loin fait gagner ? *(mesuré : chaque demi-coup gagne les six duels, dans les deux camps)* | long |
| `tools/tune_probe.tscn` | de combien de niveaux le joueur doit-il dominer ? | ~20 min |
| `tools/economy_probe.tscn` | la campagne verse-t-elle de quoi se traverser ? | long |
| `tools/promo_probe.tscn` | combien de Dames une campagne produit-elle ? | long |
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
à demander). **Tous les écrans du fichier sont à jour**, y compris ceux dont le
nom n'a pas de suffixe `-v2` : le nom de la frame ne dit rien de son âge.

| Écran | node-id | État |
|---|---|---|
| splash-screen | 123:7 | fait |
| king-intro-before-dialogue | 169:136 | fait |
| king-intro-dialogue | 123:32 | fait |
| village-avec-dame / sans-dame | 162:4 / 188:2 | fait (le même écran sans les halos) |
| chateau-royal-avec-dame / sans-dame | 178:5 / 178:51 | fait — écran plein, remplace la modale |
| 02_Campagne | 58:90 | fait — parchemin défilant de 2300 points |
| preparation-bataille-v2 | 169:4 | fait — introduit la plaque royale |
| 04_Bataille_Placement | 49:2 | fait |
| 05_Bataille_Combat | 2:407 | fait |
| 06_Bataille_Victoire | 2:546 | fait — écran plein |
| 07-bataille-defaite | 2:835 | fait (même écran repeint en rouge) |
| mission-popup | 228:9 | à intégrer (le panneau existe côté code) |
| 09 / 10 / 11 — popups de bâtiment | 2:1048 / 2:1115 / 2:1165 | à intégrer |
| confirm-upgrade-modal | 103:15 | à créer |
| codex-popup | 194:4 | à créer |
| 12-composants | 2:1224 | planche de référence |
| Pièces d'échecs SVG | 32:2 | déjà en jeu |

Deux écrans existent dans le jeu **sans avoir jamais été dessinés** : l'écran de
match nul (fabriqué en repeignant la victoire en acier) et la boutique, dont les
règles ne sont pas fixées.

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
4. **Pas de nouvelle police.** Inter (variable), Comic Relief pour la voix du
   Roi, Jaro pour les enseignes, dans `assets/fonts`. Jua avait servi pour un
   seul mot et pesait 2,1 Mo.

### Là où la maquette dit autre chose que le jeu

Le jeu gagne, on reprend seulement l'habillage :

1. **Taille du plateau** — la maquette annonce 8×11 cases. Les plateaux vont de
   5×6 à 8×9, pour qu'une case reste cliquable au pouce (45 à 72 points).
2. **« Déploiement : 12/15 unités »** — c'est un **budget de poids**, pas un
   effectif (Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5). Les écrans disent
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

## Contraintes techniques

- Godot 4.7, `gl_compatibility`, portrait uniquement.
- Référence 393 × 852 points, `stretch mode canvas_items` / `expand`.
- Safe areas iPhone (encoche haut, barre gestuelle bas) à respecter.
- Exports PNG avec alpha ; pas de flou lourd, pas de particules complexes.
- Repli si la fidélité au pixel prime un jour : passer `window/stretch/aspect`
  de `expand` à `keep` dans `project.godot` — zone de jeu toujours 393 × 852
  exactement, avec des bandes noires sur les écrans plus allongés.
