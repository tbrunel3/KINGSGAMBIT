# King's Gambit — où en est le jeu

**Ce document est une référence, pas une demande.** Il dit ce qu'est devenu le
jeu, ce qui en est sorti, ce qui y entre. Les demandes d'écrans arrivent
séparément, dans leurs propres briefs, et s'adossent à celui-ci.

Il remplace le premier brief du projet, qui décrivait un jeu qui n'existe plus
et a été supprimé pour qu'on ne le relise pas par erreur.

---

## ⚠️ Le fichier a TROIS pages, et c'est `MAINPROJECT` qui fait foi

Fichier `rqEdH4O2R21TuUFv7OUlF7`.

| Page | node-id | Ce qu'elle porte |
|---|---|---|
| **`MAINPROJECT`** | **`410:2`** | **la bibliothèque à jour** — 20+ écrans rangés en 7 sections. On travaille ici, et nulle part ailleurs |
| `Écrans triés` | `248:2` | les copies qui portent les **timelines d'animation** que les originaux n'ont pas |
| `KINGS GAMBIT` | `0:1` | la page d'origine : images sources, planche de composants `2:1224`, pièces SVG `32:2`, logo `116:573` |

**Le rangement du 23/08/2026 a tué les node-ids des versions précédentes.**
Tous les ids cités plus bas sont ceux de `MAINPROJECT`, sauf mention explicite
d'« ancienne page `0:1` ».

---

## Le jeu, aujourd'hui, en un paragraphe

King's Gambit est un jeu de stratégie mobile fantasy inspiré des échecs. Le
Roi a perdu sa Dame ; il reconstruit son armée et enchaîne des batailles pour
la retrouver. Avant chaque combat, le joueur **compose** puis **place son
armée** face à une formation ennemie qu'il voit ; puis il **joue lui-même
chaque coup**, une pièce par camp et par tour, jusqu'à ce qu'un camp n'ait plus
rien debout. Entre deux batailles il rentre au village, recrute, améliore ses
bâtiments. Un pion mené au bout du plateau et **ramené vivant** devient une
Dame et rejoint le Château Royal — le trône vide du début de l'histoire.

Ton : fantasy médiéval, mélancolique mais pas sombre — un royaume diminué qui
se reconstruit, pas une guerre horrifique. Aucune violence graphique : la
capture d'une pièce est une convention d'échecs, pas une mise à mort.

---

## Ce qui a changé depuis le premier brief

| Le premier brief disait | Le jeu fait aujourd'hui | Pourquoi |
|---|---|---|
| Le combat se résout tout seul, on le regarde | **Le joueur joue chaque coup au doigt** | C'est devenu le cœur du jeu. Tout le reste en découle |
| Une bataille = un combat | À partir de la **2ᵉ**, une **série de 2 combats** sans retour au village ; **3** pour les trois dernières | L'ennemi revient au complet, le joueur avec ses survivants : c'est l'usure qui fait la difficulté |
| Victoire ou défaite | **Trois issues** — victoire, défaite, **match nul** | Pat, position morte ou enlisement à matériel égal : personne n'a gagné |
| Résultats en modale sur le plateau assombri | **Écrans pleins** | Décidé à la V2, en place |
| La Dame vit dans une « Tour de la Dame » | **Elle vit au Château Royal**, aux côtés du Roi | C'est de là que vient toute l'histoire |
| Carte de campagne tenant dans un écran | **Parchemin défilant de 2 300 points** | En place |
| Rien ne guide le joueur | **11 missions qui se déverrouillent en chaîne** | Elles remplacent un tutoriel |
| « Déploiement : 12/15 unités » | **« Charge : 7/16 »** — un budget de poids | Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5 |
| Plateau de 8 × 11 cases | **De 5 × 6 à 8 × 9** | Une case doit rester touchable au pouce : 45 à 72 points de côté |

### Ce qui est sorti du jeu

Tout ce qui jouait à la place du joueur a disparu — décision de fond, pas
nettoyage : le **bouton AUTO** du combat, les **vitesses ×1 / ×2 / ×4**,
**PAUSE** et **FIN DE TOUR**, et le **bouton AUTO du placement**, remplacé par
**DERNIÈRE FORMATION** — la formation que le *joueur* avait choisie la fois
d'avant, sa décision à lui, mémorisée.

Objet du brief `figma_prompt_bataille.md`, **auquel tu as déjà répondu** : les
deux frames sont révisées et intégrées, et c'est l'option **B** qui a été
retenue — pas de bandeau, l'état du tour remonté dans le badge du haut
(« TOUR 5 · À TOI DE JOUER »).

---

## Ce qui entre dans le jeu

