# Passation — chantiers C, D et E

**Ce document existe parce que le travail change de session.** Une fenêtre
neuve repart à froid : elle aura [`CLAUDE.md`](CLAUDE.md), mais pas ce qui
s'est dit pendant le découpage. Il dit ce qu'on cherche, ce que le code fait
**déjà** — c'est la partie la plus utile —, et les décisions qui n'ont pas été
prises.

Lis [`CLAUDE.md`](CLAUDE.md) en premier. Ce document ne le répète pas.

---

## D'où ça vient

Le joueur a signalé cinq choses d'un seul message, après avoir testé le jeu sur
son téléphone. Elles ont été découpées parce qu'elles ne touchent pas les mêmes
sous-systèmes, et parce que la première rendait les autres intestables.

| | Chantier | État |
|---|---|---|
| **A** | Le combat répond et se termine | ✅ commit `57c307b` |
| **B** | La série s'enchaîne sans écran de victoire | ✅ commit `e2772b7` |
| **C** | La composition d'armée | ✅ fait |
| **D** | Polices et animations Figma | 🟡 **aux trois quarts** — voir ci-dessous |
| **E** | Les popups d'accompagnement | à faire |
| **G + F** | **L'assemblage Figma et le responsive**, ensemble | à faire **en dernier** — voir ci-dessous |

**L'ordre a été fixé par le joueur** : A → B → C → D → E, puis **G et F menés
ensemble**. Sa formulation : « après le E ça devrait être l'assemblage de tout
le projet Figma, adaptation des popups, des images, respect graphique absolu,
et le F avec du coup pour les formats d'écran responsive ».

Les mener ensemble est le bon choix, et pas seulement par commodité : reprendre
la peau d'un écran et la rendre indifférente au format sont **le même geste sur
le même fichier**. Les séparer ferait passer deux fois sur chaque écran.

> **Reprendre ici.** Dans l'ordre :
>
> 1. **Porter l'entrée du placement** (`248:493`, 3 s, 17 nœuds) — la plus
>    riche animation du fichier, et l'écran où le joueur passe le plus de temps.
>    C'est ce qui reste de D.
> 2. **Le chantier E**, avec deux nouveautés à lire d'abord : la maquette
>    contient désormais un `popup-combat-phase` (`378:4`) et un `shop-screen`
>    (`347:4`) qui n'existaient pas au découpage.
> 3. **G + F ensemble.** Le passage au crible des formats n'a été fait que sur
>    la carte de campagne : il se termine là, écran par écran, en même temps
>    que la reprise graphique.

E vient en dernier délibérément : accompagner un jeu qui va changer, c'est du
travail à refaire.

### Ce que A et B ont changé, et qu'il faut savoir

- **Trois issues sans vainqueur** au lieu d'une : le pat, la position morte,
  l'enlisement. Détaillées dans `CLAUDE.md`.
- **`Balance.COMBAT.stalemate_is_draw`** est un réglage **non tranché** : le
  joueur hésitait entre la règle d'échecs (`true`, en place) et « le camp
  bloqué perd » (`false`). Il doit jouer les deux. Ne pas le figer sans lui.
- **Un combat intermédiaire n'ouvre plus d'écran de victoire** : un bandeau
  (`SeriesBanner`) puis le placement du combat suivant. **C'est la contrainte
  qui pèse le plus sur C** — voir la décision 2 ci-dessous.
- La première série s'explique dans un popup montré une fois
  (`SeriesPopup`, `GameState.has_seen_series_warning`). C'est le gabarit à
  reprendre pour E.

### Comment lancer les bancs

Godot est installé par winget, il n'est pas dans le `PATH` :

```bash
"$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . tools/smoke_test.tscn
```

`screenshot.tscn` et `resolutions.tscn` écrivent des PNG : les lancer **sans**
`--headless`, sinon ils bloquent.

---

# C — la composition d'armée ✅ FAIT

**Ce chantier est terminé.** Ce qui suit garde la trace de la demande et du
raisonnement ; les décisions prises sont en tête, et le fonctionnement final
est décrit dans [`CLAUDE.md`](CLAUDE.md) > « Recruter fait une réserve,
composer fait une armée ». **Ne pas le reconstruire.**

