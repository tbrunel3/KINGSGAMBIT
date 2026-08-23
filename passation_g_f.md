# Passation — chantiers G et F

> ⚠️ **LES DÉCISIONS SONT PRISES DEPUIS LE 23/08/2026.** Elles sont dans
> [`chantier_g_f.md`](chantier_g_f.md), avec le plan d'attaque en six temps.
> **Lis-le d'abord.** Ce document-ci reste la référence pour l'inventaire, les
> mesures et les pièges — mais partout où il dit « pas tranché », c'est lui qui
> est périmé, pas la spec.

**Ce document existe pour la fenêtre qui prendra G et F à froid.** Il dit ce
qu'ils sont, la décision qui les ouvre, l'inventaire de ce qui reste écran par
écran, et les pièges déjà payés — avec leurs chiffres.

Lis [`CLAUDE.md`](CLAUDE.md) d'abord. Ce document ne le répète pas ; il le
prolonge sur les seuls points que le manuel n'a pas.

---

## Ce que sont G et F, et pourquoi ils sont menés ensemble

- **G** — l'assemblage graphique : reprendre la peau de chaque écran d'après la
  bibliothèque Figma, popups et images comprises.
- **F** — le format d'écran : rendre chaque écran indifférent à la taille de
  l'appareil.

Le joueur a demandé les deux dans la même phrase, et les mener ensemble est le
bon choix : **reprendre la peau d'un écran et l'ancrer sont le même geste sur
le même fichier**. Les séparer ferait passer deux fois sur chaque écran.

## ⚠️ LA DÉCISION QUI OUVRE G, ET QUI N'EST TOUJOURS PAS PRISE

`window/stretch/aspect` vaut **`expand`** dans `project.godot`.

| | `expand` *(actuel)* | `keep` |
|---|---|---|
| Le viewport | épouse l'écran, la hauteur varie | **393 × 852 exactement**, bandes noires |
| Conséquence | chaque écran DOIT être ancré | la fidélité au pixel devient absolue |
| Ce qu'on perd | la fidélité au pixel | le responsive |

**« Respect graphique absolu » et « formats responsive » étaient dans la même
phrase de la demande, et ils ne peuvent pas être vrais tous les deux.** Poser
la question au joueur AVANT de commencer : elle change la nature du chantier
entier, et se tromper coûte le passage sur les sept écrans.

---

## 1. L'ALIGNEMENT DES BOUTONS — demandé explicitement, et c'est le pire écart

> « il faudra aussi aligner les boutons des paramètres etc., sur les écrans,
> parce que là c'est n'importe quoi »

Il a raison, et voici la mesure. **La même classe de contrôle — un bouton de
coin, rond ou carré, qui sort d'un écran ou ouvre un panneau — existe en SIX
tailles et QUATRE habillages :**

| Écran | Bouton | Taille | Position | Habillage |
|---|---|---|---|---|
| village | dev (clé) | **24 × 24** | `(362, 14)` absolu | carré `PANEL_LIGHT`, r = 4 |
| village | codex `i` | **28 × 28** | `(319, 44)` absolu | rond `#174971`, r = 14 |
| village | réglages ⚙ | **28 × 28** | `(353, 44)` absolu | rond `#174971`, r = 14 |
| village | boutique | **45 × 45** | `(40, 761)` absolu | carré `#3873F2`, r = 10, filet |
| bataille | sortie ✕ | **34 × 34** | ancré droite, haut 12 | `_corner_button_style()` |
| bataille | aide `i` | **34 × 34** | ancré droite, haut 54 | idem |
| château | retour ← | **44 × 44** | en tête de conteneur | carré r = 8, ombre portée |
| préparation | retour ← | **52 × 52** | en tête | `RoyalPlate` or, r = 12 |
| codex | retour ← | **52 × 52** | en tête | `RoyalPlate` or, r = 12 |
| boutique | retour ← | **52 × 52** | en tête | `RoyalPlate` or, r = 12 |

**Ce qu'il faut en faire :**

1. **Un seul composant**, `scenes/ui/components/corner_button.gd`, qui prend un
   glyphe (ou une texture), une variante de couleur, et un rang dans la
   colonne. Les dix appels ci-dessus s'y ramènent.
