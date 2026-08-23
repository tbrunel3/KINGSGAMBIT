# Figma Make — King's Gambit : prototyper les transitions de tout le jeu

Fichier `rqEdH4O2R21TuUFv7OUlF7`, page **`MAINPROJECT`** (`410:2`).

**Ce qu'on demande :** un prototype interactif de la **navigation entière** du
jeu, pour concevoir les transitions entre écrans — puis les porter dans Godot.

Aujourd'hui le jeu **coupe franc** : les 20 trajets appellent tous
`change_scene_to_file` et l'écran suivant apparaît d'un coup. Aucune
continuité, nulle part. Trois frames de la maquette portent bien un
`Fondu au noir`, mais rien n'existe côté départ.

Le contexte général est dans [`figma_contexte_projet.md`](figma_contexte_projet.md).
**Ce document ne le répète pas.**

---

## Ce document a deux moitiés

1. **Pour toi, le designer** — ce qui existe déjà, ce qui manque, et les pièges
   qui ont déjà coûté du temps. À lire avant de lancer Make.
2. **Le prompt à coller dans Make** — self-contained, tout en bas. Il ne
   suppose aucune lecture préalable.

---

# PARTIE 1 — pour toi

## Les 20 trajets, relevés dans le code

Ce n'est pas une liste souhaitée, c'est ce que le jeu fait réellement
aujourd'hui. Chaque ligne est un endroit où une transition manque.

| Depuis | Vers | Déclenché par |
|---|---|---|
| splash | village | le jeu a déjà une sauvegarde |
| splash | intro | première partie |
| intro | village | fin du dialogue du Roi |
| **village** | château | on touche le Château Royal |
| **village** | codex | bouton `i` |
| **village** | boutique | bouton boutique, en bas à gauche |
| **village** | campagne | bouton BATAILLE |
| château | village | flèche retour |
| codex | village | flèche retour |
| boutique | village | flèche retour |
| campagne | village | flèche retour |
| campagne | préparation | on touche un cachet de bataille |
| préparation | campagne | flèche retour |
| préparation | bataille | bouton COMBATTRE |
| bataille | village | croix de sortie |
| **bandeau de série** | combat suivant | au doigt, ou tout seul après un délai |
| **écran de résultat** | bataille *(rejouer)* | bouton principal |
| **écran de résultat** | village | bouton ROYAUME |
| **écran de résultat** | campagne | bouton CAMPAGNE |
| **écran de résultat** | préparation suivante | bouton BATAILLE SUIVANTE |

⚠️ **Les quatre dernières sont les plus fréquentes.** Huit batailles sur dix
sont des **séries** de deux ou trois combats : le joueur voit le bandeau de
série et l'écran de résultat plusieurs fois par bataille, bien plus souvent
qu'il ne voit le codex ou la boutique. **Si tu ne dois en soigner que quatre,
ce sont celles-là.**

## Ce qui est DÉJÀ animé — ne pas le refaire

Relevé complet du 23/08/2026, section par section, sur `MAINPROJECT`. Les
entrées d'écran ci-dessous sont **déjà portées dans le jeu** : elles jouent
quand l'écran arrive. Ce qu'on te demande, c'est ce qui se passe **entre deux
écrans**, pas l'entrée elle-même.

| Écran | node-id | Entrée existante |
|---|---|---|
| king-intro-before-dialogue | `410:35` | 2,5 s, 3 nœuds — portée |
| king-intro-dialogue | `410:71` | 4 s, 9 nœuds — portée |
| preparation-bataille-v2 | `410:7227` | 2 s, 12 nœuds — portée |
| 04_Bataille_Placement | `410:667` | 3 s, 17 nœuds — portée |
| 07-bataille-nulle | `410:5551` | 3 s, 7 nœuds — portée |
| 09/10/11-popup-batiment | `410:7342` etc. | 2 s, 2 nœuds — à porter |
| shop-screen | `410:7061` | 1,5 s, 15 nœuds — à porter |
| mission-popup | `410:5664` | 2 s, 24 nœuds — à porter |
| popup-combat-phase | `410:7190` | 2 s, 3 nœuds — à porter |
| **06_Bataille_Victoire** | `410:5121` | **2,507 s, 24 nœuds** |
| **07-bataille-defaite** | `410:5430` | **3,5 s, 8 nœuds** |

⚠️ **Deux découvertes du relevé, à connaître avant de dessiner.**

1. **Les trois écrans de résultat ont TROIS entrées différentes**, et le jeu
   n'en joue qu'une — celle du match nul, sur les trois. Ce n'est pas un
   oubli de ta part : c'est le jeu qui est en retard sur toi, et c'est en
   cours de correction. Ce que tu as dessiné :
   - **Victoire** : le titre jaillit du bas, échelle 0,3 → 1, ressort qui
     dépasse à 1,36. Plus 12 confettis et 4 étincelles.
   - **Défaite** : le titre tombe de −80, échelle 1,15 → 1, **sans rebond**,
     et tout est plus lent (3,5 s contre 2,5).
   - **Nul** : le titre s'abat de 1,8 → 1, comme un tampon.

   **C'est excellent et c'est exactement le genre de distinction qu'on
   cherche.** Trois issues, trois lectures. Applique le même raisonnement aux
   transitions : quitter le village pour la boutique et quitter la préparation
   pour le combat ne devraient pas se ressembler.

