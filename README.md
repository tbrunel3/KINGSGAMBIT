# King's Gambit

Jeu de stratégie mobile fantasy inspiré des échecs. Le Roi a perdu sa Dame ; il
reconstruit son armée et enchaîne les batailles pour la retrouver.

Le joueur **place son armée** face à une formation ennemie qu'il voit, puis
**joue lui-même chaque coup**, une pièce par camp et par tour. Entre deux
batailles il rentre au village, recrute, améliore. Un pion mené au bout du
plateau et **ramené vivant** devient une Dame et rejoint le Château Royal.

**Moteur : Godot 4.7** (testé sur 4.7.1 stable), GDScript, rendu
`gl_compatibility`. **Cible : iPhone portrait**, interface calée sur
393 × 852 points, safe areas gérées.

> Deux autres documents, qui ne répètent pas celui-ci :
> [`CLAUDE.md`](CLAUDE.md) est le manuel de l'agent qui reprend le code, et
> [`figma_contexte_projet.md`](figma_contexte_projet.md) la référence du
> designer.

---

## Jouer

| Où | Comment |
|---|---|
| **Dans Godot** | ouvrir `project.godot`, puis **F5**. La voie à prendre pour modifier le jeu |
| **Windows** | `build/windows/KingsGambit.exe`, autonome. Non versionné (109 Mo, au-delà de la limite GitHub) : il se régénère à l'export |
| **Navigateur, iPhone compris** | `https://tbrunel3.github.io/KINGSGAMBIT/`, au doigt, sans rien installer |

L'export web écrit dans `docs/`, **non versionné** : 55 Mo de wasm et de pck à
chaque export n'ont rien à faire dans l'historique. Le build est publié depuis
la branche **`gh-pages`**, qui ne contient que lui (Settings → Pages → Branch
`gh-pages`, dossier `/ (root)`). Mono-thread, avec manifeste PWA : « Sur l'écran
d'accueil » depuis Safari donne une icône et un plein écran portrait.

```bash
godot --headless --path . --export-release "Windows Desktop"
```

```bash
godot --headless --path . --export-release "Web"
```

### Le parcours à tester

**BATAILLE** → une bataille → **PRÉPARER L'ARMÉE** → choisis un type, touche les
cases de ta zone → **COMBATTRE**. Puis **tu joues chaque coup**. Retour au
village : ouvre un bâtiment, recrute, lance une amélioration (le compte à
rebours continue même jeu fermé).

**Rien ne joue jamais à ta place.** **DERNIÈRE FORMATION**, au placement, repose
l'armée telle que *tu* l'avais rangée ; il n'apparaît qu'après un placement
validé sur cette bataille.

Tu démarres avec **4 pions et un cavalier** — une armée de pions seuls est une
finale d'échecs, le pire des tutoriels. Caserne des Pions et Écuries ouvertes
d'entrée ; Cloître et Donjon apparaissent gratuitement aux niveaux de château
**2 et 3**.

| Repère | Ce qu'il fait |
|---|---|
| **point i** (sous la croix de sortie, en bataille) | les règles noir sur blanc : poids et pose au placement, tour par tour, capture et promotion au combat |
| **MISSIONS** (barre du haut) | le fil rouge : **onze** objectifs qui se déverrouillent **en chaîne** (une mission n'apparaît qu'une fois celles de son `requires` réclamées) et paient en or. Les **cinq premières** sont le tutoriel ; une pastille dorée signale ce qui attend |
| **DEV** (en haut à droite) | raccourcis de test : or, déblocages, améliorations instantanées, **RAZ** pour effacer la sauvegarde |

### Tester sur son téléphone, en réseau local

```bash
python tools/serve_local.py docs
```

Le script affiche les deux adresses — une pour ce PC, une pour le téléphone — et
génère le certificat dont il a besoin.

**Le HTTPS n'est pas une précaution, c'est une obligation** : Godot refuse de
démarrer hors d'un « contexte sécurisé ». `localhost` en est un,
`http://192.168.1.60` non — le téléphone n'afficherait que *« Secure Context —
Check web server configuration (use HTTPS) »*. Certificat auto-signé : le
téléphone avertit **une fois**, accepter (« Paramètres avancés » →
« Continuer »). Si la page ne s'ouvre pas du tout, c'est le pare-feu Windows :
autoriser `python.exe` en entrée sur le profil du réseau courant.