2. **Deux tailles, pas six** : une pour les boutons de coin flottants (34 est
   le compromis actuel de la bataille, et c'est la plus juste au pouce), une
   pour le retour en tête d'écran (52, la plaque royale). Tout le reste
   s'aligne dessus.
3. ⚠️ **Le village est le seul écran encore en coordonnées ABSOLUES**
   (cf. `CLAUDE.md`, règle 4 : « Reste à convertir : village »). Ses quatre
   boutons y sont posés en `Rect2` en dur. **Sa conversion en zones ancrées
   fait partie de F**, et c'est elle qui permettra d'aligner ses boutons sur
   les autres écrans au lieu de les recaler à la main.
4. **Le bouton de développement (la clé) n'est dans aucune maquette.** Il
   apparaît dans toutes les captures, en haut à droite, et chevauche
   visuellement la rangée des réglages. Décider : le masquer hors build de
   débogage (`OS.is_debug_build()`), ou l'assumer. ⚠️ **Attention** : le joueur
   teste sur son téléphone via le build web EXPORTÉ, donc en release — le
   masquer lui retire son raccourci. Lui poser la question.

---

## 2. L'INVENTAIRE DES ANIMATIONS

**Un relevé d'animations a déjà été faux DEUX fois**, pour deux raisons
différentes, et les deux valent d'être connues :

1. Le premier interrogeait les seize frames de la page d'origine et concluait
   « deux écrans animés ». Il en manquait quatre : **les timelines vivaient sur
   les COPIES** de la page « Écrans triés ».
2. Le deuxième, corrigé, déclarait les popups **sans aucune donnée de
   mouvement**. C'est faux depuis la réorganisation : la section en porte
   **quatre**.

**La leçon : un relevé d'animations périme dès que le designer touche au
fichier.** Le refaire avant de déclarer quoi que ce soit.

⚠️ `get_motion_context` **refuse une PAGE** en argument (« nothing selected »).
Il faut l'appeler **section par section** : `420:2` à `420:8`.

| Frame | node-id | Durée | Nœuds | État |
|---|---|---|---|---|
| king-intro-dialogue | `410:71` | 3 s | 6 | ✅ `king_intro_dialogue.gd` |
| king-intro-before-dialogue | `410:35` | 2,5 s | 1 | ✅ porté |
| 07-bataille-nulle | `410:5551` | 3 s | 7 | ✅ `battle_result._animate_entry` |
| preparation-bataille-v2 | `410:7227` | 2 s | 12 | ✅ opacités et échelles seulement |
| 04_Bataille_Placement | `410:667` | 3 s | **17** | ✅ `battle._animate_entry` |
| **mission-popup** | `410:5664` | 2 s | **24** | ❌ **la plus riche du fichier** |
| **09-popup-batiment** | `410:7342` | 2 s | 2 | ❌ |
| **10-popup-batiment-verrouille** | `410:7488` | 2 s | 2 | ❌ |
| **11-popup-amelioration** | `410:7629` | 2 s | 2 | ❌ |
| **shop-screen** | `410:7061` | 1,5 s | **15** | ❌ |

⚠️ **QUATRE SECTIONS N'ONT PAS ÉTÉ RELEVÉES** : `420:2` Intro (les deux frames
connues sont à reconfirmer), `420:3` Navigation, `420:4` Campagne, `420:6`
Résultats. **Cet inventaire est donc incomplet, et il le dit plutôt que de
prétendre le contraire.** Commencer par là.

### `mission-popup` — 24 nœuds, et ce sont DEUX animations

Dans l'ordre : la modale jaillit du coin haut-droit (`translate 97,5 / −394`,
`scale 0,05 → 1`, ressort) ; croix, titre, séparateur et liste montent de 10 px
en cascade à 30 ms d'écart ; **les cinq barres de progression se remplissent**
(`width: 0 → N`), décalées de 75 ms ; le badge « à réclamer » se comprime à
0,85, gonfle à 1,15 puis disparaît ; **dix pièces d'or** éclosent, s'éparpillent
et **volent vers la bourse** ; la bourse **rebondit** — huit impulsions de
`scale` entre 1,09 et 1,14.

⚠️ **Ne pas porter ça comme une entrée d'écran.** Les points 1 à 3 sont
l'ouverture ; les suivants ne se jouent **qu'au moment où le joueur réclame**
une mission. Deux animations dans une seule timeline de maquette.

⚠️ **Les pièces traversent l'écran** : elles partent de la ligne de mission et
atterrissent sur la bourse en haut. Elles ne peuvent donc pas vivre dans la
modale — il leur faut une couche au-dessus de tout.

### Les trois popups de bâtiment — un seul portage pour les trois

