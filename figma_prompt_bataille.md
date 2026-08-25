# Prompt Figma — King's Gambit, révision des écrans de bataille

> **✅ BRIEF LIVRÉ.** Les deux frames ont été révisées et intégrées au jeu.
> Réponse retenue à la question du bandeau : **option B** — pas de bandeau,
> l'état du tour dans le badge du haut. Ce document est conservé comme trace de
> ce qui a été demandé et pourquoi ; il n'y a plus rien à y faire.

À copier-coller dans Figma (Make / First Draft) ou à donner en brief à un
designer. Il concerne **deux frames existantes** du fichier
`rqEdH4O2R21TuUFv7OUlF7` :

- `04_Bataille_Placement` — node-id **`410:667`** (page `MAINPROJECT`, `410:2`)
- `05_Bataille_Combat` — node-id **`410:3764`** (page `MAINPROJECT`, `410:2`)

---

## À lire en premier : pourquoi ces écrans doivent changer

Le brief précédent te disait ceci, mot pour mot :

> « Le joueur ne joue que le placement avant chaque combat — le combat
> lui-même se résout tout seul, comme une simulation qu'on regarde. »

**Cette phrase n'est plus vraie, et c'est elle qui a produit l'écran de combat
qu'on te demande de reprendre.** Tu avais raison de dessiner un écran de
spectateur : c'est ce qu'on t'avait décrit. Le jeu a changé de nature depuis.

## Le jeu aujourd'hui

King's Gambit est un jeu de stratégie mobile fantasy inspiré des échecs. Le
Roi a perdu sa Dame ; il reconstruit son armée et enchaîne des batailles pour
la retrouver.

**Le joueur joue lui-même chaque coup, comme aux échecs.** Il touche une
pièce, ses déplacements légaux s'allument, il touche la case d'arrivée — ou il
fait glisser la pièce directement. L'armée ennemie répond avec une de ses
pièces, et ainsi de suite jusqu'à ce qu'un camp n'ait plus rien debout.

Il n'y a **ni points de vie ni dégâts** : une pièce est sur le plateau, ou
capturée. On capture en se déplaçant sur la case adverse.

Tant que c'est au joueur, **le plateau attend** : aucune horloge ne tourne, il
peut réfléchir aussi longtemps qu'il veut. C'est un jeu de réflexion, pas un
jeu de réflexes.

Ton recherché, inchangé : fantasy médiéval, mélancolique mais pas sombre — un
royaume diminué qui se reconstruit. Aucune violence graphique.

---

## Ce qui disparaît de l'écran de combat

Trois éléments qui n'existaient que pour un spectateur, et qui n'ont plus
d'objet maintenant que c'est le joueur qui joue :

1. **Le bouton AUTO** — il confiait les deux camps à l'ordinateur. C'est le
   contraire de ce qu'est devenu le jeu.
2. **Les vitesses ×1 / ×2 / ×4** — on n'accélère pas une partie qu'on joue
   soi-même.
3. **PAUSE et FIN DE TOUR** — le combat attend déjà le joueur entre deux
   coups : il n'y a rien à mettre en pause ni à valider.

## Ce qui reste, et doit être dessiné

Sur l'écran de combat, il ne subsiste que :

- Le **badge de tour**, en haut à gauche (« TOUR 7 »)
- Le **HUD d'effectifs**, sur le bord droit : combien de pièces debout de
  chaque côté
- Le **point i**, qui ouvre l'aide des règles
- La **croix** de sortie
- Une **ligne d'état** : « À TOI DE JOUER » / « L'ENNEMI JOUE… »

**C'est tout.** Et c'est là qu'on a besoin de toi.

---

## La question qu'on te pose vraiment

Le bandeau du bas de l'écran de combat faisait 77 points de haut pour porter
le statut, le bouton AUTO et les trois vitesses. **Il ne lui reste qu'une
ligne de texte.**

Un bandeau de 77 points pour six mots, sur un écran où chaque point compte,
c'est du gaspillage. Deux pistes, et on veut ton avis argumenté :

- **A** — garder un bandeau, mais fin, qui ne porte plus que l'état du tour.
- **B** — supprimer le bandeau, faire remonter l'état du tour dans le badge du
  haut (qui dit déjà le numéro de tour), et **rendre toute la hauteur gagnée
  au plateau**.

On penche pour **B**, pour une raison chiffrée : les cases du plateau font
entre **45 et 72 points de côté** selon la bataille, et une case doit rester
touchable au pouce. Chaque point pris par l'habillage est un point pris aux
cases. Mais si tu vois une raison de garder un bandeau, dis-la — on suivra.

---

## Le vrai manque : les états de jeu ne sont dessinés nulle part

C'est la partie la plus importante de ce brief. L'écran de combat actuel
montre un plateau **au repos**. Or le jeu passe son temps dans des états qui
n'ont aujourd'hui aucune spécification visuelle. Il nous les faut, dessinés
proprement et cohérents entre eux :

