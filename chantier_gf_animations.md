# G + F — l'inventaire des animations à importer

**Ce document existe parce qu'un relevé d'animations a déjà été faux deux
fois**, et que la demande du joueur est cette fois explicite : *« importer les
écrans avec les animations, sans rien oublier »*.

Il tient l'inventaire COMPLET des timelines de la page `MAINPROJECT`
(`410:2`), ce qui est porté et ce qui ne l'est pas. Il se met à jour à chaque
portage, et à chaque relevé.

---

## Pourquoi les relevés précédents étaient faux

Deux fois, et pour deux raisons différentes — les deux valent d'être connues :

1. **Le premier relevé** interrogeait les seize frames de la page d'origine et
   concluait « deux écrans animés ». Il en manquait quatre : **les timelines
   vivaient sur les COPIES** de la page « Écrans triés », pas sur les
   originaux.
2. **Le deuxième relevé**, corrigé, listait six frames — et déclarait les
   popups *sans aucune donnée de mouvement*. **C'est faux depuis la
   réorganisation** : la section Popups en porte quatre, dont la plus riche du
   fichier après le placement.

La leçon est la même dans les deux cas : **un relevé d'animations périme dès
que le designer touche au fichier.** Refaire `get_motion_context` en
`recursive` sur les **sept sections** avant de déclarer quoi que ce soit.

⚠️ `get_motion_context` refuse une PAGE en argument (« nothing selected »). Il
faut l'appeler section par section : `420:2` à `420:8`.

---

## L'inventaire

| Frame | node-id | Durée | Nœuds | État |
|---|---|---|---|---|
| **king-intro-dialogue** | `410:71` | 3 s | 6 | ✅ porté — `king_intro_dialogue.gd` |
| **king-intro-before-dialogue** | `410:35` | 2,5 s | 1 | ✅ porté |
| **07-bataille-nulle** | `410:5551` | 3 s | 7 | ✅ porté — `battle_result._animate_entry`, les trois peaux |
| **preparation-bataille-v2** | `410:7227` | 2 s | 12 | ✅ porté — opacités et échelles seulement (enfants de conteneur) |
| **04_Bataille_Placement** | `410:667` | 3 s | **17** | ✅ porté — `battle._animate_entry` |
| **popup-combat-phase** | `410:7190` | — | — | ✅ porté (peau) — pas de timeline propre |
| **mission-popup** | `410:5664` | 2 s | **24** | ❌ **PAS porté — la plus riche du fichier** |
| **09-popup-batiment** | `410:7342` | 2 s | 2 | ❌ pas porté |
| **10-popup-batiment-verrouille** | `410:7488` | 2 s | 2 | ❌ pas porté |
| **11-popup-amelioration** | `410:7629` | 2 s | 2 | ❌ pas porté |
| **shop-screen** | `410:7061` | 1,5 s | **15** | ❌ pas porté |

Sections restant à relever : `420:2` Intro *(les deux frames connues, à
reconfirmer)*, `420:3` Navigation, `420:4` Campagne, `420:6` Résultats.
**Tant que ces quatre relevés ne sont pas faits, cet inventaire est
incomplet et doit être annoncé comme tel.**

---

## Le détail de ce qui reste à porter

### `mission-popup` — 24 nœuds, 2 s

C'est une **chorégraphie de récompense**, pas une entrée d'écran. Dans
l'ordre :

1. la modale jaillit du coin haut-droit (`translate 97,5 / −394`, `scale
   0,05 → 1`, ressort `cubic-bezier(0.45, 1.45, 0.8, 1)`) ;
2. croix, titre, séparateur et liste montent de 10 px en cascade, 30 ms
   d'écart, courbe `expo-out` ;
3. **les barres de progression se REMPLISSENT** (`width: 0 → N`), décalées de
   75 ms l'une après l'autre — cinq barres ;
4. le badge « à réclamer » se comprime à 0,85, gonfle à 1,15, puis **disparaît**
   en `scale 0` ;