2. **La campagne, le splash et `village-avec-dame` n'ont aucune donnée de
   mouvement.** Vérifié, ce n'est pas une supposition. La carte de campagne est
   pourtant un parchemin défilant de 2300 points, et c'est l'écran où le joueur
   choisit sa prochaine bataille : il mériterait une arrivée.

## Ce que le joueur a demandé en plus

**Les bâtiments du village doivent devenir cliquables**, pas seulement leurs
enseignes — et le passage vers le popup doit être un **zoom vers l'endroit
touché, avec un fondu au noir**. C'est en cours côté jeu.

Ça donne le ton de ce qu'on cherche partout ailleurs : une transition qui
**part du geste du joueur**, pas un fondu générique posé sur tout.

## Cinq pièges, tous déjà payés

1. **La boucle de Figma est un artefact d'aperçu.** Une entrée d'écran ne se
   joue qu'une fois. Ce qu'on reprend, ce sont les **décalages, les durées et
   les courbes** — jamais l'itération infinie.
2. **Un `Fade-From-Black` rend la frame NOIRE à l'export statique.** Un
   rectangle noir plein écran à l'opacité 1 qui s'efface sur les 25 premiers %
   : l'export capture l'image 0, donc le voile. Ce n'est pas un bug, mais
   préviens quand une frame en contient un, sinon on croit l'écran cassé.
3. **On ne peut pas animer la POSITION d'un élément à l'intérieur d'un
   conteneur en auto-layout.** Côté Godot le tween se bat avec la mise en
   page. Les **opacités** et les **échelles** passent partout ; les
   translations seulement sur des éléments posés librement. Si une transition
   dépend d'une translation, dis-le explicitement — on saura qu'il faut sortir
   l'élément de son conteneur.