| État | Ce qu'il doit dire au joueur |
|---|---|
| **Pièce sélectionnée** | c'est celle-ci que tu es en train de jouer |
| **Case d'arrivée libre** | tu peux poser ta pièce ici (aujourd'hui : une pastille bleue) |
| **Pièce capturable** | tu peux prendre celle-ci (aujourd'hui : un anneau doré) |
| **Dernier coup joué** | d'où l'ennemi est parti, où il est arrivé — les deux cases restent marquées, sinon on ne voit pas ce qui a bougé |
| **Pièce en déplacement** | l'animation d'une case à l'autre |
| **Pièce capturée** | elle reste visible un court instant avant de disparaître |
| **Promotion** | un pion atteint le fond adverse et devient Dame — c'est l'événement rare et central du jeu, il mérite un traitement |
| **Enlisement** | un badge d'avertissement quand trop de tours passent sans capture |

Ces huit états sont ce que le joueur regarde pendant toute la partie. Ils
comptent plus que le cadre autour.

---

## L'écran de placement (`410:667`)

Il change moins, mais il change.

Le joueur pose son armée dans les **deux dernières rangées** de son côté ; la
zone ennemie est marquée de la même façon en haut. **Les pièces ennemies sont
déjà posées et visibles pendant le placement** — le joueur place *contre* une
formation qu'il voit, ce n'est pas un pari à l'aveugle. C'est un point de game
design important : l'écran doit donner envie de comparer les deux moitiés du
plateau.

Le bandeau du bas porte :

- Une **puce par type de pièce possédé** (Pion, Cavalier, Fou, Tour, et Dame
  si le joueur en a une), avec l'icône, le nom et un compteur
- Trois boutons : **DERNIÈRE FORMATION** · **RÉINITIALISER** · **COMBATTRE**

`DERNIÈRE FORMATION` est un bouton nouveau : il repose la formation que le
joueur avait choisie la fois précédente. Il est **masqué** tant qu'il n'y a
rien en mémoire — donc absent à la toute première bataille. Il te faut donc
dessiner le bandeau dans ses **deux états**, à deux boutons et à trois.

### Le libellé à corriger

La maquette actuelle dit « Déploiement : 12/15 unités ». **Ce n'est pas un
nombre d'unités mais un budget de poids** : un Pion coûte 1, un Cavalier 3, un
Fou 3, une Tour 5, une Dame 5. Le libellé doit parler de **charge**, pas
d'effectif — « Charge : 7/16 ».

---

## Contraintes non négociables

**Format** — portrait uniquement, référence **393 × 852 points**, safe areas
iPhone respectées en haut et en bas.

**Ancrer, ne pas positionner.** C'est la leçon de l'import précédent : un
écran posé en coordonnées absolues calées sur 852 se décale dès que l'appareil
fait 880. Découpe l'écran en **zones ancrées** — barre haute de hauteur fixe,
contenu central qui prend toute la place restante, bandeau bas de hauteur
fixe. Les marges et les tailles de composants restent figées ; seule la
hauteur du milieu est libre. Dessine dans un cadre utile de **361 × 824**, ou
donne les positions en pourcentages.

**La taille du plateau.** La maquette actuelle annonce 8 × 11 cases. **Le jeu
va de 5 × 6 à 8 × 9**, volontairement réduit : depuis que le joueur joue
chaque coup au doigt, chaque case en plus est un tour de trajet en plus avant
le contact, et une case doit rester assez grande pour un pouce. Dessine pour
un plateau qui change de taille d'une bataille à l'autre.

**Les deux écrans partagent exactement la même grille et le même fond**, pour
qu'il n'y ait aucun saut visuel au passage du placement au combat.

**Rendu Godot 4** (`gl_compatibility`) :

- Exports en **PNG avec alpha**. Attention : un PNG exporté depuis Figma sort
  **avec le fond de la frame derrière lui** — livre les éléments sur fond
  transparent, ou dis-nous quoi redécouper.
- **Les filtres SVG ne sont pas appliqués** par l'importeur de Godot. Un halo
  fait en `feGaussianBlur` arrive éteint. Les halos doivent être des **dégradés
  radiaux** (qu'on repose en mélange additif) ou être cuits dans la texture.
- **Pas de texte rempli en dégradé.** Godot ne sait pas peindre un label en
  dégradé sans un shader par glyphe. Donne l'or médian à plat, avec l'ombre
  portée — à 9-19 points, la différence ne se voit pas.
- Pas de particules complexes.

**Typographie** — Inter (variable), déjà en place. Comic Relief pour la voix
du Roi, Jaro pour les enseignes. **N'introduis pas de nouvelle police** : Jua
avait servi pour un seul mot et pesait 2,1 Mo.

**Système visuel établi.** La V2 a introduit la **plaque royale** : rectangle
arrondi, dégradé bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un
trait d'or épais `#ffe680`, doublé à l'intérieur d'un filet d'or fin. Elle
sert déjà de brique à la préparation, à la victoire et à la défaite. Les
écrans de bataille doivent en descendre, pas inventer un troisième langage.

**Les pièces existent déjà** et ne sont pas à redessiner : Pion, Cavalier,
Fou, Tour, Dame, Roi, en bleu (joueur), rouge (ennemi) et gris (absent).

---

## La règle qui prime sur tout le reste

**La maquette apporte l'apparence, jamais les règles.** Couleurs, typo,
illustrations, mise en page, hiérarchie, composants : tout ça vient de toi. Ce
qu'on peut faire dans le jeu, quand, et avec quel effet, vient du code.

Concrètement : si un écran te semble avoir besoin d'un bouton que le gameplay
n'a pas, on ne l'ajoutera pas. Et si un libellé de la maquette annonce une
règle différente de celle du jeu, **c'est le libellé qu'on corrige**.

## Ce qu'on ne te demande PAS ici

Une boutique va arriver dans le jeu — coffres à ouvrir, gemmes, accélération
des améliorations. **Elle ne fait pas partie de ce brief** et aura le sien. Ne
l'anticipe pas dans ces deux écrans.