## Ce qui a été décidé, et livré

| Question | Réponse du joueur |
|---|---|
| Nouvel écran ou `battle_prep` interactif ? | **`battle_prep` interactif**, sur une maquette `169:4` **refaite** par le joueur : ennemi en haut, déploiement au milieu, caserne en bas |
| Recompose-t-on entre deux combats ? | **Non — la composition survit et se réduit** des pertes… |
| | …**mais les renforts doivent être plaçables** : ils rentrent donc dans la composition (`CampaignRun._reinforce`) |
| Où se dépense la charge ? | **À la composition seulement** |
| L'idée des casernes (garnison / relèvement) | **Pas maintenant** — toujours ouverte, voir la décision 4 plus bas |

Une découverte non prévue : **la maquette refaite est en thème clair** (crème,
panneaux blancs) alors que tout le jeu est en nuit et or. La rupture a été
signalée au joueur, qui l'a maintenue. `battle_prep` est donc le seul écran
clair du jeu — et il est en **Inter**, pas en Geist, ce qui retire un point du
chantier D.

Mesuré après coup : `smoke_test` tient ses **10/10 batailles gagnables** (le
signal que cette passation demandait de surveiller), `ui_test` joue la
composition, et 360 × 800 ne déborde pas.

Deux pièges payés en le faisant, qui ne sont pas dans la liste générale :

1. **Libérer un nœud pendant que son propre signal émet est refusé par Godot**
   (« Attempted to free a locked object »). La carte de caserne déclenche la
   reconstruction qui la libère : sans un `call_deferred`, la carte survivait
   et la composition restait bloquée sur sa première pièce — **sans qu'aucune
   erreur ne remonte à l'écran**.
2. **Un `PanelContainer` ignore les constantes `margin_*`.** Sa marge vient des
   `content_margin` de sa `StyleBox` ; posée en constante, elle ne fait rien et
   le contenu vient coller le trait.

---

## L'archive de la demande


## Ce que le joueur a demandé, dans ses mots

> « après le recrutement de troupe, rien ne change ensuite, il faudrait pouvoir
> recruter des troupes dans chaque batiment et ensuite avant chaque combat on
> aurait un espace slot vide, avec un poids max de bataille défini par le niveau
> du chateau, ou on placerait les pièces que l'on a acqueri, sans pouvoir
> dépasser le poids max, ensuite on aurait accès aux pièces choisi dans le
> panneau déploiement de l'ecran placement_bataille »

## Ce que le code fait DÉJÀ — à lire avant de construire

C'est le point le plus important de cette section. **Le recrutement alimente
bien le placement**, contrairement à ce que le joueur croit :

- `battle.gd` remplit `_remaining[type]` depuis `_run.roster`, qui vient de
  `Game.units_owned()` au moment de `Game.begin_run()`.
- Le placement respecte **déjà** un budget de poids :
  `Balance.deploy_capacity(castle_level)`, de 16 au Nv.1 à 36 au Nv.10, chaque
  pièce coûtant `Balance.deploy_weight()` — Pion 1, Cavalier 3, Fou 3, Tour 5,
  Dame 5.

**Alors pourquoi « rien ne change » ?** Parce que la charge est le vrai plafond,
pas l'effectif. Au château Nv.1 on pose 16 de charge : recruter un dixième pion
ne fait entrer aucune pièce de plus sur le plateau. Le recrutement produit une
**réserve**, pas une armée — et le jeu ne montre nulle part cette distinction.

**Ce qui manque vraiment, c'est l'étape de CHOIX.** Aujourd'hui composer et
placer sont le même geste, sur le même écran, au même moment.

⚠️ Ne pas repartir de la description du joueur sans avoir relu ces deux points :
la moitié de ce qu'il demande existe, et le rebâtir créerait **deux budgets de
charge concurrents**.

## La piste recommandée — et pourquoi

**Ne pas ajouter un quatrième écran. Rendre `battle_prep` interactif.**

[`scenes/battle/battle_prep.tscn`](scenes/battle/battle_prep.tscn) (Figma
`preparation-bataille-v2`, node-id `169:4`) affiche déjà, en lecture seule et
exactement au bon moment : l'armée ennemie, un panneau « TON ARMÉE » avec une
carte par type, une ligne « Charge : 27/28 », et un bouton « PRÉPARER L'ARMÉE ».