---

## Règles du jeu

Les pièces rappellent les échecs sans en respecter les règles. **Ni points de
vie ni dégâts** : une pièce est sur le plateau, ou capturée. On capture en se
**déplaçant sur la case adverse**. Aucune attaque à distance.

| Pièce | Déplacement | Nv.1 | Nv.10 |
|---|---|---|---|
| **Pion** | avance tout droit, capture en diagonale avant | 1 case, ouverture 1 | 2 cases, ouverture 4 |
| **Cavalier** | sauts, ignore les pièces du trajet | petit saut (1,1) | 7 figures, jusqu'à (3,4) |
| **Fou** | diagonales, bloqué par les pièces | 2 cases | 8 cases |
| **Tour** | lignes et colonnes, bloquée par les pièces | 2 cases | 8 cases |
| **Dame** | toutes directions — uniquement par promotion | 2 cases | 9 cases |

Le niveau débloque des **capacités**, pas seulement des chiffres : le pion gagne
le **double pas d'ouverture** des échecs au **Nv.2**, qui passe à 3 cases au
**Nv.5** et 4 au **Nv.8**, alors que sa portée ordinaire ne monte qu'au
**Nv.7** ; le cavalier passe du petit saut diagonal au L classique au **Nv.2**,
puis à des figures plus longues. Tour et fou restent à **2 cases au Nv.1** : à
1 case ils seraient plus faibles qu'un pion, incapables de riposter à une pièce
postée en diagonale. Ils s'arrêtent devant une pièce alliée, et **en prenant**
la première pièce ennemie ; un Cavalier saute par-dessus tout.

**L'anneau rouge** cercle en permanence tes pièces prenables au coup suivant :
sans points de vie, où une capture est définitive, toute la tension tient à voir
la pièce qui attaque. Il est **fixe, jamais clignotant** — l'or qui bat
appartient au couronnement. Il s'allume aussi **au placement**, ce qui en fait
un vrai contre-placement : on voit tout de suite qu'on vient de poser une tour
sous la ligne d'un fou adverse.

### La Dame

Un pion qui atteint le fond adverse devient **Dame** et **garde le niveau du
pion** — celle d'un pion Nv.1 se déplace bien moins loin que celle d'un Nv.10.
Le sacre **prend un tour** : le pion arrive, la case est marquée, les deux camps
ont le temps de la regarder — l'un pour la défendre, l'autre pour l'attaquer.

**Elle se mérite** : le pion doit avoir déjà capturé
(`PROMOTION_REQUIRES_CAPTURE`), la bataille être encore disputée
(`PROMOTION_CONTESTED_RATIO`), et il n'y a **qu'une couronne par camp et par
bataille** (`PROMOTION_ONE_PER_BATTLE`). Sinon c'est du ramassage — plus rien en
face, un pion se promène jusqu'au bout : il promeut quand même, mais en
**Cavalier**, qui ne rejoint pas le Château Royal.

| | |
|---|---|
| **Si elle survit** | le pion quitte la caserne, la Dame s'installe au **Château Royal**, sur le trône vide du premier écran. Redéployable pour **5 de charge** (le prix d'une Tour), mais sa *valeur* reste **9** — c'est ce que voit l'IA, qui la traite comme la pièce la plus chère. Capturée, elle est perdue comme le pion qu'elle était |
| **L'aura** | une Dame **laissée au village** rapporte **+15 % d'or** par victoire (`DAME_GOLD_BONUS`), compté par Dame au repos. En déployer une renonce à sa part, pas à celle des autres : tout l'arbitrage du chip **DAME**. Au village, le château **rayonne** tant qu'une Dame est là |
| **La Dame retrouvée** | la dernière bataille, « La Tour de la Dame », en offre une à la **première victoire** (`"dame"` dans `CAMPAIGN`). Sans ce filet, la promotion restant rare, la moitié du jeu resterait éteinte |
| **Les améliorer** | pas de bâtiment : leur niveau est **le plus faible du niveau du Château et du nombre de Dames abritées**. Une seule Dame dans un château Nv.5 reste Nv.1 ; trois Dames dans un château Nv.3 sont toutes Nv.3. Aucune Dame n'est jamais dépensée |

