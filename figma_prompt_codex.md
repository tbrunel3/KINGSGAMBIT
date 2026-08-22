# Prompt Figma — King's Gambit, le codex et deux demandes annexes

Ce brief est celui qui a manqué au codex. Il concerne le fichier
`rqEdH4O2R21TuUFv7OUlF7` et trois choses :

1. **`codex-popup`** — node-id **194:4**. La mise en page est juste et on la
   garde ; **les données décrivent un autre jeu** et sont toutes à refaire.
   Le résultat est posé dans une frame neuve, **`codex-popup-v3`**, à côté de
   l'originale — rien n'est écrasé.
2. **La carte de campagne illustrée** — l'image posée à côté des frames, avec
   les numéros d'étape dessinés dedans. On en veut une version **sans les
   numéros**.
3. **La Dame captive** — la pièce derrière des barreaux. Elle n'a aucun écran
   qui l'affiche. On lui en demande un : le bandeau d'enjeu de la **bataille
   10**.

Le contexte général du jeu est dans [`figma_contexte_projet.md`](figma_contexte_projet.md).
Ce document ne le répète pas ; il donne **les chiffres**.

---

## 1. Le codex

### Pourquoi il est à refaire

Ce n'est pas une critique du dessin. Le codex a été dessiné sans brief, et il
a inventé des règles plausibles pour un jeu de tactique — sauf que ce n'est pas
ce jeu-ci.

| Le codex écrit | Le jeu |
|---|---|
| des colonnes **PV** et **ATK** par niveau | **ni points de vie ni dégâts** — une pièce est debout, ou capturée |
| « Charge : +50 % dégâts », « Bénédiction : soigne 10 PV/tour », « Frappe royale : dégâts ×2 » | rien de tout cela n'existe |
| « Roque : peut échanger de position avec le Roi » | il n'y a **pas de Roi** sur le plateau |
| une carte **LE ROI**, et « défaite si votre Roi est vaincu » | idem — le Roi est le narrateur, pas une pièce |
| « champ quadrillé de 8 cases sur 11 » | de **5×6 à 8×9** selon la bataille |
| « commandes de vitesse ×1, ×2, ×4 » | retirées — rien ne joue à la place du joueur |
| 8 bâtiments (Donjon de Fer, Cathédrale, Académie militaire, Chapelle de soins) | **5** : le Château Royal et quatre casernes |
| « Écuries des Cavaliers — Recruter : 150 Or » | Écuries — **90 Or**, et le prix **monte** à chaque recrue |

### La structure : elle ne bouge pas

Plaque de titre + croix de fermeture, rangée de puces de filtre, une carte par
pièce (en-tête, divider orné, illustration + description, tableau par niveau,
pied de carte), puis la section des bâtiments et celle des règles. **Garde tout
ça.** Trois ajustements seulement, et ce sont des défauts mécaniques, pas des
choix de goût :

- **La rangée de puces déborde déjà** : 404 pt de puces dans un conteneur de
  361. Elle passe à **6 puces** (le ROI disparaît) et devient une bande à
  **défilement horizontal**.
- **La colonne `BONUS / INFO` fait 100 pt** pour du texte qui en demande le
  double. Les quatre colonnes sont redistribuées au profit de la mobilité, qui
  est de loin la plus longue.
- **Tout en auto-layout.** La frame actuelle est posée en coordonnées absolues
  sur 4 537 pt de haut. C'est la règle 2 de la collaboration : un écran calé en
  dur se décale dès que l'appareil change de taille.

### Les cartes : 5, plus de Roi

`TOUS · PION · CAVALIER · FOU · TOUR · DAME`

Chaque carte porte, dans son en-tête, une puce **POIDS** — c'est ce que la
pièce coûte dans le budget de placement, et l'écran de préparation l'affiche
déjà sous la forme « Charge : 7/16 ».

Dans le corps de la carte, la ligne « Attaque » devient **« Capture »**, parce
qu'il n'y a pas d'attaque séparée : **on capture en se déplaçant sur la case
adverse**, comme aux échecs.

### Les chiffres

Ce qui suit est **généré depuis le code du jeu**, pas recopié. Les dix niveaux
y sont : le codex est la référence, c'est le seul endroit où le joueur peut
voir la courbe entière.

### PION — poids 1, valeur 1
Caserne des Pions — recrutement **35 Or** (+8 par pion déjà possédé)