### La boutique — ✅ livrée

**Le brief existe et l'écran est en jeu** : `figma_prompt_boutique.md` pour la
demande, `archive/chantier_h_boutique.md` pour les règles, frame **`shop-screen`**
(`410:7061`), cascade d'ouverture et dix illustrations posées le 23/08.

Ce qui a été tranché, pour mémoire : boutique **réelle**, gemmes gagnées en
jouant (les euros restent visibles mais grisés « Bientôt ») ; un coffre donne du
**temps d'amélioration**, jamais d'or ni de pièces ; les gemmes viennent de
**coffres gratuits à minuterie** (1 h et 3 h) ; la section OR est gardée avec
des montants recalibrés. Corrections livrées sur la frame le 23/08 : légende
des quatre coffres, section OR recalibrée, euros grisés, **bloc de coffres
gratuits dessiné**.

### Des niveaux de bâtiment qui donnent du choix, pas de la portée

Aujourd'hui, monter une caserne allonge surtout la portée de sa pièce. La
direction prise est différente : les niveaux doivent donner à une pièce **un
choix de cases d'atterrissage de plus en plus fin** — le traitement que reçoit
déjà le Cavalier, dont chaque palier ouvre de nouvelles figures de saut.

Aucun impact visuel immédiat, sauf peut-être sur la façon dont les popups de
bâtiment montrent « ce que gagne la pièce au niveau suivant ». Signalé pour que
tu ne sois pas surpris.

---

## Le vocabulaire du jeu

Les libellés de la maquette et ceux du jeu divergent sur plusieurs points.
**C'est le jeu qui a raison** — merci d'aligner les futurs écrans dessus.

| La maquette dit | Le jeu dit |
|---|---|
| Atelier | **Caserne des Pions** |
| Académie | **Écuries** |
| Chapelle | **Cloître des Fous** |
| Cathédrale | **Donjon des Tours** |
| Forge (verrouillée) | *n'existe pas* |
| Tour de la Dame | **Château Royal** — la Dame n'a pas de bâtiment à elle |
| « 12/15 unités » | **« Charge : 7/16 »** — un budget de poids |
| Plateau 8 × 11 | **de 5 × 6 à 8 × 9** |
| 9 batailles + « Bientôt disponible » | **10 batailles.** Le médaillon du sommet **est** la bataille 10, La Tour de la Dame — et le libellé disparaît |

*(Les deux frames du village ont été corrigées le 23/08 : les quatre casernes
portent enfin les noms du jeu, plus la pastille de gemmes et les entrées
Boutique / Codex.)*

---

## Les écrans, et où on en est

Node-ids de la page **`MAINPROJECT`** (`410:2`).

| Section | Écran | node-id | État |
|---|---|---|---|
| 🎬 Intro | splash-screen | `410:3` | en jeu |
| | king-intro-before-dialogue | `410:35` | en jeu |
| | king-intro-dialogue | `410:71` | en jeu |
| 🏘️ Navigation | village-avec-dame | `410:153` | en jeu |
| | village-sans-dame | `410:196` | en jeu |
| | chateau-royal-avec-dame | `410:233` | en jeu — écran plein |
| | chateau-royal-sans-dame | `410:286` | en jeu |
| | écrans de bâtiment | `517:2` | en jeu — douze décors |
| 🗺️ Campagne | 02_Campagne | `410:342` | en jeu |
| ⚔️ Combat | preparation-bataille-v2 | `410:7227` | en jeu — l'écran de composition |
| | 04_Bataille_Placement | `410:667` | en jeu — révision livrée |
| | 05_Bataille_Combat | `410:3764` | en jeu — révision livrée |
| | popup-combat-phase | `410:7190` | en jeu — c'est le **bandeau de série** |
| 🏆 Résultats | 06_Bataille_Victoire | `410:5121` | en jeu — écran plein |
| | 07-bataille-defaite | `410:5430` | en jeu |
| | 07-bataille-nulle | `410:5551` | en jeu — peau d'acier |
| 📋 Popups | mission-popup | `410:5664` | **en jeu** (`mission_popup.gd`) |
| | 09-popup-batiment | `410:7342` | **en jeu** — une seule scène couvre les quatre états |
| | 10-popup-batiment-verrouille | `410:7488` | **en jeu** — cerclé d'or comme demandé |
| | 11-popup-amelioration | `410:7629` | **en jeu** |
| | confirm-upgrade-modal | `410:7769` | **en jeu** (`confirm_upgrade.gd`) |
| | 12-popup-donjon-tours | `492:2` | posé pour le prototype Make |
| | 13-popup-guide-pat | `499:2` | en jeu — maquette posée par l'intégration, **à retoucher** |
| | 14-popup-guide-composition | `500:2` | idem |
| | 15-popup-guide-aura-dame | `500:55` | idem |
| | 16-popup-guide-temps-reel | `500:108` | idem |
| 📖 Codex & Shop | codex-popup-v3 | `410:6525` | en jeu — voir plus bas |
| | shop-screen | `410:7061` | en jeu |