Il ne lui manque que le geste. Le rendre interactif donne au joueur son écran de
slots **sans allonger un parcours qui compte déjà quatre écrans** (village →
carte → préparation → placement → combat), et sans dupliquer le budget de
charge.

Le placement ne proposerait alors plus que les pièces **choisies** :
`_remaining` viendrait de la composition et non de l'armée entière. C'est
exactement « on aurait accès aux pièces choisi dans le panneau déploiement ».

Côté maquette, deux choses n'ont jamais été ouvertes et peuvent contenir la
réponse du designer :

- **`04_Bataille_Placement_2boutons`**, node-id `287:308` — rend noir à
  l'export, il faut l'ouvrir dans Figma.
- une section **« RETOUR — écrans de bataille (relecture du 22/0… ) »** sur la
  page « Écrans triés » (`248:2`), jamais lue.

## Les décisions à poser au joueur AVANT de coder

> **Toutes tranchées sauf la 4** (les casernes), que le joueur a explicitement
> reportée. Le reste est archive.


1. **Nouvel écran, ou `battle_prep` interactif ?** Recommandation ci-dessus,
   mais c'est son parcours.

2. **Recompose-t-on avant CHAQUE combat d'une série ?** *La question la plus
   délicate du chantier.* Depuis B, un combat gagné enchaîne par un bandeau et
   repart droit au placement, sans repasser par la préparation. Or les pertes
   du combat 1 changent ce qu'on peut composer au combat 2. Trois réponses :
   - composition **unique** pour toute la série — simple, mais on subit ses
     pertes sans pouvoir réagir ;
   - recomposition **à chaque combat** — cohérent, mais ça remet un écran entre
     deux combats, exactement ce que B vient d'enlever ;
   - la composition **survit et se réduit** automatiquement des pertes.

3. **La composition est-elle mémorisée d'une bataille à l'autre ?** Le placement
   a déjà un bouton « DERNIÈRE FORMATION » ; le même principe s'y applique.

4. **L'idée des casernes.** Le joueur l'a glissée dans une autre réponse :
   « améliorer la caserne des pions tous les x niveaux pourrait améliorer le
   starting pack de pions dans les batailles ». Deux lectures, **il faut
   demander laquelle** :
   - le **plancher de garnison** (`Balance.GARRISON_MINIMUM`, 3 pions offerts
     après chaque bataille) monte avec le niveau de la caserne ;
   - le **relèvement entre deux combats** (`Balance.RUN_REINFORCE_WEIGHT`, un
     poids fixe) monte avec le niveau de la caserne.

   « Starting pack **dans les batailles** » penche pour la première. Les deux
   sont des valeurs de `balance.gd` — mais la première touche l'économie et
   demande `economy_probe`, qui prend plusieurs heures.

5. **Où se dépense la charge ?** À la composition, ou au placement ? **Les deux
   à la fois serait un piège** : deux plafonds qui se ressemblent, et le joueur
   ne saurait plus lequel le bloque.

## Les fichiers qui comptent

| Fichier | Ce qu'il porte |
|---|---|
| [`scenes/battle/battle_prep.gd`](scenes/battle/battle_prep.gd) | l'écran de préparation, panneau « TON ARMÉE » compris |
| [`scenes/battle/battle.gd`](scenes/battle/battle.gd) | la phase de placement, `_remaining`, la charge posée |
| [`scripts/core/campaign_run.gd`](scripts/core/campaign_run.gd) | `roster`, pertes de série, relèvement |
| [`scripts/core/game_state.gd`](scripts/core/game_state.gd) | `units_owned`, `begin_run`, plancher de garnison |
| [`scripts/data/balance.gd`](scripts/data/balance.gd) | `deploy_capacity`, `deploy_weight`, `GARRISON_MINIMUM`, `RUN_REINFORCE_WEIGHT` |

## Comment le prouver

- `ui_test` joue déjà le placement et la série ; il devra jouer la composition.
- `smoke_test` déclare **10/10 batailles gagnables**. Si la composition
  restreint ce qu'on peut poser, **ce chiffre peut tomber** : c'est le premier
  signal à surveiller.