Même entrée partout : `Dark-Overlay` en opacité 0 → 1 sur 20 % de la timeline ;
la modale en opacité 0 → 1, `translate 0/+30 → 0`, `scale 0,92 → 1`, de 0,15 s
à 0,6 s, courbe `cubic-bezier(0, 0, 0.2, 1)`.

**C'est le gabarit d'entrée de modale du jeu entier.** Posé une fois dans
`Modal`, il sert aussi la confirmation d'amélioration.

### `shop-screen` — 15 nœuds, cascade de haut en bas

En-tête qui tombe de −40 px avec ressort ; panneau des monnaies en
`scale 0,5 → 1` ; **chaque section** monte de +35/+40 px avec `scale 0,92 → 1`
(coffres 0,15 s, gemmes 0,5 s, or 0,75 s) ; **chaque carte** éclôt en
`scale 0,5 → 1` à 100 ms d'écart ; le bandeau légendaire en ressort élastique.

⚠️ Les sections et les cartes sont des **enfants de conteneur** : opacité et
échelle seulement. Les translations ne sont pas portables telles quelles.

---

## 3. LES ÉCRANS — ce qui est fait, ce qui ne l'est pas

Bibliothèque : page **`MAINPROJECT`** (`410:2`), 20 écrans en 7 sections. La
table complète des node-ids est dans [`CLAUDE.md`](CLAUDE.md).

**Onze écrans ont été confrontés à leur frame et sont conformes** : village,
campagne, préparation, boutique, placement, combat, codex, bandeau de série,
popup de bâtiment (ouvert et verrouillé), popup de missions. Les huit formats
de `resolutions.tscn` passent sur chacun.

**Ce qui reste, écran par écran :**

| À faire | Où |
|---|---|
| Le lettrage **« COMBATTEZ »** qui barre le plateau au début du combat | `05_Bataille_Combat` `410:3764` — de l'apparence pure, jamais portée |
| La peau de `mission-popup` et des trois popups de bâtiment | déjà proches ; reste l'animation |
| Le **cerclage d'or du popup de bâtiment VERROUILLÉ** | la maquette le cercle d'or, le jeu le laisse en bordure sourde |
| L'ancrage du **village** | dernier écran en coordonnées absolues |

**Deux écarts où c'est la MAQUETTE qui a tort**, signalés au designer dans son
propre retour `294:2` et jamais corrigés depuis :

1. ⚠️ **Le plateau de `05_Bataille_Combat` fait toujours plus de 12 rangées.**
   Le jeu va de **5×6 à 8×9** et la taille change à chaque bataille. Ce n'est
   pas du cadrage : sur 360 points utiles, 5 colonnes donnent des cases de 72
   points, 8 colonnes encore 45, en dessous ça ne se touche plus au pouce. Et
   depuis que chaque coup est joué à la main, chaque rangée en plus est un tour
   de trajet avant le contact.
2. La maquette n'a **ni croix de sortie, ni point `i`, ni ligne d'état** sur le
   combat. Le jeu les a — et c'est le designer lui-même qui les avait demandés.

---

## 4. LES FORMATS — ce qui est fait et ce qui reste

`resolutions.tscn` capture **huit tailles**, dont **trois hors format** :
`web-393x700`, `court-360x620`, `tres-long-430x1080`. **Ce sont celles-là qu'il
faut regarder en premier** — les cinq d'origine avaient toutes le même rapport,
et le banc ne pouvait structurellement pas voir un problème de format.

Passés au crible : carte de campagne, village, combat, préparation, boutique,
placement. **Reste : château, codex, écrans de résultat, popups.**

Les cinq pièges du format sont dans [`CLAUDE.md`](CLAUDE.md) > « Le format
d'écran ». Le plus contre-intuitif : **la largeur en unités de jeu ne descend
jamais sous 393** — c'est la HAUTEUR qui varie.

---

## 5. LES PIÈGES DU PORTAGE, TOUS PAYÉS

1. **Ne jamais animer la `position` d'un enfant de conteneur.** Le tween se bat
   avec la mise en page. *Exception* : un enfant de `Control` **nu**, comme
   `Safe/Overlay` en bataille — c'est ce qui a permis de porter les
   translations du placement telles quelles.
2. **Une position ne se lit qu'une fois les ancres posées.** Relever
   `node.position` à la construction rend une valeur qui ne veut rien dire.
   Mesuré : le bandeau de déploiement disparaissait de l'écran sur **les huit
   formats**, y compris 430 × 1080 où la hauteur ne manque pas — c'est ce qui a
   permis d'écarter le débordement. `await get_tree().process_frame` AVANT
   toute lecture de position, et avant de poser les `pivot_offset`.