**Deux frames que `MAINPROJECT` n'a PAS reprises**, et qui n'existent que sur
l'ancienne page `0:1` :

| Frame | Ancien node-id | État |
|---|---|---|
| preparation-bataille-10-v3 | `330:2` *(ancienne page `0:1`, non repris dans MAINPROJECT)* | **en jeu** — la préparation, plus le bandeau de la Dame captive. Le code s'y appuie encore |
| 12-composants | `2:1224` *(ancienne page `0:1`, non repris dans MAINPROJECT)* | planche de référence |
| codex-popup v1 | `194:4` *(ancienne page `0:1`)* | conservée intacte, **remplacée** par la v3 |

### Une demande ouverte

**La carte de campagne illustrée** (`209:423`, ancienne page `0:1`). Elle est
plus belle que le parchemin en jeu et on la prendrait volontiers, mais
**vérifié** : c'est un `RECTANGLE` à remplissage image, et les numéros d'étape
sont **peints dans le raster** — ce n'est pas un calque qu'on masque. Le jeu
trace ses propres cachets par-dessus, et ce sont eux qui disent verrouillé /
disponible / gagné. Il nous faudrait la même carte **régénérée sans les
pastilles numérotées**, et **couvrant les dix étapes** : celle-ci ne couvre que
les étapes 6 à 10.

*(La Dame captive, elle, est réglée : elle est le bandeau d'enjeu de la
préparation de la bataille 10, « La Tour de la Dame », la seule qui accorde une
Dame. Le PNG détouré du dépôt — 800 × 1259, alpha propre — a été reversé dans la
maquette : l'image d'origine du fichier arrivait avec un fond opaque.)*

### Un écran en jeu qui n'a jamais été dessiné

**Les quatre lettres scellées du Roi** (`royal_letter.gd`) : elles portent le
*pourquoi* de l'histoire là où les popups guide portent le *comment*. Elles
sont montées sur deux illustrations du fichier (enveloppe, parchemin — plissures
à 39,5 % et 65,4 %, marge intérieure 8,5 %), sans frame dédiée.

---

## Le codex : la forme était bonne, le contenu décrivait un autre jeu

> **✅ RÉGLÉ.** Le brief qui te manquait existe :
> [`figma_prompt_codex.md`](figma_prompt_codex.md), avec tous les chiffres du
> jeu. La frame **`codex-popup-v3`** (`410:6525`) a été posée à côté de la
> tienne — **ton `codex-popup` d'origine n'a pas été touché** — et l'écran est
> en jeu. Ce qui suit reste écrit pour mémoire, parce que c'est le genre
> d'erreur qui revient sans un brief.

La mise en page de `codex-popup` était juste — plaque de titre, puces de filtre,
une carte par pièce, un tableau par niveau, puis les bâtiments et les règles.
**Mais rien de ce qu'elle écrivait n'était vrai du jeu** :

| Le codex écrit | Le jeu |
|---|---|
| des colonnes **PV** et **ATK** par niveau | **ni points de vie ni dégâts** — une pièce est debout, ou capturée |
| « Charge inflige +50 % de dégâts », « Soigne les alliés adjacents de 10 PV/tour » | aucun soin, aucun dégât, aucune statistique de combat |
| « champ quadrillé de 8 cases sur 11 » | de 5×6 à 8×9, pour qu'une case reste touchable |
| « commandes de vitesse ×1, ×2, ×4 » | retirées — rien ne joue à la place du joueur |
| « défaite si votre Roi est vaincu » | il n'y a **pas de Roi** sur le plateau |
| Donjon de Fer, Cathédrale, Académie militaire, Chapelle de soins | cinq bâtiments : le Château Royal et quatre casernes |

Ce n'est pas une critique du dessin : c'est le brief qui t'a manqué. **La mise
en page a été gardée telle quelle**, seules les données ont changé.

