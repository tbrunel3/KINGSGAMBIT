# Figma Make — King's Gambit : prototyper la navigation du jeu

Fichier `rqEdH4O2R21TuUFv7OUlF7`, page **`MAINPROJECT`** (`410:2`).

**Ce qu'on demande :** un prototype interactif de la **navigation entière** du
jeu — tous les écrans, tous les trajets entre eux, et ce qui déclenche chacun.

**Le mouvement, c'est toi qui le trouves.** Ce document ne prescrit ni durées,
ni courbes, ni effets : il dit **ce qui doit mener où**, et te laisse décider
comment. L'intégration récupérera tes timelines telles quelles.

Aujourd'hui le jeu **coupe franc** : les 20 trajets appellent tous
`change_scene_to_file` et l'écran suivant apparaît d'un coup. Aucune
continuité, nulle part.

Le contexte général est dans [`figma_contexte_projet.md`](figma_contexte_projet.md).
**Ce document ne le répète pas.**

---

## Ce document a deux moitiés

1. **Pour toi, le designer** — ce qui existe déjà, et les contraintes de
   portage : ce qu'on sait ramener dans Godot, et ce qu'on ne sait pas. À lire
   avant de lancer Make.
2. **Le prompt à coller dans Make** — self-contained, tout en bas. Il ne
   suppose aucune lecture préalable, et il ne parle **pas** d'animation.

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

Relevé complet du 23/08/2026, section par section, sur `MAINPROJECT`. Ce sont
des **entrées d'écran** : elles jouent quand l'écran arrive. Ce qu'on te
demande ici, c'est ce qui se passe **entre deux écrans**.

| Écran | node-id | Entrée existante |
|---|---|---|
| king-intro-before-dialogue | `410:35` | 2,5 s, 3 nœuds — portée |
| king-intro-dialogue | `410:71` | 4 s, 9 nœuds — portée |
| preparation-bataille-v2 | `410:7227` | 2 s, 12 nœuds — portée |
| 04_Bataille_Placement | `410:667` | 3 s, 17 nœuds — portée |
| 07-bataille-nulle | `410:5551` | 3 s, 7 nœuds — portée |
| 06_Bataille_Victoire | `410:5121` | 2,507 s, 24 nœuds — en cours |
| 07-bataille-defaite | `410:5430` | 3,5 s, 8 nœuds — en cours |
| 09/10/11-popup-batiment | `410:7342` etc. | 2 s, 2 nœuds — à porter |
| shop-screen | `410:7061` | 1,5 s, 15 nœuds — à porter |
| mission-popup | `410:5664` | 2 s, 24 nœuds — à porter |
| popup-combat-phase | `410:7190` | 2 s, 3 nœuds — à porter |

⚠️ **Deux découvertes du relevé, à connaître.**

1. **Tes trois écrans de résultat ont trois entrées vraiment différentes**, et
   le jeu n'en jouait qu'une — celle du match nul, sur les trois. Ce n'est pas
   un oubli de ta part : c'est le jeu qui était en retard sur toi, et c'est en
   cours de correction. **C'est exactement le genre de distinction qu'on
   cherche**, et tu n'as pas besoin qu'on te l'explique.
2. **La campagne, le splash et `village-avec-dame` n'ont aucune donnée de
   mouvement.** Vérifié, ce n'est pas une supposition. La carte de campagne est
   pourtant un parchemin défilant de 2300 points, et c'est l'écran où le joueur
   choisit sa prochaine bataille.

## Ce que le joueur a demandé en plus

**Les bâtiments du village doivent devenir cliquables**, pas seulement leurs
enseignes — et le passage vers le popup d'information doit **partir du point
touché**. C'est en cours côté jeu, et c'est dans le prompt comme une
interaction à prototyper, sans direction de mouvement.

## Les contraintes de PORTAGE — ce qu'on sait ramener, et ce qu'on ne sait pas

Ce n'est pas de la direction artistique : c'est la liste de ce que Godot peut
reproduire. Une animation qui sort de là sera à refaire.

1. **Opacité et échelle se portent partout.** Sans réserve.
2. **Les translations ne se portent que sur des éléments posés librement**, pas
   à l'intérieur d'un conteneur en auto-layout — côté Godot le tween se bat
   avec la mise en page. **Si une transition dépend d'une translation, dis-le**
   : on saura qu'il faut sortir l'élément de son conteneur, et on le fera.
3. **Les valeurs en points absolus se décalent.** La référence est 393 × 852,
   mais la hauteur réelle varie d'un téléphone à l'autre — jusqu'à 987 points —
   et la largeur peut monter à 495 sur un écran court. Un déplacement exprimé
   en fraction de l'écran survit à ça, pas un déplacement en points.
4. **Un `Fade-From-Black` rend la frame NOIRE à l'export statique.** Un
   rectangle noir plein écran à l'opacité 1 qui s'efface : l'export capture
   l'image 0, donc le voile. Ce n'est pas un bug — mais préviens quand une
   frame en contient un, sinon on croit l'écran cassé.
5. **La boucle de Figma est un artefact d'aperçu.** Une transition ne se joue
   qu'une fois. On reprend les décalages, les durées et les courbes, jamais
   l'itération.
6. **La maquette apporte l'apparence, jamais les règles.** Si le prototype
   montre un écran sans un bouton dont le jeu a besoin, on garde le bouton et
   on l'habille. Si un libellé annonce une règle que le code ne joue pas,
   **c'est le libellé qu'on corrige**. Ça a déjà coûté un codex entier à
   refaire.