- `economy_probe` est **obligatoire** si le chantier touche au plancher de
  garnison ou aux coûts de recrutement.
- `resolutions` : un écran de slots se serre vite sur 360 points de large.

---

# D — polices et animations

## Les polices : la demande contredit une règle du projet

Le joueur a écrit : « change les polices d'ecriture comme ils sont sur les
ecrans figma ». Les maquettes sont en **Geist** ; le jeu ne l'embarque pas.

État réel de `assets/fonts/` — noter que **`CLAUDE.md` en annonce trois et il y
en a quatre** :

| Police | Poids | Usage |
|---|---|---|
| `Inter.ttf` | 876 Ko | tout le jeu (`UiTheme.font`, `font_bold`, `font_black`) |
| `ComicRelief-Regular.ttf` | 80 Ko | la voix du Roi |
| `Jaro.ttf` | 146 Ko | les enseignes (`font_display`) |
| `Lora.ttf` | 212 Ko | `font_title`, deux usages seulement |

Le précédent qui fait règle : **Jua a été retirée parce qu'elle pesait 2,1 Mo
pour un seul mot.** Embarquer Geist n'est donc pas interdit — c'est un arbitrage
à faire les chiffres en main, et personne ne les a mesurés.

**Trois options, à trancher avec le joueur :**

1. **Embarquer Geist** et l'utiliser là où la maquette la met. Peser le fichier
   d'abord ; le build web fait déjà 55 Mo.
2. **Garder Inter** et aligner les maquettes dessus. C'est ce qui a été fait
   pour `codex-popup-v3` (`321:2`), converti de Geist vers Inter — les autres
   frames sont restées en Geist. Cohérent, gratuit, mais c'est le designer qui
   cède.
3. **Geist pour les titres seulement**, Inter pour le corps. Compromis, et ça
   pourrait remplacer Lora, qui ne sert que deux fois.

**Un point déjà acquis** : la maquette refaite de la préparation (`169:4`) est
intégralement en **Inter** — `Inter:Bold`, `Inter:Extra_Bold`,
`Inter:Semi_Bold`, `Inter:Black`. Le désaccord Geist/Inter ne porte donc pas
sur cet écran, et il faut vérifier combien d'autres frames le designer a
converties depuis.

⚠️ Un relevé est nécessaire avant de choisir : **quelles frames utilisent quoi**.
Le script qui l'a fait pour le codex est réutilisable — `getStyledTextSegments(['fontName'])`
sur tous les nœuds `TEXT` d'une frame, via `use_figma`.

## Les animations : le relevé est PÉRIMÉ

Un relevé complet a été fait sur les seize frames du fichier : **deux** avaient
une timeline, les deux écrans d'intro, déjà portées.

**Ce relevé est faux aujourd'hui.** Le designer en a ajouté au moins une depuis
— l'écran de nul `348:2` (3 s, sept nœuds), découverte parce que le joueur en a
donné le lien. **Refaire le relevé sur toutes les frames** avec
`get_motion_context` en `recursive`, y compris celles de la page « Écrans
triés » (`248:2`), qui n'a jamais été passée au peigne.

Ce qui est déjà porté, et qui donne le langage à reprendre :

| Fichier | Ce qu'il anime |
|---|---|
| `scenes/intro/king_intro_dialogue.gd` | élévations, posé de l'illustration, retard de l'invite |
| `scenes/battle/battle_result.gd` | `_animate_entry` — l'entrée relevée sur `348:2`, appliquée aux trois peaux |
| `scenes/battle/series_banner.gd` | la même, en plus court |
| `scenes/battle/campaign.gd`, `scenes/village/village.gd` | halos et respirations |

**Deux pièges déjà payés sur les animations :**

- La **boucle** de Figma est un artefact d'aperçu : ce qui compte, ce sont les
  décalages, les durées et les courbes. L'entrée ne se joue qu'une fois.
- **Ne jamais animer la `position` d'un enfant de conteneur.** Le bandeau de
  série s'est collé en haut de l'écran parce qu'un tween de position se battait
  avec le `CenterContainer`. Animer l'opacité et l'échelle ; pour l'échelle,
  poser `pivot_offset` **après** la mise en page.

