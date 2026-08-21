# KING'S GAMBIT — Handoff Figma → Godot 4

Tu arrives sur un projet de jeu mobile King's Gambit, un jeu de stratégie fantasy inspiré des échecs. Le Roi a perdu sa Dame (la Reine) ; il reconstruit son armée et enchaîne des batailles pour la retrouver.

Le joueur place son armée avant le combat, puis **joue lui-même chaque coup contre l'IA**, une pièce par camp et par tour, comme aux échecs (tape ou glisser-déposer). Un bouton AUTO laisse l'IA jouer les deux camps pour rejouer vite une bataille déjà gagnée. Un pion mené au bout du plateau devient Dame ; ramenée vivante, elle rejoint le **Château Royal** — le trône vide du début de l'histoire — et redevient déployable.

À partir de la quatrième bataille, un niveau de campagne ne se gagne plus en un combat mais en **une série** — deux d'affilée, puis trois pour les trois dernières, sans retour au village. Les trois premières restent en un seul combat : on y découvre le jeu. L'armée ennemie revient au complet à chaque combat, le joueur revient avec ses survivants : c'est l'usure qui fait la difficulté, pas une armée qui grossit. L'or n'est versé qu'à la fin de la série, et un seul combat perdu la fait tomber entière.

Le niveau de jeu de l'armée ennemie monte avec la campagne (novice → aguerri → expert, déclaré bataille par bataille dans `Balance.CAMPAIGN`) : les premiers combats doivent être gagnables par quelqu'un qui découvre le jeu. L'armée de départ comprend un cavalier — une armée de pions seuls est une finale d'échecs, donc un mauvais tutoriel — et la dernière bataille offre une Dame à la première victoire.

## L'IA : une recherche, pas des heuristiques

**Les trois niveaux de jeu sont trois PROFONDEURS de recherche**, pas trois jeux de règles (`Balance.AI_DEPTH`, `scripts/battle/battle_search.gd`). Un negamax avec élagage alpha-bêta, en approfondissement itératif sous contrainte de temps.

- **novice = 1 demi-coup** — l'ancienne IA heuristique (`battle_ai.gd`), gardée telle quelle. Elle vérifie que sa case d'arrivée n'est pas attaquée mais ne joue jamais la réponse adverse : elle se fait fourcher. Réservée aux deux premières batailles.
- **aguerri = 2** — elle voit la réponse immédiate. Elle ne donne plus une pièce.
- **expert = 3** — elle voit sa réplique : fourchettes, enfilades, échanges à trois temps.

Deux bancs répondent aux deux seules questions qui comptent, et sont à relancer dès qu'on touche à la taille des plateaux, aux portées ou à l'évaluation :

- `tools/ai_bench.tscn` — est-ce que chercher plus loin fait gagner ? Mesuré : chaque demi-coup supplémentaire gagne **les six duels**, dans les deux camps.
- `tools/ai_probe.tscn` — combien coûte un coup ? Sur le plus grand plateau (8×9, 11 pièces par camp) : profondeur 2 = 10 ms, 3 = 139 ms, 4 = 1 400 ms. **C'est pourquoi l'échelle s'arrête à trois.**

**Pourquoi pas Stockfish, ni aucune base de données d'échecs.** Le jeu n'est pas une partie d'échecs : plateaux de 5×6 à 8×9, armées quelconques, aucun roi, et la victoire consiste à capturer toute l'armée adverse — pas à mater. Un moteur d'échecs évalue autour de la sécurité du roi, et ses bibliothèques d'ouvertures comme ses tables de finale sont des consultations de positions 8×8 standard : rien n'y est consultable ici. Ce qui se transporte, et qui est déjà fait, c'est la mécanique — recherche, élagage, ordre des coups.

## Le match nul

Une bataille enlisée se tranche au matériel restant — mais **à égalité stricte, personne n'a gagné**. Avant, l'égalité était attribuée au joueur en combat manuel : il suffisait de bloquer le plateau et de laisser filer le compteur pour encaisser la récompense pleine.

- Le camp qui **mène** au matériel garde sa victoire : être incapable d'attraper la dernière pièce qui vous fuit ne doit pas effacer un avantage gagné.
- Au nul, les survivants rentrent, les morts restent morts, le combat ne rapporte rien — mais **la série n'est pas rompue**. C'est un tour d'usure payé pour rien, pas une déroute.
- Un nul au **dernier** combat achève la série sans qu'elle soit remportée : consolation seulement, et la bataille suivante ne s'ouvre pas.
- L'écran de résultat a une troisième peau (`BattleResult.draw_skin`) : le décor de la victoire, en acier, sans confettis et sans le grand lettrage.

