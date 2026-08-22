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

**Dans Godot** — ouvre `project.godot`, puis **F5**. C'est la voie à prendre
pour modifier le jeu.

**Exécutable Windows** — `build/windows/KingsGambit.exe`, un seul fichier
autonome. Non versionné (109 Mo, au-delà de la limite GitHub) : il se régénère
avec la commande d'export plus bas.

**Navigateur, y compris iPhone** — le dossier `docs/` contient un build web prêt
à publier. Une fois GitHub Pages activé (Settings → Pages → Branch `main`,
dossier `/docs`), le jeu est jouable à
`https://tbrunel3.github.io/KINGSGAMBIT/`, au doigt, sans rien installer. Le
build est mono-thread et embarque un manifeste PWA : « Sur l'écran d'accueil »
depuis Safari donne une icône et un affichage plein écran en portrait.

### Le parcours à tester

**BATAILLE** → choisis une bataille → **PRÉPARER L'ARMÉE** → choisis un type et
touche les cases de ta zone → **COMBATTRE**. Puis **tu joues chaque coup** :
touche une pièce, ses déplacements s'allument, touche la case d'arrivée — ou
fais-la glisser directement. L'ennemi répond avec une de ses pièces, et ainsi de
suite. Retour au village, ouvre un bâtiment, recrute, lance une amélioration :
le compte à rebours continue même jeu fermé.

**Rien ne joue jamais à ta place.** Le bouton **DERNIÈRE FORMATION**, au
placement, repose l'armée telle que *tu* l'avais rangée la fois d'avant — il
n'apparaît qu'une fois que tu as validé un placement sur cette bataille.

Tu démarres avec **4 pions et un cavalier** : une armée de pions seuls est une
finale d'échecs, ce qui fait le pire des tutoriels. La Caserne des Pions et les
Écuries sont ouvertes d'entrée ; le Cloître et le Donjon apparaissent
gratuitement quand le Château Royal atteint le niveau requis (2 et 3).

Le **point i**, sous la croix de sortie au bord droit de l'écran de bataille,
écrit les règles noir sur blanc : la pose et le barème des poids pendant le
placement, le tour par tour, la capture et la promotion pendant le combat.

Le bouton **MISSIONS** de la barre du haut porte le fil rouge du jeu : onze
objectifs qui se déverrouillent **en chaîne** (une mission n'apparaît que
lorsque celles de son `requires` ont été réclamées) et paient en or. Les cinq
premières forment le tutoriel — gagner, recruter, améliorer, enchaîner, gagner
proprement. Une pastille dorée signale les récompenses qui attendent. Le bouton
**DEV**, en haut à droite, ouvre un panneau de raccourcis de test : or,
déblocages, améliorations instantanées, et **RAZ** pour effacer la sauvegarde.

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
ne monte qu'au Nv.7. Le cavalier suit la même logique : **petit saut diagonal**
au niveau 1, le L classique au niveau 2, puis des figures de plus en plus
longues. La tour et le fou restent à 2 cases au niveau 1 : à 1 case ils seraient
plus faibles qu'un pion, incapables de riposter à une pièce postée en diagonale.

Une Tour ou un Fou s'arrête devant une pièce alliée, et s'arrête **en prenant**
la première pièce ennemie rencontrée. Un Cavalier saute par-dessus tout.

### Voir l'attaque arriver

Un **anneau rouge** cercle en permanence tes pièces que l'ennemi peut prendre à
son prochain coup. Dans un jeu sans points de vie, où une capture est
définitive, toute la tension tient à voir la pièce qui attaque : aux échecs on
ne ressent pas le danger parce que la position est mauvaise, mais parce qu'on
voit le coup venir. L'anneau est **fixe, jamais clignotant** — l'or qui bat
appartient déjà au couronnement, et deux clignotements sur le même plateau ne se
lisent plus ni l'un ni l'autre.

Il s'allume aussi **pendant le placement**, et ce second usage vaut le premier :
on voit immédiatement qu'on vient de poser une tour sous la ligne d'un fou
adverse. C'est ce qui fait du placement un vrai contre-placement.

### La Dame

**Promotion** : un pion qui atteint le fond du plateau adverse devient **Dame**.
Elle garde le niveau du pion qui a promu — une Dame issue d'un pion Nv.1 se
déplace donc bien moins loin que celle d'un pion Nv.10.

