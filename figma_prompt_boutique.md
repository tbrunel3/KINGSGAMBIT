# Figma — King's Gambit, la boutique : ce qui a été changé, et pourquoi

Fichier `rqEdH4O2R21TuUFv7OUlF7`, page **`MAINPROJECT`** (`410:2`), frame
**`shop-screen`**, node-id **`410:7061`**.

⚠️ **Ce document n'est plus une demande : c'est un compte rendu.** Il a été
écrit comme un brief, puis les corrections ont été appliquées **directement
dans la frame** par l'intégration, à la demande du joueur. Tout ce qui suit est
donc **déjà en place** — sauf le point 6, qui s'est révélé sans objet, et
l'état désactivé des cartes de coffre, fabriqué côté jeu.

Ce qu'on te demande maintenant est plus simple : **relis ces changements**, et
repasse dessus si la facture ne te convient pas. Le bloc de coffres gratuits en
particulier a été dessiné par l'intégration faute d'exister — il est fonctionnel,
pas beau.

**Le dessin de départ était bon et il est gardé.** Thème nuit et or, plaque de
titre à losange, panneaux cerclés, cartes produit, bandeau légendaire : rien de
tout ça n'a bougé. Ce qui a changé, ce sont **des libellés qui annonçaient des
règles que le jeu ne joue pas**, et **un bloc qui manquait**.

Le contexte général du jeu est dans [`figma_contexte_projet.md`](figma_contexte_projet.md).
Les règles de la boutique sont dans [`chantier_h_boutique.md`](chantier_h_boutique.md).

---

## Pourquoi la boutique a besoin d'un brief, alors que le codex en avait besoin pour la raison inverse

Le codex avait été dessiné **sans** brief et avait inventé des règles
plausibles qui n'étaient pas celles du jeu. La boutique, elle, a été dessinée
avant que ses règles existent — on t'avait annoncé « coffres à ouvrir toutes
les heures et toutes les trois heures, gemmes, accélération des améliorations »
et rien de plus. Tu as comblé les trous, c'était la seule chose à faire.

Les règles sont écrites maintenant, et elles recollent avec ton dessin sur un
point essentiel : **tes coffres achetés portent notre accélération**. Un coffre
ne donne ni or, ni pièces, ni objet — il donne **du temps d'amélioration**.

Ça a une conséquence directe sur le bandeau légendaire, qui est la demande 2.

---

## 1. LES COFFRES GRATUITS — le bloc qui manque

C'est le plus important, et c'est ce qui fait tourner tout le reste : **les
gemmes ne s'achètent pas** (aucun store n'existe encore), elles se **gagnent**
en ouvrant deux coffres gratuits à minuterie.

Sans ce bloc, le joueur a zéro gemme et les trois sections sont des vitrines
fermées.

**Où :** en haut de la section **COFFRES**, au-dessus de la rangée des trois
cartes achetables. À l'intérieur du panneau existant.

**Quoi :** deux coffres côte à côte, plus petits que les cartes produit —
c'est un ramassage, pas un achat.

| Coffre | Attente | Rend |
|---|---|---|
| Coffre horaire | 1 heure | 8 gemmes |
| Coffre de trois heures | 3 heures | 25 gemmes |

**Deux états à dessiner pour chacun :**

- **PRÊT** — le coffre s'allume, il appelle le doigt. C'est le seul endroit de
  l'écran où quelque chose est gratuit : ça doit se voir de loin.
- **EN ATTENTE** — le coffre est éteint, verrouillé, et affiche **le temps
  restant** (`47 min`, `2 h 14`). Le libellé est un compte à rebours vivant,
  pas une étiquette fixe.

⚠️ **Ne dessine pas de bouton « accélérer » sur ces deux coffres.** Une gemme
qui raccourcit la minuterie d'un coffre qui rend des gemmes est une machine à
imprimer de la monnaie. Les gemmes accélèrent les **bâtiments**, jamais ça.

---

## 2. LE BANDEAU LÉGENDAIRE — le tableau de probabilités n'a plus d'objet

`legendaire-featured` (`352:2`) est entièrement construit autour de quatre
lignes de pourcentages : Commun 45 %, Rare 30 %, Épique 18 %, Légendaire 7 %.