## La Dame : rare à faire, dure à garder

Trois règles, chacune sur une cause différente. Mesure de départ (`tools/promo_probe.tscn`) : douze promotions par campagne, dont **six de ramassage**.

1. **L'IA défend sa rangée du fond.** Une prime de menace de promotion dans l'évaluation (`BattleSearch.PROMOTION_THREAT`) : sans elle, l'adversaire ne voit le pion que lorsqu'il entre dans l'horizon de recherche, bien trop tard pour aller au-devant. Attention au calibrage — à 400 de base, la prime valait quatre pions et poussait les deux camps à **courir** au fond plutôt qu'à se battre : les promotions doublaient au lieu de se raréfier. Une prime d'évaluation penche la balance, elle ne fait pas le travail de la recherche.
2. **Une Dame ne se gagne que dans une bataille encore disputée** (`Balance.PROMOTION_CONTESTED_RATIO`, la moitié du matériel engagé). En dessous, le pion promeut quand même — il a traversé le plateau — mais en **Cavalier**, qui ne rejoint pas le Château Royal. C'est le seul bouton à tourner si les Dames redeviennent trop fréquentes ou trop rares.
3. **Une Dame faite en cours de série reste en ligne** jusqu'au dernier combat (`CampaignRun._enlist_dames`) : elle ne se met pas à l'abri dès qu'elle est couronnée. Si elle tombe, c'est le **pion qu'elle était** qui manque au village, pas une Dame — il n'y en avait aucune là-bas.

Résultat mesuré sur la campagne : **8 Dames → 2**, les huit autres promotions donnant un Cavalier. Le garde-fou à ne pas perdre de vue : elle ne doit pas devenir inaccessible, sinon le Château Royal et l'aura redeviennent du contenu mort — c'est pourquoi la bataille 10 en offre une à la première victoire.

## La série de combats

`scripts/core/campaign_run.gd` tient l'état d'une série ; `Balance` déclare `fights` par bataille (1 au début, 3 à la fin).

**`fights` est le bouton de la durée d'une séance.** Un combat joué à la main prend cinq à dix minutes sur les grands plateaux : à cinq combats, un niveau demandait quarante minutes d'affilée sans point de sauvegarde en cours de combat — trop long pour un jeu qu'on ouvre sur un téléphone. À `1`, toute la machinerie de série devient invisible : le badge redit « PLACEMENT », la préparation n'annonce pas de série, et la victoire paie et débloque immédiatement. Trois règles fixent l'enjeu :

1. Les pertes ne quittent l'armée du village **qu'à la fin de la série** — une série est une seule unité économique, pas trois batailles côte à côte.
2. Entre deux combats, le joueur relève `Balance.RUN_REINFORCE_WEIGHT` de poids parmi ses pertes, les moins chères d'abord : **deux pions se relèvent, jamais une tour**. C'est ce qui empêche la spirale de la mort.
3. Perdre un combat perd la série, et tout l'or promis avec — il ne reste que la consolation, calculée sur les combats déjà gagnés.

L'armée ennemie est la même à chaque combat, mais **ne se range pas deux fois pareil** (tirage semé sur le numéro du combat) : sans ça, rejouer le même plateau cinq fois d'affilée serait rejouer la même partie. Le premier combat garde le rangement de référence.

Une série survit à la fermeture du jeu et **reprend au combat suivant**. Quitter au milieu d'un combat le fait recommencer, avec l'effectif qu'il avait au départ — pas la série entière.

Un bouton **i** sur l'écran de bataille ouvre l'aide correspondant à la phase en cours (pose et barème des poids ; tour par tour, capture et promotion). C'est le seul endroit du jeu où les règles sont écrites.

Ton : fantasy médiéval, mélancolique mais pas sombre. Aucune violence graphique.

## Import V2 : où on en est