### Les pertes et la série

**Les pertes sont définitives** : une pièce capturée quitte l'armée et devra
être recrutée. C'est ce qui donne son poids au placement — et la raison d'être
de l'écran de campagne, qui permet de rejouer une bataille gagnée pour refaire
de l'or (**40 %** de la récompense). Une **garnison minimale** de **3 pions**
est rendue gratuitement après chaque bataille, sans quoi une armée balayée sans
or rendrait la partie impossible à reprendre.

À partir de la **deuxième** bataille, un niveau se gagne en une **série** —
**deux** combats d'affilée, **trois** pour les trois dernières, sans retour au
village. L'ennemi revient au complet, toi avec tes survivants : c'est l'usure
qui fait la difficulté. Entre deux combats, **2 points de poids**
(`RUN_REINFORCE_WEIGHT`) se relèvent parmi tes pertes, les moins chères d'abord
— deux pions, jamais une tour. L'or n'est versé qu'à la fin, et **un seul combat
perdu fait tomber la série entière**.

### Les trois façons de finir sans vainqueur

Un combat se termine normalement quand un camp n'a plus de pièce. Sinon, de
**trois** manières, réglées à trois endroits de `Balance.COMBAT`.

| | Ce qui se passe | Issue | Réglage |
|---|---|---|---|
| **Pat** | le camp au trait n'a **plus aucun coup légal** | **nul**, comme aux échecs | `stalemate_is_draw` (`true`) |
| **Position morte** | plus aucune capture possible, jamais | **toujours nulle** | `dead_position_check_after` (4), `dead_position_grace` (6) |
| **Enlisement** | **20 tours** complets sans la moindre prise, mais des coups restent jouables | tranché **au matériel restant** ; à égalité stricte, personne n'a gagné | `stalemate_rounds_manual` (20) |

⚠️ **Un camp ne passe JAMAIS son tour.** Le pat n'est pas une passe : la partie
finit sur-le-champ. `BattleEngine._pass_turn` ne subsiste qu'en garde-fou et
**signale une erreur** au lieu de passer. L'ancien compteur de deux passes
d'affilée ne rattrapait rien — le coup du JOUEUR le remettait à zéro, donc une
IA figée laissait la partie tourner indéfiniment : **48 passes illégitimes sur
60 parties**.

Le pat est **beaucoup plus fréquent ici qu'aux échecs** : sur cinq colonnes les
pions se bloquent nez à nez sans arrêt, et un pion ne prend pas tout droit.
Mesuré à `stalemate_is_draw = true` : **6 des 19 parties du banc finissent
nulles**, bataille 1 comprise. Le basculer à `false` (shatranj : le camp bloqué
perd) change le public du jeu — pas sans relancer `smoke_test`. La position
morte évite une punition gratuite : deux cavaliers Nv.1 sur des couleurs
opposées ne se toucheront jamais, et elle tombe en **10 activations au lieu des
80** du compteur d'enlisement.

**Au nul, les survivants rentrent, le combat ne rapporte rien, et la série n'est
pas rompue** : un tour d'usure payé pour rien, pas une déroute. Surtout,
⚠️ **un nul REJOUE le combat, il ne le consomme pas** — même numéro, mêmes
survivants, blessés relevés, compteur de combats inchangé. Le plafond
`Balance.RUN_DRAWS_ALLOWED` (**3**) l'empêche de devenir un abri : sans lui,
bloquer la position permettrait de retenter indéfiniment sans rien risquer. Au
troisième nul, la série s'achève sans être remportée.

### Le niveau de jeu de l'IA

Chaque bataille déclare celui de l'**armée ennemie** (`ai` dans `CAMPAIGN`).
Aucune règle ne change, aucun privilège n'est donné : **ce sont trois
profondeurs de recherche**, pas trois jeux d'heuristiques.