| NIVEAU | MOBILITÉ | CASERNE | AMÉLIORATION |
|---|---|---|---|
| Nv.1 | en avant 1 case, capture en diagonale | 8 | 150 Or |
| Nv.2 | en avant 1 case, 2 au premier coup, capture en diagonale | 10 | 300 Or |
| Nv.3 | en avant 1 case, 2 au premier coup, capture en diagonale | 12 | 500 Or |
| Nv.4 | en avant 1 case, 2 au premier coup, capture en diagonale | 14 | 750 Or |
| Nv.5 | en avant 1 case, 3 au premier coup, capture en diagonale | 16 | 1050 Or |
| Nv.6 | en avant 1 case, 3 au premier coup, capture en diagonale | 18 | 1400 Or |
| Nv.7 | en avant 2 cases, 3 au premier coup, capture en diagonale | 20 | 1800 Or |
| Nv.8 | en avant 2 cases, 4 au premier coup, capture en diagonale | 22 | 2250 Or |
| Nv.9 | en avant 2 cases, 4 au premier coup, capture en diagonale | 24 | 2750 Or |
| Nv.10 | en avant 2 cases, 4 au premier coup, capture en diagonale | 26 | — |

### CAVALIER — poids 3, valeur 3
Écuries — recrutement **90 Or** (+18 par cavalier déjà possédé)

| NIVEAU | MOBILITÉ | CASERNE | AMÉLIORATION |
|---|---|---|---|
| Nv.1 | saut diagonal | 4 | 220 Or |
| Nv.2 | saut en L | 5 | 420 Or |
| Nv.3 | saut diagonal, saut en L | 6 | 680 Or |
| Nv.4 | saut diagonal, saut en L | 7 | 1000 Or |
| Nv.5 | saut diagonal, saut en L, saut 3+1 cases | 8 | 1380 Or |
| Nv.6 | saut diagonal, saut en L, saut 3+1 cases | 9 | 1820 Or |
| Nv.7 | saut diagonal, saut en L, saut 3+1 cases, saut 3+2 cases | 10 | 2320 Or |
| Nv.8 | saut diagonal, saut en L, saut 3+1 cases, saut 3+2 cases, saut 4+1 cases | 11 | 2880 Or |
| Nv.9 | saut diagonal, saut en L, saut 3+1 cases, saut 3+2 cases, saut 4+1 cases, saut 4+2 cases | 12 | 3500 Or |
| Nv.10 | saut diagonal, saut en L, saut 3+1 cases, saut 3+2 cases, saut 4+1 cases, saut 4+2 cases, saut 4+3 cases | 13 | — |

### FOU — poids 3, valeur 3
Cloître des Fous — recrutement **80 Or** (+15 par fou déjà possédé)

| NIVEAU | MOBILITÉ | CASERNE | AMÉLIORATION |
|---|---|---|---|
| Nv.1 | diagonales, 2 cases | 4 | 200 Or |
| Nv.2 | diagonales, 2 cases | 5 | 390 Or |
| Nv.3 | diagonales, 2 cases | 6 | 630 Or |
| Nv.4 | diagonales, 3 cases | 7 | 930 Or |
| Nv.5 | diagonales, 3 cases | 8 | 1290 Or |
| Nv.6 | diagonales, 4 cases | 9 | 1710 Or |
| Nv.7 | diagonales, 5 cases | 10 | 2190 Or |
| Nv.8 | diagonales, 6 cases | 11 | 2730 Or |
| Nv.9 | diagonales, 7 cases | 12 | 3330 Or |
| Nv.10 | diagonales, 8 cases | 13 | — |

### TOUR — poids 5, valeur 5
Donjon des Tours — recrutement **110 Or** (+22 par tour déjà possédé)

| NIVEAU | MOBILITÉ | CASERNE | AMÉLIORATION |
|---|---|---|---|
| Nv.1 | lignes et colonnes, 2 cases | 3 | 260 Or |
| Nv.2 | lignes et colonnes, 2 cases | 4 | 500 Or |
| Nv.3 | lignes et colonnes, 2 cases | 5 | 800 Or |
| Nv.4 | lignes et colonnes, 3 cases | 6 | 1160 Or |
| Nv.5 | lignes et colonnes, 3 cases | 7 | 1580 Or |
| Nv.6 | lignes et colonnes, 4 cases | 8 | 2060 Or |
| Nv.7 | lignes et colonnes, 5 cases | 9 | 2600 Or |
| Nv.8 | lignes et colonnes, 6 cases | 10 | 3200 Or |
| Nv.9 | lignes et colonnes, 7 cases | 11 | 3860 Or |
| Nv.10 | lignes et colonnes, 8 cases | 12 | — |

### DAME — poids 5, valeur 9
Château Royal — **ne se recrute pas**, elle se gagne par promotion

| NIVEAU | MOBILITÉ | CASERNE | AMÉLIORATION |
|---|---|---|---|
| Nv.1 | toutes directions, 2 cases | 10 | — |
| Nv.2 | toutes directions, 2 cases | 10 | — |
| Nv.3 | toutes directions, 3 cases | 10 | — |
| Nv.4 | toutes directions, 3 cases | 10 | — |
| Nv.5 | toutes directions, 4 cases | 10 | — |
| Nv.6 | toutes directions, 5 cases | 10 | — |
| Nv.7 | toutes directions, 6 cases | 10 | — |
| Nv.8 | toutes directions, 7 cases | 10 | — |
| Nv.9 | toutes directions, 8 cases | 10 | — |
| Nv.10 | toutes directions, 9 cases | 10 | — |