---

# D — état réel : les deux prémisses étaient fausses

**Les deux moitiés du chantier reposaient sur des relevés périmés. Refaits.**

## Les polices : il n'y a rien à faire

La demande était « change les polices comme sur Figma », et ce document
annonçait des maquettes en **Geist**. **C'est faux aujourd'hui.** Relevé sur
les 1 200 nœuds de texte des 30 frames, via `use_figma` et
`getStyledTextSegments(['fontName'])` :

**tout le fichier est en Inter**, la police que le jeu embarque déjà. Restent
quatre glyphes égarés — `Jua` dans `village-avec-dame` et `07-bataille-nulle`,
`Lilita One` dans `king-intro-dialogue`. Jua ayant été retirée pour son poids
(2,1 Mo pour un mot), il n'y a **ni arbitrage à poser, ni police à embarquer**.
Les trois options de ce document sont sans objet.

## Les animations : le relevé était périmé, et pour une raison précise

**Les timelines vivent sur les COPIES de la page « Écrans triés » (`248:2`),
pas sur les originaux.** Un relevé fait sur la page principale — ce qu'avait
fait la session précédente — ne peut pas les voir. Le fichier a d'ailleurs
**trois pages**, et `get_metadata` sans `nodeId` n'en annonce qu'une.

L'inventaire complet est dans [`CLAUDE.md`](CLAUDE.md). Ce qui reste :

- ⚠️ **`248:493` — l'entrée du placement, 3 s, 17 nœuds.** La plus riche du
  fichier, et non portée. Grille qui zoome de 1,08, badge de tour qui tombe de
  −80 px avec rebond, HUD qui glisse de +70 px, bandeau qui monte de +200 px,
  quatre puces qui éclosent en ressort en cascade, lueur verte pulsée sur
  COMBATTRE.
- `287:308` — un fondu au noir de 0,5 s. C'est **lui** qui explique pourquoi
  cette frame « rend noir à l'export » : la question est close, il n'y a rien
  à réparer.

**Fait :** l'entrée de la préparation (`248:406`, 2 s, 12 nœuds), portée en
opacités et échelles — pas en translations, parce que ses panneaux sont
enfants d'un `VBoxContainer`.

⚠️ **Une animation d'entrée rend les bancs de capture menteurs**, et je m'y
suis fait prendre : la préparation ressortait quasiment vide de
`resolutions.tscn`, et j'ai d'abord accusé la mise en page. Les deux outils
sautent maintenant à la fin des tweens (`_finish_animations`). **Tout nouvel
outil de capture doit faire pareil.**

---

# F — le format d'écran (chantier neuf)

## D'où ça vient

Le joueur a testé le build web sur son téléphone et signalé « des dégradés
bizarres vu que j'ai pas le même format que les fenêtres web ».

## Ce qui est fait

La **carte de campagne** est corrigée, et les cinq pièges rencontrés sont
écrits dans [`CLAUDE.md`](CLAUDE.md) > « Le format d'écran ». En résumé : la
largeur en unités de jeu ne descend jamais sous 393 (c'est la HAUTEUR qui
varie), un `Control` enfant de `ScrollContainer` ne s'étire pas, un dégradé
approximé par bandes raye sur un format non entier, et `parchment_map.jpg`
avait **30 px de barre brune cuits dans chaque bord** par l'export Figma.

`EdgeFades` a été réécrit en vraies textures de dégradé — **ne pas revenir aux
bandes**. Le parchemin a été recadré (786 → 726).

## Ce qui reste

- **Passer les six autres écrans au crible.** `resolutions.tscn` a désormais
  trois tailles hors format (`web-393x700`, `court-360x620`,
  `tres-long-430x1080`) : ce sont **elles** qu'il faut regarder. Seule la carte
  a été traitée.
- ⚠️ **Le banc lui-même était l'angle mort** : ses cinq définitions d'origine
  avaient toutes le même format. C'est la quatrième fois dans ce projet que le
  défaut est dans l'instrument — relire l'instrument avant d'accuser le jeu.