| Niveau | Profondeur | Ce qu'elle voit |
|---|---|---|
| **Novice** | 1 demi-coup | Prend ce qui passe. Elle vérifie que sa case d'arrivée n'est pas attaquée, mais ne joue jamais la réponse adverse : elle se fait fourcher |
| **Aguerri** | 2 | La réponse immédiate. Elle ne donne plus une pièce |
| **Expert** | 3 | Sa réplique : fourchettes, enfilades, échanges à trois temps |

**Le camp du joueur n'est jamais confié à personne.** La recherche sert encore
aux bancs (`tools/`), qui font jouer les deux camps pour simuler des campagnes.

### Jouer son tour

Tour par tour, **une pièce par camp**. Aucune horloge : le plateau attend.

- **Taper** une pièce l'allume — pastilles bleues sur les cases libres, anneaux
  dorés autour des pièces prenables. Taper une de ces cases joue le coup.
- **Glisser** la pièce fait la même chose d'un geste ; la case survolée s'allume
  en or quand le coup est légal.

Le dernier coup reste surligné : sur un petit écran, c'est ce qui permet de voir
ce que l'adversaire vient de faire. Au placement, les mêmes gestes posent
(tape), retirent (tape sur une pièce posée) et repositionnent (glisse — deux
pièces qui se croisent échangent leur case).

L'état du tour s'écrit dans le **badge en haut à gauche** : « TOUR 5 · À TOI DE
JOUER ». L'écran de combat n'a **pas** de bandeau en bas — les **77 points** qui
portaient le bouton AUTO et les vitesses sont partis avec ce qui jouait à la
place du joueur, et la hauteur est retournée au plateau.

---

## Où régler le jeu

**Tout l'équilibrage est dans un seul fichier :
[`scripts/data/balance.gd`](scripts/data/balance.gd).**

| Section | Contenu |
|---|---|
| `UNITS` | mobilité, capacité, valeur, coût de recrutement, coût et durée d'amélioration — **sur 10 niveaux** |
| `CASTLE_DATA` | charge déployable par niveau de château, coûts et durées |
| `CAMPAIGN` | les 10 batailles : grille, composition ennemie, niveaux, récompense, `fights` |
| `AI_DEPTH`, `AI_BUDGET_MS` | profondeur et budget de réflexion (**450 ms**) |
| `COMBAT` | durées d'animation, pat, position morte, enlisement, garde-fous |
| `GARRISON_MINIMUM`, `REPLAY_REWARD_RATIO` | filet de sécurité et rentabilité du farm |
| `RUN_REINFORCE_WEIGHT`, `RUN_DRAWS_ALLOWED` | renforts entre deux combats, plafond de nuls par série |
| `PROMOTION_CONTESTED_RATIO` | le bouton à tourner si les Dames sont trop fréquentes ou trop rares |
| `UNLOCK_CASTLE_LEVEL` | niveau de château auquel Cloître / Donjon apparaissent |
| `SHOP` | prix des coffres et des packs |

Les tableaux sont indexés par niveau : ajouter un niveau = ajouter une valeur à
chaque tableau de la pièce, et augmenter `MAX_LEVEL`. Le banc vérifie que les
tailles concordent et que la mobilité ne recule jamais.

Deux entrées de `CAMPAIGN` à ne pas confondre : **`level` est le niveau des
pièces ENNEMIES**, `player` celui auquel le joueur est censé aborder la
bataille. Elles se séparent depuis que l'avantage du joueur est fait de qualité
et non de nombre.

⚠️ **Toucher aux effectifs ennemis ou à leur niveau, c'est toucher au niveau de
jeu réel de l'IA.** Le coût d'un coup suit le nombre de coups légaux, donc les
effectifs *et* les portées. En passant la dernière bataille de **11 à 14 pièces
par camp**, la profondeur 3 est passée de **139 ms à 396 ms** et est sortie du
budget : l'IA déclarée experte retombait à la profondeur 2 sans que rien ne le
dise. Relancer `tools/ai_probe.tscn` après, systématiquement.

L'habillage (couleurs, arrondis, marges) est isolé dans
[`scripts/ui/ui_theme.gd`](scripts/ui/ui_theme.gd).