### CHÂTEAU ROYAL

| NIVEAU | CHARGE DE DÉPLOIEMENT | AMÉLIORATION |
|---|---|---|
| Nv.1 | 16 | 300 Or |
| Nv.2 | 19 | 560 Or |
| Nv.3 | 21 | 900 Or |
| Nv.4 | 23 | 1320 Or |
| Nv.5 | 26 | 1820 Or |
| Nv.6 | 28 | 2400 Or |
| Nv.7 | 30 | 3060 Or |
| Nv.8 | 32 | 3800 Or |
| Nv.9 | 34 | 4620 Or |
| Nv.10 | 36 | — |

### Les « spéciaux », les vrais

Une seule ligne par pièce, et elle dit quelque chose de vrai :

| Pièce | Spécial |
|---|---|
| Pion | **Promotion** — mené au bout du plateau adverse, il devient Dame. Ramenée **vivante**, elle rejoint le Château Royal et se redéploie ensuite comme n'importe quelle pièce. |
| Cavalier | **Il saute** — les pièces sur le chemin ne le bloquent jamais. Chaque niveau lui ouvre une figure de saut de plus, et non de la portée. |
| Fou | Bloqué par la première pièce rencontrée sur sa diagonale. |
| Tour | Bloquée par la première pièce rencontrée sur sa ligne. |
| Dame | **Aura** — une Dame restée au village rapporte **+15 % d'or** sur chaque bataille. La déployer, c'est renoncer à sa part pour ce combat-là. Son niveau est le plus petit du niveau du Château Royal et du **nombre** de Dames abritées. |

### La section des bâtiments : 5, pas 8

Ni Donjon de Fer, ni Cathédrale, ni Académie militaire, ni Chapelle de soins.

| Bâtiment | Ce qu'il fait | Disponible |
|---|---|---|
| **Château Royal** | Fixe la charge de déploiement (16 au Nv.1, 36 au Nv.10) et abrite les Dames | dès le départ |
| **Caserne des Pions** | Recrute et améliore les pions | dès le départ |
| **Écuries** | Recrute et améliore les cavaliers | dès le départ |
| **Cloître des Fous** | Recrute et améliore les fous | **Château Nv.2** |
| **Donjon des Tours** | Recrute et améliore les tours | **Château Nv.3** |

La Dame n'a pas de bâtiment à elle : elle vit au Château Royal, aux côtés du
Roi. C'est de là que vient toute l'histoire.

Améliorer un bâtiment **prend du temps réel** — de 30 secondes au premier
palier à 4 heures au dernier. Ça mérite une ligne dans la section.

### La section des règles : 6, réécrites

1. **LE CHAMP DE BATAILLE** — Un plateau quadrillé, de 5 × 6 à 8 × 9 cases
   selon la bataille. Tour par tour : **une pièce par camp et par tour**.
2. **LE PLACEMENT** — Avant chaque combat, vous posez votre armée sur vos deux
   rangées du fond, face à une formation ennemie que vous voyez. Ce n'est pas
   un nombre de pièces mais un **budget de charge** : Pion 1, Cavalier 3,
   Fou 3, Tour 5, Dame 5, contre la capacité du Château Royal.
3. **LA CAPTURE** — Ni points de vie ni dégâts. **On capture en se déplaçant
   sur la case adverse.** Une pièce est sur le plateau, ou elle n'y est plus.
4. **L'ANNEAU ROUGE** — Un cercle rouge entoure en permanence vos pièces
   prenables au coup suivant. Sans points de vie, **voir l'attaque arriver est
   toute la tension du jeu**.
5. **VICTOIRE, DÉFAITE, MATCH NUL** — Un camp gagne quand l'autre n'a plus rien
   debout. Une bataille enlisée se tranche au matériel restant — et **à
   égalité stricte, personne n'a gagné** : les survivants rentrent, le combat
   ne rapporte rien, mais la série n'est pas rompue.
6. **LA SÉRIE** — Seule la première bataille se joue en un combat. À partir de
   la deuxième, il en faut **deux d'affilée**, puis **trois** pour les trois
   dernières, sans retour au village. L'ennemi revient au complet ; vous
   revenez avec vos survivants — c'est là qu'est la difficulté. Entre deux
   combats, quelques-unes de vos pertes les moins chères se relèvent : **deux
   pions se relèvent, jamais une tour.**

---

## 2. La carte de campagne illustrée — sans les numéros