Fichier Figma : `rqEdH4O2R21TuUFv7OUlF7`. Les écrans se lisent avec
`get_design_context` en passant le node-id ci-dessous (le compte connecté a un
siège Full sur l'équipe, aucun droit à demander).

**Tous les écrans du fichier sont à jour, y compris ceux dont le nom n'a pas
de suffixe `-v2`.** Le nom de la frame ne dit rien de son âge : `04_Bataille_
Placement`, `06_Bataille_Victoire`, `09-popup-batiment` et les autres ont été
retravaillés au même titre que `preparation-bataille-v2`. Il n'y a pas de
maquette V1 restante à trier — ce que montre Figma aujourd'hui fait foi.

| Écran | node-id | État |
|---|---|---|
| splash-screen | 123:7 | **fait** |
| king-intro-before-dialogue | 169:136 | **fait** (nouvel état d'approche) |
| king-intro-dialogue | 123:32 | **fait** (révision du 21/08 incluse) |
| village-avec-dame | 162:4 | **fait** |
| village-sans-dame | 188:2 | **fait** (c'est le même écran sans les halos) |
| chateau-royal-avec-dame | 178:5 | **fait** — écran plein, remplace la modale |
| chateau-royal-sans-dame | 178:51 | **fait** (même écran, illustration du trône vide) |
| 02_Campagne | 58:90 | **fait** — parchemin défilant de 2300 points |
| preparation-bataille-v2 | 169:4 | **fait** — introduit la plaque royale |
| 04_Bataille_Placement | 49:2 | à faire |
| 05_Bataille_Combat | 2:407 | à faire |
| 06_Bataille_Victoire | 2:546 | **fait** — écran plein, remplace la modale |
| 07-bataille-defaite | 2:835 | **fait** (même écran repeint en rouge) |
| mission-popup | 228:9 | à faire (le panneau existe déjà côté code) |
| 09-popup-batiment | 2:1048 | à faire |
| 10-popup-batiment-verrouille | 2:1115 | à faire |
| 11-popup-amelioration | 2:1165 | à faire |
| confirm-upgrade-modal | 103:15 | à créer (pas de code aujourd'hui) |
| codex-popup | 194:4 | à créer |
| 12-composants | 2:1224 | planche de référence |
| Pièces d'échecs SVG | 32:2 | déjà en jeu |

Quatre pièges rencontrés, à ne pas redécouvrir :

1. **Les halos de la maquette sont des ellipses floutées** (`feGaussianBlur`).
   L'import vectoriel de Godot n'applique pas les filtres SVG : importés tels
   quels, ils ne s'allument pas. Les reproduire en `GradientTexture2D` radial
   avec un `CanvasItemMaterial` en `BLEND_MODE_ADD` (cf. `village.gd`).
2. **Godot ne réimporte pas un asset remplacé** quand on lance le jeu en ligne
   de commande. Après avoir écrasé un PNG ou un TTF, lancer
   `godot --headless --path . --import` avant toute capture.
3. **Polices** : Inter (variable, toutes les graisses dans un fichier), Comic
   Relief (la voix du Roi) et Jaro (les enseignes) sont dans `assets/fonts`.
   La maquette utilise aussi **Jua** pour le bouton Missions — 2,1 Mo pour un
   seul mot, remplacé par Jaro.
4. **Un PNG exporté depuis Figma n'est pas détouré** : `download_assets` rend
   le nœud *avec le fond de la frame derrière lui*. Les cachets de la campagne
   sont donc arrivés en carrés opaques bruns. Il faut redécouper l'alpha après
   coup (cf. le disque et l'ombre portée reconstruits dans
   `assets/campaign/`) — ou ne prendre en image que ce qui porte un filtre SVG
   et redessiner le reste au trait.

## V2 Figma : la maquette est VISUELLE, le gameplay vient du code

**Règle absolue de l'import : Figma apporte l'apparence, jamais les règles.**
Couleurs, typographie, illustrations, mise en page, hiérarchie visuelle,
composants : tout ça se prend dans la maquette. Le comportement du jeu — ce
qu'on peut faire, quand, avec quel effet — reste celui de `scripts/` et de
`balance.gd`, quoi qu'en dise le fichier Figma.

Concrètement : si une frame montre un écran sans le bouton dont le gameplay a
besoin, on garde le bouton et on l'habille au style de la maquette. Si un
libellé de la maquette annonce une règle différente de celle du code, c'est le
libellé qu'on corrige, pas la règle.

Les points où la maquette V2 dit autre chose que le jeu — et où c'est donc **le
jeu qui gagne**, en reprenant seulement l'habillage :

1. **Écran Combat** — la maquette dit « pas de panneau de contrôle, le joueur
   observe le combat automatique ». Le combat se joue désormais **coup par
   coup au doigt** : l'écran a besoin de son bandeau (« À toi de jouer », AUTO,
   vitesses) et du point i.
2. **Taille du plateau** — la maquette annonce 8×11 cases. Les plateaux vont de
   5×6 à 8×9, volontairement réduits pour qu'une case reste cliquable au pouce
   (45 à 72 points de côté). 8×11 rendrait les cases trop petites.
3. **« Déploiement : 12/15 unités »** — ce n'est pas un nombre d'unités mais un
   **budget de poids** (Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5). Le libellé
   doit parler de charge, pas d'effectif. Appliqué : la préparation et le
   placement disent tous les deux « Charge : 7/16 ».
4. **Noms des bâtiments** — la maquette parle d'Atelier, Académie, Chapelle,
   Cathédrale. Le jeu a Caserne des Pions, Écuries, Cloître des Fous, Donjon des
   Tours. Les Dames ramenées vivantes n'ont pas de bâtiment : elles vivent au
   Château Royal, comme le montrent les frames chateau-royal-avec-dame et
   chateau-royal-sans-dame.
5. **Village avec / sans Dame** — les deux états existent bien dans le jeu : la
   différence se joue sur le **halo doré du Château Royal** et ses fenêtres
   allumées, exactement comme dans la maquette.
6. **Carte de campagne** — la maquette montre neuf cachets et coiffe le
   médaillon du sommet d'un « Bientôt disponible ». Le jeu compte **dix
   batailles**, et la dixième est justement la Tour de la Dame : le médaillon
   EST la bataille 10, et le libellé disparaît. La maquette n'écrit pas non
   plus les noms de bataille sur la carte — le jeu suit, ils s'affichent à la
   préparation.

Écrans de la maquette qui n'existent pas encore côté code : Codex du Royaume,
modale de confirmation d'amélioration, écran plein Château Royal. Ceux-là sont
à créer, et comme ils n'ont pas de gameplay derrière, la maquette y fait
autorité de bout en bout. Le popup des missions, lui, existe déjà et suit la
maquette (liste, progression, RÉCLAMER).

## Contraintes techniques

- Godot 4 (gl_compatibility), portrait uniquement
- Résolution de référence : 393 × 852 points (iPhone), stretch mode canvas_items / expand
- Safe areas iPhone (encoche haut + barre gestuelle bas) à respecter

### Mise en page : ancrer, ne plus positionner (règle pour la V2)

Les écrans actuels sont posés en **coordonnées absolues** calibrées pour exactement 393 × 852. C'est la cause du « scale bizarre » constaté sur téléphone : en `stretch/aspect = expand`, la zone de jeu réelle fait 393 × 880 ou 405 × 852 selon l'appareil, et tout ce qui était calé sur 852 se retrouve décalé. La zone sûre retire en plus 16 points de chaque côté — un élément posé à `x:333` d'une largeur de 60 sort de l'écran.

**Pour le prochain import Figma, chaque écran doit être découpé en zones ancrées** plutôt qu'en positions fixes :

- une barre haute ancrée en haut, de hauteur fixe ;
- un contenu central qui prend **toute la place restante** (hauteur variable) ;
- un bandeau bas ancré en bas, de hauteur fixe.

Les marges, les tailles de composants et les rayons restent figés ; seule la hauteur du milieu est libre. Les maquettes doivent donc être dessinées dans un cadre utile de **361 × 824** (393 × 852 moins les marges de zone sûre), ou fournir les positions en pourcentages.

Écrans déjà convertis : `battle.tscn` (grille, croix, bandeau du bas ancrés) et `campaign.tscn` (carte centrée sur sa largeur de maquette, bouton du bas ancré en bas dans la zone sûre). Restent à convertir : village, préparation.

Solution de repli si la fidélité au pixel prime : passer `window/stretch/aspect` de `expand` à `keep` dans `project.godot` — la zone de jeu fait alors toujours 393 × 852 exactement, avec des bandes noires sur les écrans plus allongés.
- Exports : sprites/textures PNG avec alpha, pas de blur lourd ni particules complexes

## Assets fournis

### Pièces d'échecs — SVG (dans pieces/)

Chaque pièce existe en 3 variantes :
- `bleu/` = joueur (allié)
- `rouge/` = ennemi
- `absent/` = grisé/fantôme (slot vide, pas encore recruté)

Fichiers par dossier : `roi.svg`, `dame.svg`, `cavalier.svg`, `fou.svg`, `tour.svg`, `pion.svg`

18 SVG au total. Utilise-les comme Sprite2D ou TextureRect dans Godot.

### Backgrounds — PNG (dans backgrounds/)

| Fichier | Usage | Dimensions originales |
|---|---|---|
| village_background.png | Fond de l'écran Village (01) | 393×852 |
| battlefield_background.png | Fond des écrans Placement (04) et Combat (05) | 393×852 |
| parchment_map.jpg | Fond de la carte de campagne (02), dans `assets/campaign/` | 786×4600 (2×) |

### Screenshots des écrans (dans screens/)

PNG @2x de chaque écran Figma — utilise-les comme référence visuelle pour reproduire l'UI.

## Palette de couleurs

### Couleurs globales

| Rôle | Hex |
|---|---|
| Fond général / panels | #0f111a |
| Panel foncé | #161926 |
| Panel moyen | #262c3f |
| Bordure | #3d4f6b |
| Texte principal | #e6ecf5 / #f0f3f8 |
| Texte atténué | #8fa0b8 / #a0aabf |
| Or / accent doré | #ffd11a / #ffd700 / #d4af37 |
| Or foncé (texte sur or) | #331f00 |
| Bouton or | #c59b27 |
| Accent joueur (bleu) | #268cd9 / #4f86c6 |
| Danger / ennemi | #c65f5f / #b5514f |
| Succès / gagné | #339940 / #5fb37a |

### Couleurs par pièce

| Pièce | Hex joueur | Hex ennemi |
|---|---|---|
| Pion | #4f86c6 | #b5514f |
| Cavalier | #c96f4f | — |
| Fou | #8f6fc6 | — |
| Tour | #6f9f5f | — |
| Dame | #d8a0d0 | — |
| Roi | #c6a84f | — |

## Typographie

Tout est en Inter (Google Fonts, gratuite). Poids utilisés :
- Inter Black (32px) — titres de section composants
- Inter Bold (11-19px) — noms de bâtiments, boutons, titres
- Inter Semi Bold (10-15px) — status bar, labels, pills
- Inter Medium (11px) — texte secondaire, progression
- Inter Regular (8-14px) — descriptions, texte body

## Les 12 écrans

### 01_Village (écran d'accueil)

- Background : village_background.png avec overlay noir semi-transparent + fondus sur les 4 bords (gradient linéaire noir→transparent)
- Status bar : heure iOS (9:41), icônes status
- Top bar (y:38, h:46) : pills noires arrondies (radius 10) contenant or/niveau/gemmes + bouton settings rond (radius 14)
- Fondu sous la top bar (gradient noir)
- Labels bâtiments : 5 labels positionnés sur la map
  - "CHÂTEAU ROYAL" (x:120, y:445) — texte or #ffd933, fond #0a0d14, radius 14, bordure 1.5px
  - "Caserne des Pions" (x:20, y:272) — texte blanc, même style
  - "Écuries" (x:258, y:272)
  - "Cloître des Fous" (x:30, y:542)
  - "Donjon des Tours" (x:248, y:542)
  - Chaque label a un sub-frame avec pill de niveau + barre de progression (effectif/max)
  - Label verrouillé (x:50, y:685) : "🔒 Forge" grisé + "Château Nv.6 requis" en petit
- Bouton BATAILLE (x:87, y:748, w:219, h:59) : fond or #ffd11a, radius 18, stroke 2px, texte "⚔ BATAILLE" noir 19px bold
- **Code actuel** : quatre bâtiments et le château, pas de Forge et pas de bâtiment pour la Dame — elle vit au Château Royal.
- **Halo du Château Royal** : dès qu'une Dame est rentrée, un dégradé radial doré en mélange additif respire sous les enseignes et les fenêtres du château s'allument (positions relevées sur la maquette V2). L'enseigne du château affiche alors le nombre de Dames et l'or qu'elles rapportent (+15 % chacune).
- Bouton DEV (x:362, y:14) : discret, 24×24, radius 4, emoji 🛠

### 02_Campagne (carte de progression)

Refaite d'après la maquette V2 : ce n'est plus un parchemin d'un écran mais une
**carte de 393 × 2300 points qui défile**, du bas — l'Orée du Bois — vers le
haut, où la Tour de la Dame attend en médaillon.

- Fond : `assets/campaign/parchment_map.jpg`, une seule image de 786 × 4600
  (le cadre entier rendu à 2×, bords sombres compris). Le parchemin, les
  montagnes, les forêts **et les cinq scènes de bataille** de la maquette y
  sont déjà fondus — les scènes étaient des calques en `mix-blend-multiply`,
  elles ont été cuites dans la texture plutôt que reposées à l'exécution : une
  texture au lieu de six, et aucun mode de fusion à régler
- Chemin : `assets/campaign/path.svg`, le tracé en pointillés de la maquette,
  posé tel quel (dessiné à la main, il ne s'interpole pas)
- Cachets (`campaign_seal.gd`) : trois états repris des frames `level-N-seal`
  — cire pâle *gagnée*, cire d'or vif *disponible*, plomb piqué de rouille
  *verrouillé*. Le fond de cire vient d'un PNG (dégradé + ombre portée + ombre
  interne, trois filtres SVG que Godot n'applique pas) ; anneau intérieur,
  gouttes de cire et rouille sont dessinés au trait
- Dernière bataille : pas un cachet mais un **médaillon** de 160 points, disque
  sombre cerclé d'or, la tour gravée au centre, avec un halo additif qui
  respire dès qu'elle est jouable
- Bouton du bas : « ⛨ RETOUR CHÂTEAU », pleine largeur, fond `#261a0d` à 90 %,
  radius 14, bordure `#99804d`. La maquette le pose à la fin du parchemin ; le
  jeu le garde **flottant et ancré en bas**, sinon il disparaît dès qu'on
  remonte le chemin — en échange il s'efface quand on lit la carte
- La carte s'ouvre sur la bataille en cours, pas sur le bas du parchemin

### 03_Preparation_Bataille (briefing)

Refait d'après `preparation-bataille-v2` (169:4), qui change la **peau** sans
changer le propos. C'est cet écran qui introduit la **plaque royale**, la
brique visuelle de la V2 : un rectangle arrondi rempli d'un dégradé bleu nuit
(`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un trait d'or épais `#ffe680`, et
doublé à l'intérieur d'un filet d'or fin `rgba(255,215,0,.31)` posé exactement
sur la zone de contenu.

- Composant : `scenes/ui/components/royal_plate.gd` (`RoyalPlate`, un
  `MarginContainer` qui se dessine). Tout en sort — panneaux, cartes d'unité,
  bannière rouge, bouton retour, pastille PRÊT, coque dorée du bouton d'action
  — en changeant seulement couleurs, rayon et épaisseur. Tracé au polygone
  coloré par sommet plutôt qu'en `StyleBoxFlat` : StyleBoxFlat ne sait pas
  remplir en dégradé, et c'est le dégradé qui donne son relief à la plaque
- En-tête : bouton retour 52×52 (bord 3,5px, biseau intérieur) + plaque de
  titre pleine largeur, sertie d'un **losange** à cheval sur sa tranche haute
- Panneau ennemi : bannière « ARMÉE ENNEMIE » en dégradé horizontal rouge,
  puis une carte par type présent (pièce, `Nom ×N`, niveau)
- Panneau joueur : « TON ARMÉE » + la **charge**, et une carte par type de
  l'armée — `PRÊT` en pastille bleue si le joueur en possède, `RÉSERVE` grisée
  sinon. Un bâtiment pas encore apparu au village n'affiche pas de niveau
  plutôt qu'un « Nv.0 » faux
- Panneau de l'enjeu : récompense (avec la pièce `kg_coin`), aura des Dames au
  repos, taille du terrain, et la mention « bataille déjà gagnée »
- Bouton d'action : une coque d'or sertie autour d'un bouton bleu — deux
  plaques imbriquées
- **Texte d'or** : la maquette remplit ses mots d'un dégradé. Godot ne sait pas
  peindre un `Label` en dégradé sans un shader par glyphe, dont le rendu dépend
  de la hauteur de chaque lettre ; `UiTheme.gold_label()` garde donc l'or médian
  à plat, avec l'ombre portée de la maquette. À 9-19 points, la différence ne se
  voit pas

### 04_Bataille_Placement

- Background : battlefield_background.png + overlay noir semi-transparent + fondus 4 bords
- Grille (x:17, y:155, w:360, h:496). **La maquette montre 10 × 16 cases ; le code n'utilise pas ces chiffres** : la taille vient de `Balance.CAMPAIGN` (5×7 pour la première bataille, jusqu'à 8×9 pour la dernière) et la taille de case est calculée à partir de la place disponible. Des plateaux réduits sont indispensables depuis que le joueur joue chaque coup au doigt — une case fait alors 45 à 72 points de côté
  - Zone bleue joueur (dernières rangées) : fond bleu opacity 0.28, bordure bleue pointillée 2.5px
  - Zone rouge ennemi (premières rangées) : fond rouge opacity 0.28, bordure rouge pointillée 2.5px
  - Nombre de rangées de déploiement : `Balance.DEPLOY_ROWS` (2)
- Tour-Badge (x:12, y:52, w:169, h:35) : fond bleu #268cd9, radius 12, stroke 1.5px — "PLACEMENT — Tour 0"
- Stats-HUD (x:333, y:390, w:56, h:67) : fond #0d0f1a, radius 12, stroke 1px — compteurs ennemis/alliés
- Control-Panel (y:635, h:189, fond #0f121f) :
  - Header row : "Sélectionne tes unités" texte
  - Chips row : un chip par type possédé (Pion, Cavalier, Fou, Tour — plus Dame si le joueur en a une en réserve) avec icône + compteur
  - Buttons row : "AUTO", "RÉINITIALISER", "COMBATTRE" (or)
  - Gestes : tape une case de la zone bleue pour poser, tape une pièce posée pour la reprendre, glisse-la pour la repositionner (deux pièces qui se croisent échangent leur case)

### 05_Bataille_Combat

- Même grille et background que 04 (identique pour transition fluide)
- Tour-Badge (x:12, y:52, w:86, h:41) : fond or #ffd11a, radius 14, stroke 1.5px — "TOUR 1"
- Stats-HUD (x:333, y:390, w:52, h:73) : compteurs "×6 / ×7"
- Control-Panel (y:747, h:77, fond #111319) :
  - Separator line
  - **Code actuel** : "À toi de jouer" / "L'ennemi joue…", bouton AUTO (bascule en MANUEL quand il est actif) et vitesses (×1/×2/×4). Pas de PAUSE ni de FIN TOUR : le combat attend déjà le joueur entre deux coups
  - Coups légaux de la pièce sélectionnée : pastille bleue sur une case libre, anneau doré autour d'une pièce à prendre ; la case de départ et la case d'arrivée du dernier coup restent surlignées

### 06_Bataille_Victoire et 07_Bataille_Defaite

Refaits d'après les maquettes V2 : ce n'est plus une modale posée sur le
plateau assombri mais un **écran plein** (`scenes/battle/battle_result.gd`).
Les deux issues partagent exactement la même construction — le panneau de
défaite est le panneau de victoire repeint en rouge — et c'est ce qui décide
de la forme du composant : une seule « peau » (`victory_skin()` /
`defeat_skin()`) change fond, bordures, dégradés et accents.

- Illustration plein cadre : `assets/results/victory_bg.jpg` (la taverne
  pavoisée) et `defeat_bg.jpg` (le camp sous la pluie), plus un voile de
  teinte et deux vignettes dégradées, haute et basse
- Le mot **VICTOIRE / DÉFAITE est une image** (`victory_title.png`,
  `defeat_title.png`, 340 × 136) : c'est un lettrage gravé, pas du texte. Son
  halo est refait en dégradé radial additif — un flou n'existe pas en 2D
- Confettis de la victoire : douze rectangles et quatre étincelles **posés un
  par un** aux coordonnées de la maquette, pas une nappe de particules
- Bilan sur une plaque royale sertie de son losange, filet d'or intérieur,
  une ligne par fait de la bataille
- Boutons : **une seule action dans sa coque sertie** (bataille suivante, ou
  Réessayer quand il n'y a plus de bataille suivante), puis les deux sorties
  côte à côte, ROYAUME et CAMPAGNE
- Le contenu du bilan vient du jeu, pas de la maquette : celle-ci montre trois
  lignes d'exemple, le jeu en affiche autant qu'il en a — aura des Dames au
  repos, Dames ramenées au Château Royal, Dame offerte par la campagne
- Le filet ornemental sous le titre est **visible dans les deux issues**. La
  maquette de victoire le cache derrière la plaque du bilan ; comme c'est le
  même ornement dessiné pour les deux écrans, on le laisse respirer

### 08_Popup_Chateau

- Background village + overlay sombre
- Castle-Modal (x:24, y:180, w:345, h:398) : fond #161926, radius 16, stroke 2px
- Close-X (cercle #262c3f, radius 999)
- Header : nom + niveau château
- Ornate divider
- Upgrade details (fond #262c3f, radius 12) : coût, durée, bonus
- Upgrade-Button (fond #c59b27, radius 10, stroke 2px)

### 09_Popup_Batiment (recrutement)

- Même structure modale
- Building-Modal (x:24, y:120, w:345, h:352) :
  - Titre bâtiment + niveau
  - Troop detail box (fond #262c3f, radius 12)
  - Options : Recruter + Améliorer

### 10_Popup_Batiment_Verrouille

- Locked-Modal (fond #1a1c29, radius 16, stroke 2px)
- Header avec icône 🔒
- Preview box (#1c1f2e, radius 12) : aperçu du déplacement
- Unlock condition (#262c3f, radius 12) : "Apparaît au Château Nv.X"

### 11_Popup_Amelioration

- Upgrade-Modal (fond #161926, radius 16, stroke 2px)
- Header : nom + "Nv.X → Nv.Y"
- Progress graphic (#262c3f, radius 12) : barre de progression
- Active progress : compte à rebours
- Bonus preview (#1c1f2e, radius 8) : aperçu du niveau suivant

### 12_Composants (référence design system)

- Frame large (800×1600) servant de fiche technique
- Sections : Boutons & Commandes, Badges & Statuts, Jetons & Unités, Cases du Plateau, Exemples de Cartes
- C'est ta bible — reproduis chaque composant en tant que scène Godot réutilisable

## Composants UI à créer en Godot

### Boutons

| Type | Fond | Texte | Radius | Stroke | Usage |
|---|---|---|---|---|---|
| Primaire | Or #ffd11a | #331f00 bold | 18 | 2px or foncé | BATAILLE, COMBATTRE |
| Action Or | #c59b27 | blanc bold | 12 | 2px | Améliorer, Préparer |
| Action Bleu | #268cd9 | blanc | 10 | — | AUTO |
| Secondaire | #262c3f | #e6ecf5 | 10 | 1px #3d4f6b | Réessayer, Annuler |
| Danger | #c65f5f | blanc | 10 | — | Abandonner |
| Discret/Lien | transparent | #8fa0b8 | — | — | Village (retour) |

### Modales

- Fond #161926, radius 16-20, stroke 2px (couleur selon contexte : or/rouge/bleu)
- Close-X : cercle #262c3f radius 999, "✕" blanc
- Diviseur ornemental entre sections
- Cards internes : fond #262c3f, radius 12

### Pills / Badges

- Fond noir ou #262c3f, radius 8-10
- Texte petit (10-12px) semi-bold
- États : vert gagné, or disponible, gris verrouillé

### Barre de ressources (Top bar)

- Pills noires (radius 10) avec icône emoji + valeur
- Espacement horizontal, alignées en haut

### Grille de bataille

- 10×16, cellW=36, cellH=31, position (17, 155) dans le frame 393×852
- Cases alternées (damier) avec stroke fine
- Zones colorées : bleu joueur (opacity 0.28), rouge ennemi (opacity 0.28)
- Pièces : sprites SVG, taille 24px (grandes) ou 18px (pions), centrées dans la case

### Chips de sélection (placement)

- Frame avec icône pièce SVG + nom + compteur
- Fond #161926, radius 8, stroke quand sélectionné

## Architecture Godot recommandée

```
res://
├── assets/
│   ├── pieces/
│   │   ├── bleu/ (roi.svg, dame.svg, cavalier.svg, fou.svg, tour.svg, pion.svg)
│   │   ├── rouge/ (idem)
│   │   └── absent/ (idem)
│   ├── backgrounds/
│   │   ├── village_background.png
│   │   ├── battlefield_background.png
│   │   └── parchment_map.png
│   └── screens/ (screenshots de reference, non integres au build)
├── scenes/
├── scripts/
└── ...
```

## Ordre de travail suggéré

1. Theme Godot (kings_gambit_theme.tres) : configurer Inter + toute la palette
2. Composants UI : boutons, modales, cards, badges, pills — scènes réutilisables
3. Battle Grid : grille 10×16 avec placement de pièces SVG
4. Écran Village (01) : background + labels + bouton bataille
5. Écran Campagne (02) : parchemin sur bois + chemin + étapes
6. Écran Préparation (03) : briefing cards
7. Écran Placement (04) : grille + zones + sélecteur de pièces
8. Écran Combat (05) : même grille, contrôles de vitesse, mode lecture seule
9. Modales (06-11) : victoire, défaite, popups bâtiments
10. Logique de jeu : placement, combat auto, progression, sauvegarde

## Notes importantes

- Les écrans 04 (Placement) et 05 (Combat) partagent exactement la même grille et le même background pour éviter tout "saut" visuel lors de la transition
- La Dame n'est pas recrutée — elle apparaît uniquement par promotion (un pion qui atteint le bout du plateau), et n'est conservée que si elle survit à la bataille : elle rejoint alors le Château Royal. Laissée au village elle rapporte +15 % d'or par bataille ; son niveau au combat est le plus faible du niveau du château et du nombre de Dames abritées, et aucune n'est jamais dépensée
- Le niveau d'un bâtiment débloque des CAPACITÉS, pas seulement des chiffres : le pion gagne le double pas d'ouverture au niveau 2 (`first_move_range` dans Balance), le cavalier de nouvelles figures de saut
- Le Roi est unique et lié au Château Royal
- Les SVG sont les assets finaux — ne les remplace pas par des placeholders
- Aucune valeur de gameplay ne doit être écrite ailleurs que dans `scripts/data/balance.gd` (tailles de plateau, compositions ennemies, portées, coûts, durées d'animation)
- Tous les fondus (edge fades) sont des gradients linéaires noir→transparent sur les 4 bords de l'écran