---

## Architecture

Principe directeur : **la logique de jeu ne connaît pas l'affichage**. Tout
`scripts/battle/` est fait d'objets purs, sans un seul nœud Godot — donc
simulable en headless, ce qui permet aux bancs de jouer des campagnes entières.

```
project.godot            portrait, stretch canvas_items, 4 autoloads

scripts/
  data/balance.gd        [autoload Balance]     toutes les valeurs de réglage
  core/save_manager.gd   [autoload SaveManager] lecture/écriture JSON dans user://
  core/game_state.gd     [autoload Game]        or, armée, niveaux, progression
  core/router.gd         [autoload Router]      changement de scène + contexte
  core/campaign_run.gd   l'état d'une série de combats

  battle/battle_unit.gd     une pièce en combat (données pures)
  battle/grid_model.gd      occupation du plateau, zones de déploiement
  battle/movement_rules.gd  déplacements et prises, par type de pièce
  battle/battle_ai.gd       IA novice + aiguillage vers la recherche
  battle/battle_search.gd   negamax alpha-bêta, niveaux aguerri et expert
  battle/battle_engine.gd   boucle tour par tour, émet des événements
  battle/grid_view.gd       rendu de la grille, menaces, entrées tactiles

  ui/ui_theme.gd         palette, polices et styles
  ui/safe_area.gd        marges d'encoche iPhone

scenes/
  intro/                      splash et dialogue du Roi
  village/village.tscn        village, or, bâtiments, bouton bataille
  village/building_popup.tscn recrutement et amélioration
  village/castle_screen.tscn  Château Royal, plein écran
  village/mission_popup.tscn  les onze missions
  battle/campaign.tscn        parchemin défilant, dix cachets
  battle/battle_prep.tscn     composition et briefing avant combat
  battle/battle.tscn          placement, combat et résultat (une seule scène)
  battle/battle_result.gd     victoire / défaite / nul — trois peaux d'un écran
  ui/components/              plaque royale, modale, chips, icônes, pastilles

tools/                     les bancs — voir la section Tests
```

### Quatre choix à connaître

- **Une seule scène de bataille**, à trois phases (placement → combat →
  résultat) : l'état du placement n'a jamais à transiter entre deux scènes.
- **Les données d'équilibrage sont des dictionnaires GDScript**, pas des `.tres`
  — éditables au texte, lisibles en diff Git, modifiables sans ouvrir Godot.
- **Les améliorations sont un timestamp Unix de fin** : le temps passe
  normalement jeu fermé.
- **Les écrans sont ANCRÉS, jamais posés en coordonnées absolues** — barre haute
  fixe, contenu central élastique, bandeau bas fixe. Le village est le cas
  particulier : ses étiquettes collent à des bâtiments *peints dans
  l'illustration*, d'où deux calques — `DecorLayer` suit le rectangle réel du
  fond, `UiLayer` suit l'écran.

### Les deux entrées du moteur

`BattleEngine.play_move(unit, cell)` joue le coup choisi par le joueur ;
`BattleEngine.step()` demande à l'IA de choisir **et** de jouer celui du camp
courant. Les deux retournent les événements (`move`, `capture`, `promotion`,
`pass`, `end`) que la vue rejoue. Le coup est déjà résolu quand l'animation
commence : **l'animation ne décide de rien, elle montre.**

---

## Tests

```bash
godot --headless --path . tools/smoke_test.tscn
```

Le banc principal, ~70 s : cohérence des tableaux de `balance.gd`, économie,
formation mémorisée, détection des menaces, retrait des pertes, règles de pièces
sur des plateaux montés à la main, série de combats, puis simulation des
10 batailles et chargement de tous les écrans.

Tous les autres se lancent pareil — `godot --headless --path . tools/X.tscn` —
**sauf les trois qui écrivent des PNG** (`screenshot`, `resolutions`,
`hitbox_debug`), qui exigent une fenêtre, donc **sans `--headless`**.