3. **Une animation d'entrée rend les bancs de capture menteurs.**
   `screenshot.tscn` et `resolutions.tscn` sautent à la fin des tweens
   (`_finish_animations`). Tout nouvel outil de capture doit faire pareil.
4. **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` et `AUTOWRAP_WORD_SMART` sur
   TOUT libellé.** Dans une pastille de 66 points, « 145 » se replie **à un
   caractère par ligne**, la pastille triple de hauteur et l'en-tête s'étire
   avec elle. `shop.gd` a son `_text()` maison qui coupe l'autowrap ; reprendre
   le même réflexe partout.
5. **Un PNG exporté depuis Figma n'est pas détouré** — il arrive avec le fond
   de la frame cuit dedans, alpha entièrement opaque. Vérifié encore sur le
   picto de boutique. **Prendre l'image SOURCE** (`download_assets` >
   `rawImages`), jamais l'`export`.
6. **Godot ne réimporte pas un asset remplacé** : `--headless --path . --import`
   après tout PNG ou TTF écrasé.
7. **Une comparaison entre le jeu et la maquette n'est valable qu'à ÉTAT DE
   PARTIE ÉGAL.** Les captures partaient d'une sauvegarde neuve — tout au
   niveau 1, deux bâtiments verrouillés — face à une maquette qui montre un
   château Nv.5. L'écran semblait différent alors que c'était le même écran à
   un autre moment. D'où `1_village_avance.png`.

---

## 6. COMMENT LE PROUVER

| Banc | Ce qu'il doit dire |
|---|---|
| `resolutions.tscn` | et **d'abord ses trois tailles hors format** — le seul outil qui voit un problème de format |
| `screenshot.tscn` | comparer écran par écran avec la frame, **au même état de partie** |
| `ui_test.tscn` | doit rester vert : une reprise graphique qui casse un bouton ne se voit sur aucune capture |
| `smoke_test.tscn` | 10/10 batailles gagnables, et il vérifie désormais que **les polices se chargent vraiment** |

⚠️ **`smoke_test` vérifie maintenant les polices**, et c'est là parce que
`UiTheme` retombe **silencieusement** sur Inter gras quand un fichier manque ou
ne s'importe pas. Un écran en Inter là où la maquette veut Poppins se lit
« l'intégration n'a pas été faite » alors que le code la demande bien.

---

## 7. CE QUI N'EST PAS TRANCHÉ

- ⚠️ **`expand` ou `keep`** — voir en tête. C'est la première question.
- ⚠️ **Jua** : l'écran de nul porte « ROYAUME » et « CAMPAGNE » en Jua, 13
  points. Jua pèse **2,1 Mo** (revérifié). Le joueur a dit « tu utilises les
  polices de Figma, point final » — c'est le seul endroit où cette consigne se
  heurte à une mesure. Embarquer, ou corriger la maquette sur deux mots.
- **La pastille `Codex`** posée dans la maquette du village vient de
  l'intégration, pas du designer : elle a été créée en clonant `Missions`. Le
  jeu met volontairement une icône discrète, parce qu'un libellé mettrait le
  codex au rang de MISSIONS, qui dit quoi faire ensuite. À aligner dans un sens
  ou dans l'autre.
- **Le bouton de développement** (la clé) — voir le point 1.4.
- **`stalemate_is_draw`** traîne depuis le chantier A : le joueur doit jouer les
  deux réglages avant de trancher. Sans rapport avec G et F, mais il attend.

---

## 8. CE QUI A ÉTÉ FAIT JUSTE AVANT, ET QUI CHANGE LE DÉCOR

- **Le chantier H — la boutique** est terminé et mesuré. Règles dans
  [`chantier_h_boutique.md`](chantier_h_boutique.md). L'écran existe,
  fonctionnel mais **brut** : ses neuf illustrations sont des glyphes tracés au
  trait, et c'est **G** qui doit lui donner sa peau.
- **Poppins** est embarquée pour les enseignes (village). Détail dans
  `CLAUDE.md` > « Les polices viennent de la maquette ».
- **Le sacre différé a été retiré** après mesure : il ne coûtait pas une seule
  Dame sur les deux bancs. E a un popup de moins à écrire.
- **La table des node-ids de `CLAUDE.md` a été refaite** pour `MAINPROJECT` :
  les identifiants des versions précédentes sont morts.