- **Tester sur un vrai téléphone**, pas dans un navigateur intégré : celui-ci
  force un DPR de 2 et rend Godot dans le quart supérieur gauche, ce qui est un
  artefact de l'outil et fait perdre du temps. `python tools/serve_local.py docs`
  sert le build en HTTPS sur le réseau local (le HTTPS est **obligatoire** :
  Godot refuse de démarrer hors contexte sécurisé).

---

# E — les popups d'accompagnement

## Ce que le joueur a demandé

> « Si tu vois des choses mis en place pas clair pour le joueur propose moi des
> pop up d'accompagnement, ui ou d'ux »

C'est une **proposition à lui faire**, pas une liste à exécuter. Et c'est le
dernier chantier : C va changer la boucle de jeu, donc tout ce qu'on expliquerait
avant serait à réécrire.

## Ce qui existe déjà — ne pas le refaire

| Où | Ce qui est expliqué |
|---|---|
| Le point **i** en bataille (`battle._open_help`) | la charge au placement, les règles en combat — un texte différent par phase |
| `SeriesPopup` | la série, une fois, à la première rencontre |
| `MissionPopup` | les objectifs, qui remplacent un tutoriel |
| `CodexPopup` | mobilité par niveau, casernes, six règles de combat |
| `ConfirmUpgrade` | ce qu'on engage avant une amélioration longue |

## Deux écrans neufs à lire AVANT de proposer quoi que ce soit

Le designer a ajouté depuis le découpage, et ni l'un ni l'autre n'est intégré :

- **`378:4 popup-combat-phase`** — un popup de phase de combat. Il recouvre
  peut-être déjà une partie de ce que E allait proposer : à ouvrir en premier.