5. **dix pièces d'or** éclosent (`scale 0 → 1,4 → 1`), s'éparpillent, puis
   **volent vers la bourse** (`translate ≈ −20 / −288`) en s'effaçant ;
6. la bourse d'or **rebondit** à l'arrivée — huit impulsions de `scale`
   entre 1,09 et 1,14, une par pièce reçue.

⚠️ **Ne pas porter ça comme une entrée d'écran.** Les points 4 à 6 ne se jouent
qu'au moment où le joueur **réclame** une mission. Les points 1 à 3 sont
l'ouverture. Ce sont deux animations distinctes dans une seule timeline de
maquette.

⚠️ **Les pièces qui volent traversent l'écran** : elles partent de la ligne de
mission et atterrissent sur la bourse, en haut. Elles ne peuvent donc PAS
vivre dans la modale — il leur faut une couche au-dessus de tout, comme
`Overlay` au village.

### Les trois popups de bâtiment — 2 nœuds chacun, 2 s

Toutes les trois la même entrée, et c'est une bonne nouvelle : **un seul
portage sert les trois**, comme `building_popup.gd` sert déjà les quatre
états.

- `Dark-Overlay` : opacité 0 → 1 sur 20 % de la timeline, `ease-out`
- la modale : opacité 0 → 1, `translate 0/+30 → 0`, `scale 0,92 → 1`, de 7,5 %
  à 30 % (soit 0,15 s → 0,6 s), courbe `cubic-bezier(0, 0, 0.2, 1)`

C'est le gabarit d'entrée de modale du jeu entier. Une fois posé dans `Modal`,
il sert aussi la confirmation d'amélioration et le codex.

### `shop-screen` — 15 nœuds, 1,5 s

Une cascade de haut en bas, sur trois niveaux :

1. l'en-tête tombe de −40 px avec ressort (0 → 0,35 s) ;
2. le panneau des monnaies éclôt en `scale 0,5 → 1` (0,2 → 0,5 s) ;
3. **chaque section** monte de +35 à +40 px avec `scale 0,92 → 1` — coffres à
   0,15 s, gemmes à 0,5 s, or à 0,75 s ;
4. **chaque carte** éclôt en `scale 0,5 → 1`, 100 ms d'écart, dans l'ordre de
   lecture ;
5. le bandeau légendaire éclôt en **ressort élastique** (`scale 0,85 → 1`).

⚠️ Les cartes et les sections sont des enfants de conteneur dans le jeu : elles
n'ont droit qu'à l'**opacité** et à l'**échelle**. Les translations de +35 px
des trois sections ne sont pas portables telles quelles — c'est la règle qui a
déjà collé le bandeau de série en haut de l'écran.

---

## Les trois pièges du portage, tous payés

1. **Ne jamais animer la `position` d'un enfant de conteneur.** Le tween se bat
   avec la mise en page. Exception : un enfant de `Control` NU, comme
   `Safe/Overlay` en bataille — c'est ce qui a permis de porter les
   translations du placement telles quelles.
2. **Une position ne se lit qu'une fois les ancres posées.** Relever
   `node.position` à la construction rend une valeur qui ne veut rien dire, et
   le tween ramène l'élément vers une coordonnée fausse. Mesuré : le bandeau
   de déploiement disparaissait de l'écran sur les huit formats.
   `await get_tree().process_frame` AVANT toute lecture de position, et avant
   de poser les `pivot_offset`.
3. **Une animation d'entrée rend les bancs de capture menteurs.**
   `screenshot.tscn` et `resolutions.tscn` sautent à la fin des tweens
   (`_finish_animations`). Tout nouvel outil de capture doit faire pareil.

Et un quatrième, propre à la lecture de la maquette :

4. **La boucle est un artefact d'aperçu.** Figma rejoue l'entrée en rond faute
   de savoir qu'elle ne se joue qu'une fois. Ce qui compte, ce sont les
   décalages, les durées et les courbes — jamais la répétition.