Le sacre **prend un tour** : le pion arrive, il n'est pas encore Dame, et la
case est marquée. Les deux camps ont le temps de la regarder — l'un pour la
défendre, l'autre pour l'attaquer.

Une Dame ne se gagne que dans une **bataille encore disputée**
(`Balance.PROMOTION_CONTESTED_RATIO`). Sinon c'est une promotion de ramassage :
quand il ne reste plus rien en face, un pion se promène jusqu'au bout sans que
personne puisse l'arrêter. Le pion promeut quand même — il a traversé le plateau
— mais en **Cavalier**, qui ne rejoint pas le Château Royal.

**Si elle survit à la bataille, elle reste une Dame** : le pion quitte la
caserne et la Dame s'installe au **Château Royal**, sur le trône laissé vide au
premier écran du jeu. Elle se redéploie ensuite comme n'importe quelle autre
pièce, pour **5 de charge de déploiement** — le prix d'une Tour. Sa *valeur*
reste 9 : c'est ce que voit l'IA, qui la traite comme la pièce la plus chère du
plateau. Une Dame capturée est perdue comme le pion qu'elle était.

**L'aura de la Dame** : une Dame **laissée au village** tient la cour pendant que
le Roi se bat et rapporte **+15 % d'or** sur chaque victoire
(`Balance.DAME_GOLD_BONUS`). Le bonus se compte par Dame au repos — en déployer
une renonce à sa part pour cette bataille, pas à celle des autres. C'est tout
l'arbitrage du chip **DAME** au placement : une pièce de plus sur le plateau, ou
l'or qu'elle rapporte en restant à la maison. Au village, le château se met à
**rayonner** tant qu'une Dame au moins est là.

**La Dame retrouvée** : la dernière bataille s'appelle « La Tour de la Dame » et
en offre une à la **première victoire** (`"dame"` dans `Balance.CAMPAIGN`). Le
Roi a perdu sa Dame au premier écran ; il la retrouve au bout de sa quête, même
si aucun de ses pions n'a jamais traversé un plateau. Sans ce filet, une
promotion réussie restant un exploit rare, la moitié du jeu resterait éteinte
pour la plupart des joueurs.

**Améliorer les Dames** : elles n'ont pas de bâtiment à elles. Le niveau d'une
Dame est **le plus faible du niveau du Château Royal et du nombre de Dames
abritées** : une seule Dame dans un château Nv.5 reste Nv.1, trois Dames dans un
château Nv.3 sont toutes Nv.3. Il faut donc les deux — un château qui monte et
une collection qui grandit — et aucune Dame n'est jamais dépensée.

### Les pertes, la série, le nul

**Les pertes sont définitives.** Une pièce capturée quitte l'armée et devra être
recrutée à nouveau. C'est ce qui donne son poids au placement — et la raison
d'être de l'écran de campagne, qui permet de rejouer une bataille déjà gagnée
pour refaire de l'or (à 40 % de la récompense). Une **garnison minimale** de
3 pions est rendue gratuitement après chaque bataille, sans quoi une armée
balayée sans or rendrait la partie impossible à reprendre.

À partir de la **deuxième** bataille, un niveau de campagne se gagne en une
**série** — deux combats d'affilée, puis trois pour les trois dernières, sans
retour au village. L'armée ennemie revient au complet à chaque combat, toi avec
tes survivants : c'est l'usure qui fait la difficulté. Entre deux combats,
2 points de poids se relèvent parmi tes pertes, les moins chères d'abord — deux
pions se relèvent, jamais une tour. L'or n'est versé qu'à la fin, et un seul
combat perdu fait tomber la série entière.

Un combat se termine quand un camp n'a plus de pièce. Si les deux armées ne
peuvent plus s'atteindre (20 tours complets sans la moindre prise), la victoire
va au camp qui conserve le plus de matériel — mais **à égalité stricte, personne
n'a gagné**. Au nul, les survivants rentrent, le combat ne rapporte rien, et la
série n'est pas rompue : c'est un tour d'usure payé pour rien, pas une déroute.
Un camp qui n'a aucun coup légal passe son tour ; deux passes d'affilée et le
match est tranché de la même façon.

### Le niveau de jeu de l'IA