- **`347:4 shop-screen`** — la boutique. `CLAUDE.md` la déclarait « jamais
  dessinée » ; elle l'est. Ses RÈGLES, elles, ne sont toujours pas écrites
  (coffres horaires, gemmes, accélération d'améliorations), et le retour du
  designer `294:2` la met explicitement **hors périmètre** en attendant son
  propre brief et sa mesure économique. Ne pas l'anticiper.

## Les candidats repérés, par ordre de gravité

1. **Le pat qui vole une victoire.** Tu mènes 6 contre 3, l'ennemi n'a plus que
   des pions bloqués, et c'est nul. C'est la règle des échecs et c'est correct,
   mais **rien ne prévient**, et ça arrive sur la bataille 1. Mesuré : 6 des 19
   parties du banc. Un popup à la **première** fois, expliquant la ressource du
   pat, est probablement le plus utile du jeu. *(Sans objet si le joueur bascule
   `stalemate_is_draw` à `false`.)*
2. **Réserve ou armée ?** La distinction que C va introduire. Recruter remplit
   une réserve ; la charge décide de ce qui part au combat. C'est exactement ce
   que le joueur lui-même n'avait pas compris.
3. **Le sacre prend un tour.** `Balance.PROMOTION_TAKES_A_TURN` : un pion arrivé
   au fond attend un tour avant de devenir Dame, et l'adversaire a un coup pour
   l'en empêcher. Subtil, décisif, et expliqué nulle part.
4. **L'aura de la Dame.** Une Dame laissée au village rapporte +15 % d'or. C'est
   un vrai choix — la déployer ou l'encaisser — et il est indevinable.
5. **Les améliorations en temps réel**, de 30 secondes à 4 heures.
   `ConfirmUpgrade` couvre l'engagement ; reste à savoir si le joueur comprend
   qu'il peut fermer le jeu pendant.

## La règle de forme

Un popup qui se rouvre est une punition. Le gabarit est
[`scenes/battle/series_popup.gd`](scenes/battle/series_popup.gd) : un drapeau
dans `GameState` (`has_seen_*` / `mark_*_seen`, avec `_state.get(..., false)`
pour rester compatible avec les vieilles sauvegardes), et **aucun chiffre écrit
dans le texte** — tout est interpolé depuis `Balance`, sans quoi le popup se met
à mentir dès qu'on règle le jeu.

---

---

# G + F — l'assemblage Figma et le responsive, menés ensemble

**Décidé par le joueur, à faire après E.** « L'assemblage de tout le projet
Figma, adaptation des popups, des images, respect graphique absolu, et le F
avec du coup pour les formats d'écran responsive. »

## Le reste à intégrer, concrètement

Relevé sur le fichier au 22/08. Ce sont les écrans dessinés que le jeu
n'affiche pas encore, ou affiche autrement :

| Écran | node-id | État |
|---|---|---|
| `mission-popup` | 228:9 | le panneau existe côté code, la peau n'est pas reprise |
| `09` / `10` / `11` — popups de bâtiment | 2:1048 / 2:1115 / 2:1165 | le code couvre les quatre états dans une seule scène (`building_popup.gd`) ; `screenshot.tscn` en capture deux (`1e_`, `1f_`) pour comparer |
| **`popup-combat-phase`** | 378:4 | **jamais ouvert** — à lire pendant E, il recouvre peut-être une partie de ce que E allait proposer |
| **`shop-screen`** | 347:4 | **dessiné, mais hors périmètre** — voir ci-dessous |
| `248:493` placement | — | son entrée animée (17 nœuds) reste à porter |

Deux écrans existent **sans avoir jamais été dessinés** : l'écran de match nul
(fabriqué en repeignant la victoire en acier) et — plus maintenant — la
boutique.

## Trois choses à savoir avant de commencer

**1. « Respect graphique absolu » ne peut pas vouloir dire transcrire les
libellés.** La règle 2 du projet tient : la maquette apporte l'apparence,
jamais les règles. Le projet l'a déjà payé deux fois — le `codex-popup` v1
décrivait un autre jeu (PV, ATK, soins, plateau 8×11, huit bâtiments), et la
préparation refaite annonce encore « Points: 0/15 » et « Plateau 8×11 cases ».
Les deux ont été corrigés côté libellé, pas côté code. **Reprendre la peau : oui.
Reprendre les chiffres : jamais** — ils se régénèrent depuis `Balance`.

**2. La boutique est explicitement hors périmètre**, et pas par oubli. Le retour
du designer (`294:2`) l'écrit : « une boutique arrive dans le jeu — coffres,
gemmes, accélération des améliorations. Elle NE FAIT PAS PARTIE de ce retour et
aura son propre brief, une fois ses règles écrites et son économie mesurée. »
Elle est dessinée depuis ; **ses règles ne le sont toujours pas**. L'intégrer
sans économie mesurée rouvrirait le trou que `economy_probe` a mis des heures à
fermer.

**3. Le responsive et la fidélité au pixel se contredisent, et il y a un
bouton.** `window/stretch/aspect` vaut `expand` : le viewport épouse l'écran, et
c'est ce qui oblige chaque écran à être ancré. Le passer à **`keep`** donne une
zone de jeu de 393 × 852 **exactement**, avec des bandes noires sur les écrans
plus allongés — la fidélité devient absolue, le responsive disparaît.

⚠️ **C'est une décision à poser au joueur au début de G**, pas à trancher en
chemin : elle change la nature du chantier. « Respect graphique absolu » et
« formats d'écran responsive » sont dans la même phrase de sa demande, et ils
ne peuvent pas être vrais tous les deux au pixel près.

## Comment le prouver

- `resolutions.tscn`, et **d'abord ses trois tailles hors format** — c'est le
  seul outil qui voit un problème de format, et il ne le voyait pas avant.
- `screenshot.tscn` pour comparer écran par écran avec la maquette.
- `ui_test` doit rester vert : une reprise graphique qui casse un bouton ne se
  voit sur aucune capture.

---

## Deux pièges du projet qui guettent tous les chantiers restants

1. **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` sur tout libellé.** Dans un
   conteneur horizontal, toutes les colonnes se partagent alors la largeur à
   parts égales. Ça a coûté une demi-heure sur le codex : le tableau semblait
   correct et ne l'était pas. Toute colonne à largeur fixe doit repasser
   explicitement en `SIZE_FILL` — et un écran de slots est fait de colonnes.
2. **Mesurer avant d'accuser le jeu.** La sonde économique s'est trompée quatre
   fois de suite, et les quatre fois le défaut était dans l'instrument. Le bug
   de l'IA figée, lui, a été reproduit et instrumenté avant d'être corrigé :
   c'est ce qui a permis de trouver trois défauts au lieu d'un.