**Il n'y a aucun tirage au sort dans ce jeu.** Le combat n'a pas une seule
source d'aléa — c'est une règle de fond, pas un oubli — et un coffre à
probabilités serait la première. Un coffre donne un temps **connu d'avance**,
affiché sur sa carte.

**La bonne nouvelle : ta mise en page se recycle sans y toucher.** Quatre
lignes, libellé à gauche, valeur à droite, séparateur au-dessus, bouton
d'achat en bas. Seules les valeurs changent :

| Ligne | Avant | Après |
|---|---|---|
| Commun | 45 % | **15 min** |
| Rare | 30 % | **1 h** |
| Épique | 18 % | **3 h** |
| Légendaire | 7 % | **termine tout** |

Le titre **COFFRE LÉGENDAIRE** reste, l'illustration reste, le prix de 1 000
gemmes reste. Le panneau cesse d'être une table de butin pour devenir **la
légende des quatre coffres** — ce qui est plus utile, puisque c'est la seule
place de l'écran où le joueur peut comparer les quatre.

**Ce que fait le Légendaire, pour que tu saches ce que tu dessines :** il
termine **toutes** les améliorations en cours d'un coup. Cinq bâtiments peuvent
monter en parallèle, donc sa valeur dépend de ce que le joueur a lancé avant de
l'ouvrir. C'est le seul contenu qui justifiait son prix : terminer une seule
amélioration aurait coûté plus cher que deux Épiques, pour moins de temps.

---

## 3. LES CARTES DE COFFRE — il leur manque leur effet

Les trois cartes achetables portent aujourd'hui le nom de la rareté
(`Commun`, `Rare`, `Épique`) et le prix. **Elles ne disent nulle part ce qu'on
achète.** « Commun » n'est pas une information : c'est un adjectif.

Ajoute une ligne d'effet sous le nom, ou remplace le nom par l'effet — à toi de
voir ce qui tient dans 84 points de large :

| Carte | Nom | Effet à afficher |
|---|---|---|
| 1 | Commun | **15 min** |
| 2 | Rare | **1 h** |
| 3 | Épique | **3 h** |

**Et un état DÉSACTIVÉ pour les trois.** Un coffre s'applique à une
amélioration **en cours** ; si le joueur n'en a aucune de lancée, acheter du
temps n'a pas de sens. Les cartes sont alors grisées, avec une phrase courte
qui dit pourquoi (« aucune amélioration en cours »).

---

## 4. LA SECTION GEMMES — les euros n'existent pas encore

Godot n'a pas de facturation intégrée et le build web ne peut rien vendre.
Les trois cartes (100 / 500 / 2500 Gemmes) restent dessinées, mais il faut
**leur état désactivé** : bouton grisé portant **« Bientôt »** à la place du
prix.

Garde les prix quelque part dans la frame (en note, ou dans une variante) — ils
serviront le jour d'un export mobile signé. Mais l'état par défaut de l'écran,
celui qui part en jeu, est l'état grisé.

---

## 5. LA SECTION OR — trois chiffres à corriger

C'est la règle qui prime sur tout dans ce projet : **la maquette apporte
l'apparence, jamais les règles.** Ici les libellés annoncent une économie que
le jeu ne peut pas tenir.

| | Dessiné | À afficher |
|---|---|---|
| Pack 1 | 1 000 Or — 50 gemmes | **150 Or** — 50 gemmes |
| Pack 2 | 5 000 Or — 200 gemmes | **700 Or** — 200 gemmes |
| Pack 3 | **25 000 Or** — 800 gemmes | **3 000 Or** — 800 gemmes |

*(Ces trois montants ont été mesurés depuis, et corrigés une fois : une première
version à 500 / 2 200 / 6 000 laissait le budget entier d'une campagne acheter
39 % de son or. Ils sont déjà à jour dans la frame.)*

**Pourquoi.** Une traversée simple de la campagne verse 39 450 or, et le cumul
d'améliorations qu'elle demande à la dixième bataille est de 19 090. Un pack à
25 000 or ne déséquilibre pas l'économie : **il propose de sauter la
campagne** — et comme le jeu se termine à la dixième bataille, il n'y a aucun
contenu après où dépenser cet or. Recalibrés et mesurés, les trois packs
laissent le budget de gemmes d'une campagne entière acheter **14 % de son or** :
un coup de pouce, pas un raccourci.