Chaque bataille déclare celui de l'**armée ennemie** (`ai` dans
`Balance.CAMPAIGN`). Ces niveaux ne changent aucune règle : ils retirent des
précautions à l'IA, ils ne lui donnent aucun privilège. **Ce sont trois
profondeurs de recherche**, pas trois jeux d'heuristiques.

| Niveau | Profondeur | Ce qu'elle voit |
|---|---|---|
| **Novice** | 1 demi-coup | Prend ce qui passe. Elle vérifie que sa case d'arrivée n'est pas attaquée, mais ne joue jamais la réponse adverse : elle se fait fourcher |
| **Aguerri** | 2 | La réponse immédiate. Elle ne donne plus une pièce |
| **Expert** | 3 | Sa réplique : fourchettes, enfilades, échanges à trois temps |

Ces niveaux ne valent que pour l'armée ennemie : **le camp du joueur n'est jamais
confié à personne.** La recherche sert encore aux bancs de test (`tools/`), qui
font jouer les deux camps pour simuler des campagnes entières.

### Jouer son tour

Le combat est **tour par tour, une pièce par camp**. Rien ne tourne pendant que
tu réfléchis : aucune horloge, le plateau attend.

- **Taper** une pièce l'allume — pastilles bleues sur les cases libres où elle
  peut aller, anneaux dorés autour des pièces qu'elle peut prendre. Taper une de
  ces cases joue le coup.
- **Glisser** la pièce jusqu'à sa case fait la même chose d'un seul geste ; la
  case survolée s'allume en or quand le coup est légal.

Le dernier coup joué reste surligné : sur un petit écran, c'est ce qui permet de
voir ce que l'adversaire vient de faire. Pendant le placement, les mêmes gestes
servent à poser (tape), retirer (tape sur une pièce posée) et repositionner
(glisse — deux pièces qui se croisent échangent leur case).

L'état du tour s'écrit dans le **badge en haut à gauche**, à côté du numéro de
tour : « TOUR 5 · À TOI DE JOUER ». L'écran de combat n'a **pas** de bandeau en
bas — il en avait un de 77 points qui portait le bouton AUTO et les vitesses ;
tout cela est parti avec ce qui jouait à la place du joueur, et la hauteur est
retournée au plateau.

---

## Où régler le jeu

**Tout l'équilibrage est dans un seul fichier :
[`scripts/data/balance.gd`](scripts/data/balance.gd).**

| Section | Contenu |
|---|---|
| `UNITS` | mobilité, capacité, valeur, coût de recrutement, coût et durée d'amélioration — **sur 10 niveaux** |
| `CASTLE_DATA` | charge déployable par niveau de château, coûts et durées |
| `CAMPAIGN` | les 10 batailles : grille, composition ennemie, niveaux, récompense, `fights` |
| `AI_DEPTH`, `AI_BUDGET_MS` | profondeur et budget de réflexion de la recherche |
| `COMBAT` | durées d'animation, seuil d'enlisement, garde-fou d'activations |
| `GARRISON_MINIMUM`, `REPLAY_REWARD_RATIO` | filet de sécurité et rentabilité du farm |
| `RUN_REINFORCE_WEIGHT` | renforts entre deux combats d'une série |
| `PROMOTION_CONTESTED_RATIO` | le seul bouton à tourner si les Dames sont trop fréquentes ou trop rares |
| `UNLOCK_CASTLE_LEVEL` | niveau de château auquel Cloître / Donjon apparaissent |

Les tableaux sont indexés par niveau : ajouter un niveau = ajouter une valeur à
chaque tableau de la pièce, et augmenter `MAX_LEVEL`. Le banc de test vérifie que
les tailles concordent et que la mobilité ne recule jamais d'un niveau au suivant.

Deux entrées de `CAMPAIGN` sont à distinguer : **`level` est le niveau des
pièces ENNEMIES**, `player` celui auquel le joueur est censé aborder la
bataille. Les deux étaient confondus tant que l'avantage du joueur était fait de
nombre ; ils se séparent depuis qu'il est fait de qualité — moins de pièces,
mieux équipées, face à un adversaire plus nombreux et plus fruste.