## Ce dont on a besoin en retour

**Un prototype Make dont on peut lire la timeline suffit.** Nos outils
extraient les durées, les décalages, les courbes et les propriétés animées
(`get_motion_context`). **Ne rédige aucun tableau à la main.**

---

# PARTIE 2 — le prompt à coller dans Figma Make

> Tout ce qui suit est self-contained. Copie-le tel quel.

---

Crée un prototype interactif mobile en portrait, **393 × 852**, pour un jeu de
stratégie fantasy médiéval inspiré des échecs appelé **King's Gambit**.

**L'objectif est la NAVIGATION** : tous les écrans, et tous les trajets entre
eux. Les écrans peuvent rester schématiques ; ce qui compte, c'est que le
prototype se parcoure en entier, du lancement jusqu'à l'écran de résultat et
retour.

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
bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un trait d'or `#ffe580`
et doublé d'un filet d'or fin. Panneaux, cartes, bannières, boutons et badges
en sortent tous.

## Les 11 écrans

1. **Splash** — logo, écran d'ouverture.
2. **Intro du Roi** — une illustration d'un roi-pièce d'échecs assis sur un
   trône, l'air abattu, à côté d'un second trône vide. Un panneau de dialogue
   en bas, avec un bouton COMMENCER.
3. **Village** — vue isométrique d'une île avec un château central et quatre
   bâtiments autour (une caserne, des écuries, un cloître, un donjon). Chaque
   bâtiment porte une enseigne avec son nom et son niveau. Barre haute avec or,
   gemmes et un bouton MISSIONS ; boutons `i` (codex) et réglages en haut à
   droite. Un gros bouton doré **BATAILLE** en bas au centre, un bouton
   boutique à sa gauche.
4. **Château Royal** — plein écran, salle du trône, deux trônes dont un vide.
   Un panneau en bas avec un bouton AMÉLIORER, une flèche retour en haut à
   gauche.
5. **Codex** — écran défilant, encyclopédie : une carte par pièce, un tableau
   par niveau. Flèche retour.
6. **Boutique** — écran défilant : coffres, packs de gemmes, packs d'or.
   Flèche retour.
7. **Carte de campagne** — un **parchemin défilant vertical**, très long
   (environ 2300 points), avec dix cachets de cire numérotés reliés par un
   chemin. Certains verrouillés, un disponible, les autres gagnés. Toucher un
   cachet disponible mène à la préparation.
8. **Préparation de bataille** — **le seul écran clair du jeu** : parchemin
   crème et panneaux blancs, quand tous les autres sont en nuit et or. C'est
   voulu. On y compose son armée, avec un bouton COMBATTRE en bas.
9. **Placement / Combat** — un plateau de jeu quadrillé (entre 5×6 et 8×9
   cases, la taille change à chaque bataille) avec des pièces bleues et rouges.
   Barre d'état en haut, croix de sortie et bouton `i` en haut à droite,
   bandeau en bas.
10. **Bandeau de série** — un écran court entre deux combats d'une même
    bataille : une carte d'annonce qui dit où on en est et ce qu'on a perdu.
    On en sort au doigt, ou tout seul après un délai.
11. **Écran de résultat** — trois variantes : **victoire** (bleu et or,
    confettis), **défaite** (rouge sombre, tentes de camp), **match nul**
    (gris acier). Un grand mot gravé, une plaque de statistiques, puis des
    boutons : un principal, un secondaire, et deux d'action (ROYAUME,
    CAMPAGNE).

## Les 20 trajets à rendre navigables

- **Splash** → village *(sauvegarde existante)* · → intro *(première partie)*
- **Intro** → village *(fin du dialogue)*
- **Village** → château *(on touche le Château Royal)* · → codex *(bouton `i`)*
  · → boutique · → campagne *(bouton BATAILLE)*
- **Château** → village *(flèche retour)*
- **Codex** → village *(flèche retour)*
- **Boutique** → village *(flèche retour)*
- **Campagne** → village *(flèche retour)* · → préparation *(on touche un
  cachet)*
- **Préparation** → campagne *(flèche retour)* · → combat *(bouton COMBATTRE)*
- **Combat** → village *(croix de sortie)*
- **Bandeau de série** → combat suivant *(au doigt, ou après un délai)*
- **Écran de résultat** → rejouer le combat · → village *(ROYAUME)* · →
  campagne *(CAMPAGNE)* · → préparation de la bataille suivante

### Quatre à soigner en priorité

Le joueur les voit plusieurs fois par bataille, bien plus souvent que le codex
ou la boutique : **bandeau de série → combat**, et les **trois sorties de
l'écran de résultat**.

## Une interaction demandée explicitement

Dans le village, **les bâtiments illustrés eux-mêmes sont cliquables**, pas
seulement leurs enseignes. Toucher un bâtiment ouvre un popup d'information sur
ce bâtiment, et le passage doit **partir du point touché**. Le château, lui,
mène à son écran plein plutôt qu'à un popup.

## Deux contraintes techniques

1. **Portrait uniquement.** La référence est 393 × 852, mais la hauteur réelle
   varie selon le téléphone — jusqu'à 987 points — et la largeur peut monter à
   495 sur un écran court. Le prototype doit tenir sur ces trois formats.
2. **Le prototype ne décide d'aucune règle de jeu.** Les libellés, les
   chiffres et les compteurs sont illustratifs. Si une valeur est nécessaire,
   mets-en une plausible : elle sera remplacée par celle du code.