| Banc | La question à laquelle il répond | Durée |
|---|---|---|
| `smoke_test.tscn` | est-ce que tout tient encore debout ? | ~70 s |
| `ui_test.tscn` | est-ce que les vrais boutons répondent ? | court |
| `format_test.tscn` | la géométrie tient-elle sur les huit formats ? (des **chiffres**, pas des images) | ~3 s |
| `ai_probe.tscn` | combien coûte un coup à chaque profondeur ? | ~7 s |
| `ai_bench.tscn` | est-ce que chercher plus loin fait gagner ? | long |
| `tune_probe.tscn` | de combien de niveaux le joueur doit-il dominer ? | ~45 min |
| `series_probe.tscn` | une **série** entière se joue-t-elle jusqu'au bout, et quel bouton la débloque (`fights`, effectifs, `RUN_REINFORCE_WEIGHT`) ? | long |
| `economy_probe.tscn` | la campagne verse-t-elle de quoi se traverser ? | plusieurs heures |
| `shop_probe.tscn` | combien de gemmes une campagne produit-elle — donc les prix de `SHOP` ont-ils un sens ? | court |
| `promo_probe.tscn` | combien de Dames une campagne produit-elle ? | ~3 min |
| `debug_battle.tscn` | pourquoi cette bataille tourne mal ? (trace coup par coup) | court |
| `generate_theme.tscn` | régénère `assets/theme/kings_gambit_theme.tres` depuis `UiTheme` | court |
| `hitbox_debug.tscn` | où tombent les zones de clic du village ? (**sans `--headless`**) | court |
| `screenshot.tscn` | à quoi ressemblent les écrans ? (**sans `--headless`**) | ~1 min |
| `resolutions.tscn` | qu'est-ce qui déborde sur les autres téléphones ? (**sans `--headless`**) | court |

⚠️ **`screenshot.tscn` en `--headless` n'écrit AUCUN fichier, et ne le dit
pas.** Il démarre, ne rend pas une ligne, sort avec le **code 0**, et les PNG de
`tools/screenshots/` gardent leur date de la veille. Payé le 24/08 : une capture
vieille d'un jour lue comme fraîche, et une conclusion tirée dessus. **Vérifier
l'horodatage des PNG avant de conclure sur une capture.**

### Vérifier la mise à l'échelle

```bash
godot --path . tools/resolutions.tscn
```

Rend village, campagne, préparation et placement en 393×852, 360×800, 375×812,
412×915 et 430×932 — une capture par combinaison dans
`tools/screenshots/echelle/`. Le jeu est calé sur 393×852, et en
`stretch/aspect = expand` un téléphone d'un autre format ne redimensionne pas :
il **révèle** de la hauteur en plus (**873 points sur un 360×800**).

```bash
godot --headless --path . tools/format_test.tscn
```

Le pendant chiffré : **huit** formats — les cinq ci-dessus plus `web-393x700`,
`court-360x620` et `tres-long-430x1080`, **les trois qui cassent**. Il mesure
des coordonnées et échoue tout seul, là où une image régresse en silence. Trois
cas : le fond, le village, l'intro.

### Deux règles de mesure, apprises à la dure

**Un banc chronométré n'est pas une mesure.** La recherche coupe au temps
(`AI_BUDGET_MS`), donc à un endroit qui dépend de la machine : deux bancs sur la
même position rendaient deux verdicts différents. Les bancs posent donc
`BattleAI.budget_ms = 0` — aucune limite, la recherche va au bout de sa
profondeur. Ils jouent contre une IA au moins aussi forte que celle du jeu,
jamais plus faible : une bataille qu'un banc déclare gagnable l'est à coup sûr.

**Un seul combat n'est pas une mesure non plus.** Déterministe ne veut pas dire
représentatif : sur la bataille 10, baisser le *seul* niveau ennemi donnait
`NUL, NUL, PERDUE, gagnée` — un coup différent au troisième tour envoie la
partie ailleurs. `tune_probe` lit donc un **taux sur plusieurs formations**,
jamais un tirage.

### L'économie : la courbe des récompenses suit celle des coûts