⚠️ **Toucher aux effectifs ennemis ou à leur niveau, c'est toucher au niveau de
jeu réel de l'IA.** Le coût d'un coup suit le nombre de coups légaux, donc les
effectifs *et* les portées. En passant la dernière bataille de 11 à 14 pièces par
camp, la profondeur 3 est passée de 139 ms à 396 ms et est sortie du budget :
l'IA déclarée experte retombait à la profondeur 2 sans que rien ne le dise.
Relancer `tools/ai_probe.tscn` après, systématiquement.

L'habillage (couleurs, arrondis, marges) est isolé dans
[`scripts/ui/ui_theme.gd`](scripts/ui/ui_theme.gd).

---

## Architecture

Principe directeur : **la logique de jeu ne connaît pas l'affichage**. Tous les
fichiers de `scripts/battle/` sont des objets purs, sans aucun nœud Godot. Ils
sont donc simulables en headless — c'est ce qui permet aux bancs de jouer des
campagnes entières.

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
  battle/battle_search.gd   negamax alpha-bêta, les niveaux aguerri et expert
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
  battle/battle_prep.tscn     briefing avant combat
  battle/battle.tscn          placement, combat et résultat (une seule scène)
  battle/battle_result.gd     victoire / défaite / nul — trois peaux d'un écran
  ui/components/              plaque royale, modale, chips, icônes, pastilles