4. **Le jeu est en portrait uniquement, référence 393 × 852**, mais la hauteur
   RÉELLE varie d'un téléphone à l'autre (jusqu'à 987 points) et la largeur
   peut monter à 495 sur un écran court. Une transition calée sur « 852 points
   de haut » se décale. Préfère les fractions de l'écran aux valeurs absolues.
5. **La maquette apporte l'apparence, jamais les règles.** Si un prototype
   montre un écran sans un bouton dont le jeu a besoin, on garde le bouton et
   on l'habille. Si un libellé annonce une règle différente de celle du code,
   **c'est le libellé qu'on corrige**. Ça a déjà coûté un codex entier à
   refaire.

## Ce dont on a besoin en retour

Pour porter, il nous faut, par transition :

- **La durée totale**, en millisecondes.
- **Ce qui bouge**, élément par élément : opacité, échelle, translation,
  rotation.
- **Les décalages** entre éléments (le « stagger »).
- **Les courbes** — en `cubic-bezier` ou en nom, peu importe, mais explicites.

Un prototype Make dont on peut lire la timeline suffit : nos outils savent
extraire tout ça (`get_motion_context`). **Ne rédige pas de tableau à la
main.**

---

# PARTIE 2 — le prompt à coller dans Figma Make

> Tout ce qui suit est self-contained. Copie-le tel quel.

---

Crée un prototype interactif mobile en portrait, **393 × 852**, pour un jeu de
stratégie fantasy médiéval inspiré des échecs appelé **King's Gambit**.

**L'objectif du prototype est la NAVIGATION et les TRANSITIONS entre écrans**,
pas le contenu des écrans. Les écrans peuvent rester schématiques ; ce qui
compte, c'est ce qui se passe **entre** eux.

## Le ton

Fantasy médiévale, **mélancolique mais pas sombre** : un royaume diminué qui se
reconstruit. Le Roi a perdu sa Dame et reconstitue son armée pour la retrouver.
Aucune violence graphique.

Palette :
- Fonds : `#0f111a`, `#161926`, `#262c3f`
- Bordures : `#3d4f6b`
- Texte : `#e6ecf5` principal, `#8fa0b8` atténué
- Or : `#ffd11a`, `#ffd700`, `#ffe580`
- Bleu joueur : `#268cd9`, `#4f86c6`
- Rouge ennemi : `#c65f5f`, `#b5514f`
- Vert succès : `#339940`, `#5fb37a`

Typographie : **Inter** partout (Black 32 px pour les titres de section, Bold
11-19 px pour les boutons, Semi Bold 10-15 px pour les libellés, Regular 8-14 px
pour le corps). **Poppins Bold 16 / SemiBold 14** uniquement pour les enseignes
de bâtiments du village.

Élément visuel récurrent : une **plaque royale** — rectangle arrondi, dégradé
bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un trait d'or `#ffe680`
et doublé d'un filet d'or fin. Panneaux, cartes, bannières, boutons et badges
en sortent tous.

## Les 11 écrans

1. **Splash** — logo, écran d'ouverture.
2. **Intro du Roi** — une illustration d'un roi-pièce d'échecs assis sur un
   trône, l'air abattu, à côté d'un second trône vide. Un panneau de dialogue
   monte du bas.
3. **Village** — vue isométrique d'une île avec un château central et quatre
   bâtiments autour (une caserne, des écuries, un cloître, un donjon). Barre
   haute avec or et gemmes. Un gros bouton doré **BATAILLE** en bas au centre,
   un bouton boutique à sa gauche.
4. **Château Royal** — plein écran, salle du trône, deux trônes dont un vide.
   Un panneau en bas avec un bouton AMÉLIORER.
5. **Codex** — écran défilant, encyclopédie : une carte par pièce, un tableau
   par niveau.
6. **Boutique** — écran défilant : coffres, packs de gemmes, packs d'or.
7. **Carte de campagne** — un **parchemin défilant vertical**, très long
   (environ 2300 points), avec dix cachets de cire numérotés reliés par un
   chemin. Certains verrouillés, un disponible, les autres gagnés.
8. **Préparation de bataille** — **le seul écran clair du jeu** : parchemin
   crème et panneaux blancs, quand tous les autres sont en nuit et or. C'est
   voulu. On y compose son armée avant le combat.
9. **Placement / Combat** — un plateau de jeu quadrillé (entre 5×6 et 8×9
   cases, la taille change à chaque bataille) avec des pièces bleues et rouges.
   Barre d'état en haut, bandeau en bas.
10. **Bandeau de série** — un écran court entre deux combats d'une même
    bataille : une carte d'annonce qui dit où on en est et ce qu'on a perdu.
11. **Écran de résultat** — trois variantes : **victoire** (bleu et or,
    confettis), **défaite** (rouge sombre, tentes de camp), **match nul**
    (gris acier). Un grand mot gravé, une plaque de statistiques, des boutons.

## Les transitions à concevoir — c'est le cœur de la demande

Rends les 20 trajets suivants navigables, **chacun avec sa propre
transition**. Ne pose pas un fondu générique identique partout : chaque
transition doit raconter ce que le joueur vient de faire.

**Depuis le splash :** → village · → intro du Roi
**Depuis l'intro :** → village
**Depuis le village :** → château · → codex · → boutique · → carte de campagne
**Retours vers le village :** depuis château · codex · boutique · campagne · combat
**Depuis la campagne :** → préparation
**Depuis la préparation :** → campagne · → combat
**Depuis le bandeau de série :** → combat suivant
**Depuis l'écran de résultat :** → rejouer le combat · → village · → campagne ·
→ préparation de la bataille suivante

### Quatre à soigner en priorité

Le joueur les voit plusieurs fois par bataille, bien plus souvent que le codex
ou la boutique : **bandeau de série → combat**, et les trois sorties de
**l'écran de résultat**.

### Une transition demandée explicitement

Dans le village, **les bâtiments eux-mêmes sont cliquables**, pas seulement
leurs enseignes. Toucher un bâtiment doit **zoomer vers le point touché**
(échelle 1 → 1,18, le point sous le doigt reste fixe) pendant qu'un **voile
noir** monte, puis ouvrir un popup d'information par-dessus. À la fermeture,
l'inverse. Le château, lui, mène à son écran plein plutôt qu'à un popup.

C'est le modèle : une transition qui **part du geste du joueur**.

## Trois contraintes techniques

1. **Portrait uniquement.** La référence est 393 × 852, mais la hauteur réelle
   varie selon le téléphone (jusqu'à 987 points) et la largeur peut monter à
   495 sur un écran court. **Exprime les déplacements en fractions de l'écran
   plutôt qu'en points absolus**, sinon la transition se décale.
2. **Privilégie l'opacité et l'échelle.** Elles se portent partout. Les
   translations ne se portent que sur des éléments posés librement, pas dans un
   conteneur en auto-layout — signale-les quand tu en utilises.
3. **Chaque transition ne se joue qu'une fois**, jamais en boucle. Ce qui
   compte, ce sont les durées, les décalages et les courbes.

## Trois entrées d'écran à reprendre telles quelles

Elles existent déjà et fonctionnent — garde-les cohérentes avec tes
transitions plutôt que de les redessiner :

- **Victoire** : le titre jaillit du bas, échelle 0,3 → 1, ressort qui dépasse
  à 1,36. Confettis et étincelles qui tombent en tournant.
- **Défaite** : le titre tombe de −80 px, échelle 1,15 → 1, **sans rebond**,
  et tout est plus lent — 3,5 s contre 2,5 pour la victoire.
- **Match nul** : le titre s'abat de 1,8 → 1, comme un tampon.

Trois issues, trois lectures. Les transitions doivent suivre la même logique.