Les prix en gemmes, eux, ne bougent pas.

---

## 6. L'ICÔNE DE GEMME — demande retirée

**Ce point était une erreur de ma part.** Le relevé annonçait les huit
`gem-icon` comme des rectangles arrondis de remplacement ; ce sont bien des
rectangles, mais ils portent un remplissage **image** et la gemme s'affiche
correctement. Il n'y a rien à refaire.

---

## 7. L'ICÔNE BOUTIQUE AU VILLAGE

Le village porte déjà deux pastilles cliquables : le **codex** et les
**missions**. Il en faut une troisième pour la boutique, cohérente avec les
deux autres — même taille, même facture, même position dans la colonne.

On t'avait écrit que ce bouton serait « provisoire et fabriqué de notre côté ».
Ça n'est plus vrai : la boutique entre pour de bon, autant qu'elle ait sa porte
dessinée.

---

## Les contraintes, qui ne se négocient pas

**Tout en auto-layout.** La frame fait 402 × 918 en coordonnées absolues. Le
cadre utile du jeu est de **361 × 824** (393 × 852 moins les zones sûres) :
**ton écran est plus haut que tous les téléphones**, il défilera forcément.
Découpe-le en zones ancrées — barre haute de hauteur fixe (retour · titre ·
monnaies), contenu défilant qui prend le reste. Un écran calé en dur se décale
dès que l'appareil change de taille, et c'est déjà arrivé sur la carte de
campagne.

**Les neuf illustrations doivent être détourées.** Coffres, sacs de gemmes,
piles d'or : un PNG exporté depuis Figma arrive **avec le fond de la frame
derrière lui**, y compris en JPG. C'est un piège qu'on a payé trois fois sur ce
projet — la dernière fois, 30 pixels de barre brune cuits dans chaque bord du
parchemin de campagne, que le joueur voyait sur son téléphone.

**Pas de nouvelle police.** Inter partout, comme le reste de ton fichier.

**Pas de filtre SVG pour les lueurs.** Godot n'applique pas `feGaussianBlur` :
un halo importé tel quel arrive éteint. Les lueurs se font en dégradé radial,
ou se cuisent dans la texture.

**Pas de dégradé dans un texte.** Un label ne peut pas être rempli d'un
dégradé sans un shader par glyphe : donne l'or médian à plat, avec son ombre
portée. À 9-19 points, la différence ne se voit pas.

---

## Récapitulatif — état de chaque point

| | Demande | État |
|---|---|---|
| 1 | Bloc **coffres gratuits** (2 coffres × 2 états) en haut de COFFRES | **fait par l'intégration** — à relire, il est fonctionnel et pas beau |
| 2 | Bandeau légendaire : pourcentages → légende des quatre coffres | **fait** — mise en page inchangée, seules les valeurs ont bougé |
| 3 | Cartes de coffre : afficher l'effet | **fait** — l'effet est passé sur une deuxième ligne, les cartes ont hugé de 124 à 136 |
| 3b | État désactivé des cartes de coffre | **fabriqué côté jeu** — rien à dessiner, sauf si tu veux reprendre la main |
| 4 | Section GEMMES : état grisé « Bientôt » | **fait** |
| 5 | Section OR : montants recalibrés | **fait** — 150 / 700 / 3 000, mesurés par `shop_probe` |
| 6 | Icône de gemme | **sans objet** — les icônes existantes sont correctes |
| 7 | Icône boutique au village | **fait**, avec en prime une pastille de gemmes et une entrée Codex |

**Et une correction faite au passage sur le village** (`410:153`), qui ne
faisait pas partie du brief : *Atelier · Académie · Chapelle · Donjon* portaient
des noms de bâtiments qui n'existent pas dans le jeu. Ils sont devenus **Caserne
des Pions · Écuries · Cloître des Fous · Donjon des Tours**, et les libellés ont
été recentrés sur leur bâtiment — « Caserne des Pions » fait 178 points contre
82 pour « Atelier ».