Le réglage le moins intuitif du jeu, et celui qui s'est révélé faux. Le prix des
niveaux monte **géométriquement** — atteindre le niveau 6 partout (château + les
quatre casernes) coûte **19 090 or** — quand les récompenses montaient presque
linéairement. Mesuré, cumul demandé face au cumul versé à ce stade :

| | bataille 3 | bataille 7 | bataille 10 |
|---|---|---|---|
| **demandé** | 1 130 | 6 810 | 19 090 |
| **versé** *(ancienne courbe)* | 930 | 2 810 | 7 030 |

Un facteur deux et demi, qui ne se rattrape pas en jouant mieux :
`economy_probe` mesurait **11 replays** pour franchir la bataille 3 et **36 pour
la bataille 7** — ce n'est plus de la difficulté, c'est de la corvée, et
personne ne la fait sur un téléphone.

Les récompenses vont maintenant de **150 à 5 000**, calées pour que le cumul
versé **avant** une bataille couvre ce qu'elle demande, avec une marge pour les
recrues. **Aucun coût n'a bougé** : c'est le rapport qui était faux.

**La récompense est celle d'un COMBAT, pas d'une bataille** — une série de trois
combats paie trois fois, ce qu'annonce l'écran de préparation (« Récompense de
la série »). Huit batailles sur dix étant des séries, se tromper là-dessus
fausse le calcul d'un facteur deux à trois : l'erreur de la première version de
la sonde, dont la première correction des récompenses avait hérité.

⚠️ **Toucher à `upgrade_cost` sans relancer la sonde, c'est rouvrir le trou.**

La sonde distingue trois échecs : la **corvée** (plus de **douze replays** pour
une seule bataille — franchissable, mais indigne), l'**impasse** (plus d'or et
plus aucune bataille qu'on regagne) et le **plafond** (tout au maximum et ça ne
passe toujours pas : là ce n'est plus l'économie, c'est le combat).

Mesure d'arrivée : **la campagne se traverse sans farmer une seule fois**, et
finit aux niveaux qu'elle prête au joueur — Ch6 et casernes 6 pour la dernière
bataille, ce qu'annonce son `player: 6`.

**Deux chiffres à surveiller, pas un.** « Combien de replays » dit si la
campagne est trop chère, « combien reste-t-il à la fin » si elle est trop
généreuse. Une hausse des deux dernières récompenses a été essayée puis
retirée : elle supprimait tout farm, mais laissait **33 593 or dormants sur
55 530 encaissés** — une économie dont on ne dépense que **40 %** n'a plus de
décisions dedans.

Deux réserves : la sonde annonce un **majorant** du plancher (elle achète en
glouton ; un joueur qui dépense mieux s'en sort à moins, mais perd aussi plus de
pièces), et les bancs jouent **un combat** quand la plupart des batailles sont
des séries. La série use, donc demande un peu plus que le niveau déclaré — **la
bataille 8 a réclamé des casernes un cran au-dessus**. Plus un problème depuis
que l'économie suit : **`player` est un plancher, pas une cible.**

### Équilibrage vérifié

Deux compositions par bataille — une armée variée et une armée de pions — et il
en faut une qui passe : exiger qu'une seule gagne partout nierait l'intérêt du
choix d'armée, car contre des pions ce sont les pions qui répondent. Le cas le
plus important est le dernier de la liste : la toute première bataille avec
l'armée de départ exacte, sans un seul recrutement. C'est lui qui a détecté que
le premier combat du jeu était perdu.

---

## Limites connues

- **Sur un téléphone lent**, la recherche peut sortir de son budget et
  redescendre d'un demi-coup. Dégradation propre — le meilleur coup de la
  dernière profondeur achevée — mais l'IA est un peu plus faible que déclarée.
- Le Roi n'est pas une pièce jouable : le château fixe la charge déployable.
- Aucune migration de sauvegarde : changer `SAVE_VERSION` repart de zéro.
- **Tout le jeu écoute la SOURIS** — pas un seul `InputEventScreenTouch` dans le
  dépôt. Ça ne marche au doigt que parce que `emulate_mouse_from_touch` vaut
  `true` par défaut, et **un second doigt produit un second appui émulé** qui
  tue le glissement en cours : paume ou doigt qui traîne, et le geste meurt.