tools/                     les bancs — voir la section Tests
```

### Trois choix à connaître

- **Une seule scène de bataille**, à trois phases (placement → combat →
  résultat). L'état du placement n'a ainsi jamais à transiter entre deux scènes.
- **Les données d'équilibrage sont des dictionnaires GDScript**, pas des
  ressources `.tres` : éditables dans n'importe quel éditeur de texte, lisibles
  en diff Git, modifiables sans ouvrir Godot.
- **Les améliorations sont stockées comme un timestamp Unix de fin.** Le temps
  passe donc normalement jeu fermé.

### Les deux entrées du moteur

`BattleEngine.play_move(unit, cell)` joue le coup choisi par le joueur ;
`BattleEngine.step()` demande à l'IA de choisir **et** de jouer celui du camp
courant. Les deux retournent la liste des événements correspondants (`move`,
`capture`, `promotion`, `pass`, `end`), que la vue rejoue ensuite. Le coup est
déjà résolu quand l'animation commence : **l'animation ne décide de rien, elle
montre.**

### Vérifier la mise à l'échelle

```bash
godot --path . tools/resolutions.tscn
```

Rend le village, la campagne, la préparation et le placement en 393×852,
360×800, 375×812, 412×915 et 430×932, et enregistre une capture par combinaison
dans `tools/screenshots/echelle/`. C'est la façon la plus rapide de voir ce qui
déborde : le jeu est calé sur 393×852, et en `stretch/aspect = expand` un
téléphone d'un autre format ne redimensionne pas, il **révèle** de la hauteur en
plus (873 points sur un 360×800). Tout ce qui est posé en coordonnées absolues
s'y décale.

---

## Tests

```bash
godot --headless --path . tools/smoke_test.tscn
```

Le banc principal, ~70 s. Vérifie la cohérence des tableaux de `balance.gd`,
l'économie, la formation mémorisée, la détection des menaces, le retrait des
pertes, les règles de pièces sur des plateaux montés à la main, la série de
combats, puis simule les 10 batailles et charge tous les écrans.

| Banc | La question à laquelle il répond |
|---|---|
| `tools/smoke_test.tscn` | est-ce que tout tient encore debout ? |
| `tools/ui_test.tscn` | est-ce que les vrais boutons répondent ? |
| `tools/ai_probe.tscn` | combien coûte un coup à chaque profondeur ? |
| `tools/ai_bench.tscn` | est-ce que chercher plus loin fait gagner ? |
| `tools/tune_probe.tscn` | de combien de niveaux le joueur doit-il dominer ? |
| `tools/economy_probe.tscn` | la campagne verse-t-elle de quoi se traverser ? |
| `tools/promo_probe.tscn` | combien de Dames une campagne produit-elle ? |
| `tools/debug_battle.tscn` | pourquoi cette bataille tourne mal ? |
| `tools/screenshot.tscn` | à quoi ressemblent les écrans ? |
| `tools/resolutions.tscn` | qu'est-ce qui déborde sur les autres téléphones ? |

### Deux règles de mesure, apprises à la dure

**Un banc chronométré n'est pas une mesure.** La recherche coupe au temps
(`AI_BUDGET_MS`), donc à un endroit qui dépend de la machine et de sa charge :
deux bancs lancés sur la même position rendaient deux verdicts différents. Les
bancs posent donc `BattleAI.budget_ms = 0` — aucune limite, la recherche va au
bout de sa profondeur. Ils jouent alors contre une IA au moins aussi forte que
celle du jeu, jamais plus faible : une bataille qu'un banc déclare gagnable l'est
à coup sûr.

**Un seul combat n'est pas une mesure non plus.** Le combat est déterministe,
d'où l'idée qu'un essai suffisait à prouver un résultat. C'est faux : sur la
bataille 10, baisser le *seul* niveau ennemi donnait `NUL, NUL, PERDUE, gagnée`.
Un coup différent au troisième tour envoie la partie ailleurs. `tune_probe` lit
donc un **taux sur plusieurs formations**, jamais un tirage.

### L'économie : la courbe des récompenses suit celle des coûts

C'est le réglage le moins intuitif du jeu, et celui qui s'est révélé faux.

Le prix des niveaux monte **géométriquement** — atteindre le niveau 6 partout
coûte 19 090 or de bâtiments. Les récompenses, elles, montaient presque
linéairement : 3 590 or pour toute la campagne. Un facteur quatre et demi, qui
ne se rattrape pas en jouant mieux. `economy_probe` mesurait 11 replays pour
franchir la bataille 3 et **36 pour la bataille 7** — ce n'est pas de la
difficulté, c'est de la corvée, et personne ne la fait sur un téléphone.

Les récompenses vont maintenant de 150 à 5 000, calées pour que le cumul versé
**avant** une bataille couvre ce qu'elle demande, avec une marge pour les
recrues. Aucun coût n'a bougé : c'est le rapport entre les deux qui était faux.

**La récompense est celle d'un COMBAT, pas d'une bataille.** Une série de trois
combats paie trois fois cette valeur — c'est ce qu'annonce l'écran de
préparation, « Récompense de la série ». Huit batailles sur dix étant des
séries, se tromper là-dessus fausse tout le calcul d'un facteur deux à trois.
C'est exactement l'erreur qu'a faite la première version de la sonde, et la
première correction des récompenses avait été calibrée sur ce chiffre faussé.

⚠️ **Toucher à `upgrade_cost` sans relancer la sonde, c'est rouvrir le trou.**

La sonde déclare désormais la **corvée**, pas seulement l'impossible : au-delà
de douze replays pour une seule bataille, la campagne a échoué même si elle
reste théoriquement franchissable. Elle sait aussi reconnaître l'**impasse** —
plus d'or et plus aucune bataille qu'on regagne.

Une nuance mesurée, à connaître avant de retoucher `player` : les bancs de
bataille jouent **un combat**, alors que la plupart des batailles sont des
séries de deux ou trois. La série use, donc elle demande un peu plus que le
niveau déclaré — la bataille 8 a réclamé des casernes un cran au-dessus. Ce
n'est plus un problème depuis que l'économie suit : le joueur a de quoi
dépasser le niveau prévu. `player` est un plancher, pas une cible.

### Équilibrage vérifié

Deux compositions sont testées par bataille — une armée variée et une armée de
pions — et il en faut une qui passe. Exiger qu'une composition unique gagne
partout nierait l'intérêt du choix d'armée : contre des pions, ce sont les pions
qui répondent.

Le cas le plus important est le dernier de la liste : il joue la toute première
bataille avec l'armée de départ exacte, sans un seul recrutement. C'est lui qui a
détecté que le premier combat du jeu était perdu.

---

## Limites connues

- **Sur un téléphone lent**, la recherche peut sortir de son budget et redescendre
  d'un demi-coup. C'est une dégradation propre — le meilleur coup de la dernière
  profondeur achevée — mais elle rend l'IA un peu plus faible que déclarée.
- Le Roi n'est pas une pièce jouable : le château fixe la charge déployable.
- Aucune migration de sauvegarde : changer `SAVE_VERSION` repart de zéro.
- Village et préparation sont encore posés en coordonnées absolues (cf. la règle
  « ancrer, ne pas positionner » dans `CLAUDE.md`).