L'illustration posée à côté des frames est plus belle que le parchemin
actuellement en jeu, et on aimerait la prendre. **Un seul obstacle, et il est
absolu** : elle porte les numéros d'étape dessinés dedans.

Le jeu trace ses propres cachets par-dessus la carte, et ce sont eux qui disent
**verrouillé / disponible / gagné**. Un parchemin qui porte déjà ses numéros
fige la progression : le joueur verrait un « 7 » là où le jeu doit pouvoir
montrer un cachet de plomb rouillé.

**Vérifié depuis** : le nœud `209:423` est un `RECTANGLE` à remplissage image.
Les numéros sont **peints dans le raster**, pas sur un calque qu'on masque — il
n'y a donc rien à ré-exporter. Deuxième chose relevée au passage : l'image ne
couvre que les étapes **6 à 10**, alors que la campagne en compte dix.

**Ce qu'on demande** est donc une **re-génération**, pas un ré-export : la même
carte, le même trait, mais **sans aucune pastille numérotée**, et sur les
**dix** étapes du chemin. Le jeu posera ses propres cachets aux emplacements —
c'est ce qui lui permet de montrer un cachet de plomb rouillé là où le joueur
n'est pas encore allé.

Deux détails qui comptent pour le remplacement : le fichier en place est
`parchment_map.jpg`, et l'écran de campagne est un parchemin défilant de
**2 300 points** de haut pour 393 de large. Tant que cette version n'existe
pas, le jeu garde la carte actuelle — ce n'est pas bloquant.

*(Le sang au sol de l'illustration actuelle est aussi à retirer : le ton du jeu
exclut la violence graphique — la capture d'une pièce est une convention
d'échecs, pas une mise à mort.)*

---

## 3. La Dame captive — le bandeau de la bataille 10

L'image de la Dame derrière des barreaux, dans son arche de pierre, est
**l'image centrale de l'histoire du jeu** et elle n'est affichée nulle part.

La dixième et dernière bataille s'appelle **« La Tour de la Dame »**. C'est la
seule de la campagne qui accorde une Dame à sa première victoire. C'est donc
son écran.

**Ce qu'on demande** : une frame `preparation-bataille-10-v3`, variante de
`preparation-bataille-v2` (node-id **169:4**) — le même écran, **plus un
bandeau d'enjeu** portant l'illustration, entre la plaque royale du titre et le
briefing des forces.

Contraintes qui viennent du jeu, pas du goût :

- Ce bandeau **n'apparaît que sur la bataille 10**. Les neuf autres gardent
  l'écran tel quel — le dessin doit donc s'insérer et se retirer sans laisser
  de trou.
- La bataille 10 est une **série de trois combats**. Le bandeau doit survivre à
  la ligne « COMBAT 2 / 3 » qui s'affiche déjà au-dessus.
- **Aucune violence graphique.** Elle est captive, pas suppliciée. Le ton du
  jeu est mélancolique, pas sombre.
- Livre l'illustration **détourée, sur fond transparent** : l'export du nœud
  arrive sinon avec le fond gris du canvas, entièrement opaque.

---

## Les rappels qui coûtent cher quand on les oublie

- **Cadre utile 361 × 824** (393 × 852 moins les zones sûres iPhone). Portrait
  uniquement.
- **Ancrer, ne pas positionner** : auto-layout partout, barre haute de hauteur
  fixe, contenu qui prend la place restante.
- **Pas de nouvelle police.** Inter (variable), Comic Relief pour la voix du
  Roi, Jaro pour les enseignes.
- **Les filtres SVG ne sont pas appliqués par Godot.** Un halo en
  `feGaussianBlur` arrive éteint : donne-le en dégradé radial, ou cuit dans la
  texture.
- **Un label ne peut pas être rempli d'un dégradé** sans un shader par glyphe.
  Donne l'or médian à plat, avec son ombre portée.
- **La plaque royale est la brique du jeu** : rectangle arrondi, dégradé bleu
  nuit `#1e3278` → `#0a1230` → `#0e1a40`, cerclé d'un trait d'or `#ffe680`,
  doublé d'un filet d'or fin. Le codex en descend, il n'invente pas un
  troisième langage.

## Ce que le code fera de son côté

Le codex en jeu **ne recopiera pas ces tableaux** : il les regénérera à chaque
ouverture depuis le fichier d'équilibrage. C'est ce qui garantit qu'il ne
pourra plus jamais décrire un autre jeu que celui qu'on joue. Ta frame fixe la
**mise en page et les libellés constants** ; les chiffres viennent du code.

C'est aussi pourquoi il faut que la mise en page **encaisse des textes de
longueur variable** — « saut diagonal » et « saut diagonal, saut en L, saut 3+1
cases, saut 3+2 cases, saut 4+1 cases, saut 4+2 cases, saut 4+3 cases » sont la
même case du même tableau, à deux niveaux différents.
