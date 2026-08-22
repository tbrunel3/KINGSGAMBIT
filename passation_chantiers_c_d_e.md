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
| **C** | **La composition d'armée** | à faire — le plus gros |
| **D** | **Polices et animations Figma** | à faire |
| **E** | **Les popups d'accompagnement** | à faire **en dernier** |

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

# C — la composition d'armée

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

## Deux pièges du projet qui guettent les trois chantiers

1. **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` sur tout libellé.** Dans un
   conteneur horizontal, toutes les colonnes se partagent alors la largeur à
   parts égales. Ça a coûté une demi-heure sur le codex : le tableau semblait
   correct et ne l'était pas. Toute colonne à largeur fixe doit repasser
   explicitement en `SIZE_FILL` — et un écran de slots est fait de colonnes.
2. **Mesurer avant d'accuser le jeu.** La sonde économique s'est trompée quatre
   fois de suite, et les quatre fois le défaut était dans l'instrument. Le bug
   de l'IA figée, lui, a été reproduit et instrumenté avant d'être corrigé :
   c'est ce qui a permis de trouver trois défauts au lieu d'un.