Ce qui a bougé dans la v3 : **la carte du ROI a disparu** avec sa puce de filtre
(il est le narrateur, pas une pièce) ; **le tableau passe de
`NIVEAU / PV / ATK / BONUS` à `NIV. / MOBILITÉ / CASERNE / PRIX`**, et de 3
lignes à **10** — le codex est le seul écran qui montre la courbe entière ;
**« Attaque » devient « Capture »** ; **chaque carte gagne une puce POIDS**
(1 / 3 / 3 / 5 / 5), ce que la pièce coûte dans le budget que la préparation
affiche en « Charge : 27/28 » ; **les huit bâtiments deviennent cinq**, avec
leur palier de déverrouillage ; **les cinq règles deviennent six**, et l'anneau
rouge y entre — c'est la mécanique de tension du jeu et elle n'était nulle part.

Trois réglages d'adaptabilité, défauts mécaniques et non choix de goût :

| Défaut | Mesure | Correction |
|---|---|---|
| La rangée de puces débordait | 404 points de puces dans un conteneur de **361** | rembourrage de 14 → **10**, et le ROI en moins |
| La colonne `BONUS / INFO` trop étroite | 100 points pour du texte qui en demande le double | quatre colonnes redistribuées au profit de la mobilité, chiffres alignés à droite |
| La frame était en **Geist** | police que le jeu n'embarque pas | passée en **Inter** |

---

## Les règles permanentes de la collaboration

**1. La maquette apporte l'apparence, jamais les règles.** Couleurs, typo,
illustrations, mise en page, hiérarchie, composants : ça vient de toi. Ce qu'on
peut faire dans le jeu, quand, et avec quel effet : ça vient du code. Si un
écran te semble avoir besoin d'un bouton que le gameplay n'a pas, on ne
l'ajoutera pas. Si un libellé annonce une règle différente de celle du jeu,
c'est le libellé qu'on corrige.

**2. Ancrer, ne pas positionner.** Un écran posé en coordonnées absolues calées
sur 852 points se décale dès que l'appareil fait 880. Découpe chaque écran en
zones ancrées — barre haute de hauteur fixe, contenu central qui prend la place
restante, bandeau bas de hauteur fixe. Dessine dans un cadre utile de
**361 × 824** (393 × 852 moins les marges de zone sûre), ou donne les positions
en pourcentages.

**3. Quatre pièges d'import, rencontrés pour de vrai :**

| Piège | Ce qu'il faut livrer |
|---|---|
| Un **PNG exporté depuis Figma n'est pas détouré** — le nœud arrive avec le fond de la frame derrière lui (vrai aussi en JPG : `parchment_map` avait **30 px de barre brune cuits dans chaque bord**) | fond transparent, ou dis-nous quoi redécouper |
| **Les filtres SVG ne sont pas appliqués** par Godot — un halo en `feGaussianBlur` arrive éteint | des dégradés radiaux, ou le halo cuit dans la texture |
| **Un label ne peut pas être rempli d'un dégradé** sans un shader par glyphe | l'or médian à plat, avec son ombre portée — à 9-19 points, la différence ne se voit pas |
| **Pas de nouvelle police sans la peser** | le jeu embarque **Inter** (variable, partout), **Poppins Bold / SemiBold** (les enseignes du village), **Comic Relief** (la voix du Roi), **Lora** (deux titres). Jaro n'est plus utilisée |

⚠️ **CORRECTION DEMANDÉE — `07-bataille-nulle` (`410:5551`).** Les deux mots
« ROYAUME » et « CAMPAGNE » y sont en **Jua Regular 13**. Jua pèse **2,1 Mo** :
le tiers du poids de toutes les autres polices du jeu réunies, pour deux mots de
13 points sur l'écran le plus rare. Décision du joueur le 23/08/2026 : **on ne
l'embarque pas.** Peux-tu les repasser en Inter, ou en Poppins ?

C'est le seul endroit où « tu utilises les polices de Figma, point final » s'est
heurté à une mesure — et partout ailleurs la consigne tient : Poppins a été
embarquée pour les enseignes du village sans discuter (SemiBold 150 Ko + Bold
151 Ko = **302 Ko**).

**4. Le langage visuel est établi : la plaque royale.** Rectangle arrondi,
dégradé bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un trait d'or
épais `#ffe680`, doublé à l'intérieur d'un filet d'or fin. Elle sert déjà de
brique à la préparation, à la victoire et à la défaite. Les nouveaux écrans en
descendent, ils n'inventent pas un troisième langage.

⚠️ **Une exception assumée** : la préparation de bataille (`410:7227`) est en
parchemin crème et panneaux blancs, quand la carte qui la précède et le
placement qui la suit restent en nuit et or. La rupture a été signalée puis
gardée — c'est le seul écran clair du jeu.

**5. Contraintes de rendu.** Portrait uniquement, référence **393 × 852**
points, safe areas iPhone respectées. Godot 4 en `gl_compatibility` : PNG avec
alpha, pas de flou lourd, pas de particules complexes.
