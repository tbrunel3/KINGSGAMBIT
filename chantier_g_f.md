# Chantier G + F — l'assemblage graphique et le format d'écran

**Spec validée le 23/08/2026.** Elle clôt les questions que
[`passation_g_f.md`](passation_g_f.md) laissait ouvertes et fixe le plan
d'attaque. La passation reste valable pour tout le reste : l'inventaire des
écrans, les mesures des boutons de coin, les sept pièges de portage. **Ce
document ne les répète pas.**

Lis [`CLAUDE.md`](CLAUDE.md) d'abord.

---

## Les cinq décisions prises

| Question | Réponse | Conséquence |
|---|---|---|
| **Ordre des chantiers** | **G+F d'abord, E ensuite** | E est une *proposition* à faire, pas une liste à exécuter, et ses popups s'habilleraient de la peau que G pose. Faire E d'abord, c'était le repeindre juste après |
| **`expand` ou `keep`** | **`expand`**, inchangé | Chaque écran DOIT être ancré : c'est le travail de F. On renonce à la fidélité au pixel, on gagne un jeu qui remplit tous les téléphones |
| **Le bouton de développement** | **masqué derrière un geste** | La maquette est respectée ET le raccourci survit dans le build web exporté, qui est en release. `OS.is_debug_build()` aurait retiré au joueur son accès sur son propre téléphone |
| **Jua** | **abandonnée, la maquette est corrigée** | 2,1 Mo pour deux mots de 13 points. **Aucun code à écrire** : Jua n'est ni embarquée ni référencée, le jeu rend déjà « ROYAUME » et « CAMPAGNE » en Inter |
| **L'ancrage du village** | **deux calques** (approche A) | Voir ci-dessous — c'est le seul vrai choix d'architecture du chantier |

⚠️ **La décision `expand` est celle qui commandait tout le reste**, et elle est
prise. Ne pas la rouvrir sans le joueur : la reprendre coûte le passage sur les
sept écrans.

---

## Le village : le défaut, chiffré

Le village n'est pas « en coordonnées absolues » au sens naïf. Il porte déjà une
mitigation — `_fit_overlay_to_design()`
([`scenes/village/village.gd`](scenes/village/village.gd)) épingle une bande de
852 points de haut, centrée verticalement. Le défaut est ailleurs, et il est
plus vicieux.

**Le fond et le calque des étiquettes ne suivent pas la même loi d'échelle.**

- `assets/backgrounds/village_background.png` fait **864 × 1821**, rapport
  **0,4745**.
- La référence du projet fait 393 × 852, rapport **0,4613**.
- Le fond est posé en `KEEP_ASPECT_COVERED`
  ([`village.tscn`](scenes/village/village.tscn), `stretch_mode = 6`) : il
  **grossit** avec la hauteur du viewport.
- La bande d'étiquettes, elle, reste à 852 et suppose 393 de large.

Dérive calculée par la formule du `KEEP_ASPECT_COVERED`, en unités de jeu
(rappel du piège n°1 de `CLAUDE.md` : c'est la largeur qui MONTE quand l'écran
raccourcit) :

| Fenêtre | Viewport | Dérive du label sur son bâtiment | Bouton BATAILLE |
|---|---|---|---|
| 393 × 852 | 393 × 852 | 0 | centré |
| 360 × 800 | 393 × 873 | ~5 pt | centré |
| **393 × 700** *(web, barre d'URL)* | **478 × 852** | **~34 pt en Y, ~17 en X** | **décalé de 42 pt à gauche** |
| **430 × 1080** | **393 × 987** | **~30 pt** | centré |

Le bouton BATAILLE est calé sur `Rect2(102, 765, 189, 59)` — centre exact
196,5, soit 393/2. Sur un viewport de 478 de large, le centre réel est à 239 :
**42 points d'écart, et ça se voit.** Les six lumières de fenêtre du château,
posées à ±3 points près sur l'illustration, se décollent de leurs fenêtres.

⚠️ **Ces chiffres sont CALCULÉS, pas encore photographiés.** Ils viennent de la
formule que Godot applique, pas d'une capture. Le premier travail du chantier
(§1) est de les confirmer sur `resolutions.tscn`. S'ils ne se confirment pas,
c'est le calcul qu'il faut relire avant de toucher au village — la leçon des
quatre erreurs de la sonde économique.

---

## Le plan d'attaque, en six temps

### 1. Les instruments d'abord

Deux angles morts, et le projet a déjà payé chacun une fois.

**L'inventaire des animations est incomplet, et il le dit.** Quatre sections sur
sept n'ont jamais été relevées : `420:2` Intro, `420:3` Navigation, `420:4`
Campagne, `420:6` Résultats. Les relever avec `get_motion_context`, **section
par section** — l'outil refuse une page entière (« nothing selected »).

⚠️ Un relevé d'animations a été faux **deux** fois, pour deux raisons
différentes (les timelines vivaient sur les copies ; les popups ont gagné du
mouvement après coup). **Un relevé périme dès que le designer touche au
fichier.** Le refaire avant de déclarer quoi que ce soit.

**`resolutions.tscn` ne regarde que huit écrans.** Manquent : le **château**,
les **trois écrans de résultat** (victoire, défaite, nulle) et les **quatre
popups** (bâtiment ouvert, bâtiment verrouillé, amélioration, missions). Les
ajouter à `SCREENS` : ils héritent alors des huit formats et de
`_finish_animations()`.

**Sortie de cette étape** : un inventaire d'animations complet, et une planche
de captures qui montre ce qui casse — y compris la confirmation (ou non) des
chiffres du village ci-dessus.

### 2. Le village — deux calques

`village.tscn` remplace son `Overlay` unique par **`DecorLayer`** et
**`UiLayer`**.

**`DecorLayer` est ancré sur le rectangle réellement affiché par le fond**, pas
sur l'écran. Le rectangle se calcule avec la formule exacte du
`KEEP_ASPECT_COVERED` : `échelle = max(vp.x / 864, vp.y / 1821)`, taille
`864 × 1821 × échelle`, centrée. Les coordonnées Figma sont converties une fois,
depuis le repère de l'image — **qui est leur repère d'origine**, et c'est
pourquoi elles redeviennent vraies sur tous les formats.

Y vivent : les quatre labels de bâtiments, le label du château, le halo du
château, les six lumières de fenêtre.

**`UiLayer` reste ancré sur l'écran.** Y vivent : la barre haute (or, gemmes,
missions), les boutons de coin, et le bouton BATAILLE — qui passe en ancrage
centré-bas au lieu de son `Rect2`. C'est ce qui règle les 42 points.

Le découpage dit exactement ce que chaque chose est : **un bouton de réglages
qui s'éloignerait du bord parce que le décor a grossi serait faux**, et c'est
précisément ce qu'un calque unique produirait.

`_fit_overlay_to_design()` et `DESIGN_HEIGHT` disparaissent. La règle 4 de
`CLAUDE.md` peut alors dire « tous convertis ».

⚠️ **Piège n°2 de la passation** : aucune lecture de `position` avant
`await get_tree().process_frame`. Le rectangle du fond se calcule APRÈS la mise
en page, jamais à la construction — et les `pivot_offset` se posent après lui.

**Approches écartées, et pourquoi :**

- *Découper le village en zones comme les autres écrans.* Cohérent en apparence,
  mais les labels de bâtiments n'ont pas de zone à eux : ils sont collés à un
  raster. Ça les laisserait dériver, ou demanderait de les recaler à la main par
  format — c'est-à-dire de ne pas résoudre le problème.
- *Recadrer l'image en 393 × 852 exact.* En `expand` la hauteur varie
  **toujours** : ça réduit l'erreur sans la supprimer, et ça rogne
  l'illustration du designer.

### 3. Les boutons de coin — six tailles, deux

`scenes/ui/components/corner_button.gd` : un glyphe ou une texture, une variante
de couleur, un rang dans sa colonne. Les dix appels relevés dans la passation
s'y ramènent.

**Deux tailles, pas six** : **34** pour les boutons de coin flottants (le
compromis actuel de la bataille, et le plus juste au pouce), **52** pour le
retour en tête d'écran (plaque royale).

Ce qui bouge : codex et réglages **28 → 34** ; boutique **45 → 34** ; retour du
château **44 → 52**. Les trois retours déjà à 52 (préparation, codex, boutique)
ne bougent pas. `_corner_button_style()` de `battle.gd` déménage dans le
composant.

**Le bouton dev quitte l'écran.** Il est remplacé par un **appui long de 1,2 s
dans une zone invisible de 60 × 60 au coin haut-droit** de `UiLayer`. Rien à
voir dans la maquette, et le raccourci survit dans le build web. Le geste est à
redire au joueur au moment de la livraison — un raccourci qu'on oublie n'existe
pas.

### 4. Les animations qui restent

**Le gabarit d'entrée de modale**, posé une seule fois dans
[`scenes/ui/components/modal.gd`](scenes/ui/components/modal.gd) — qui a bien
`open()` / `close()` et **aucune animation** aujourd'hui : voile `0 → 1` sur
20 % de la durée, puis la modale en opacité `0 → 1`, `scale 0,92 → 1`, de 0,15 s
à 0,6 s, courbe `cubic-bezier(0, 0, 0.2, 1)`. Il sert d'un seul coup **tout ce
qui passe par `Modal`** — vérifié, ça fait six appelants : les trois popups de
bâtiment (`building_popup.gd` couvre les quatre états dans une seule scène), la
confirmation d'amélioration, le popup de missions, le popup de série et l'aide
`i` de la bataille. **C'est le meilleur rapport du chantier** : un seul endroit
touché, six écrans animés.

**`shop-screen`** (15 nœuds) : cascade de haut en bas. Sections et cartes sont
des **enfants de conteneur** — opacité et échelle **seulement**. Les
translations ne sont pas portables telles quelles (piège n°1, déjà payé sur le
bandeau de série).

**`mission-popup`** (24 nœuds) : **c'est DEUX animations dans une seule timeline
de maquette**, et les porter comme une entrée d'écran serait une erreur.

- *À l'ouverture* : jaillissement depuis le coin haut-droit, cascade des lignes.
- *Au moment où le joueur RÉCLAME* : remplissage des cinq barres, badge qui
  pulse, dix pièces d'or qui volent vers la bourse, rebond de la bourse.

⚠️ **Les pièces traversent l'écran** : elles partent de la ligne de mission et
atterrissent sur la bourse en haut. Elles ne peuvent pas vivre dans la modale —
il leur faut une couche au-dessus de tout.

### 5. Le reste de la peau

- **« COMBATTEZ »** qui barre le plateau au lancement du combat
  (`05_Bataille_Combat`, `410:3764`) — apparence pure, jamais portée.
- **Le cerclage d'or du popup de bâtiment VERROUILLÉ** — la maquette le cercle
  d'or, le jeu le laisse en bordure sourde.
- **La peau de la boutique** — l'écran est fonctionnel mais **brut** : ses neuf
  illustrations sont des glyphes tracés au trait. C'est le gros morceau de G.
- **Jua** — aucun code. Corriger la maquette côté designer, et fermer la
  question dans `CLAUDE.md`, `passation_g_f.md` et `figma_contexte_projet.md`.

### 6. Ce qui n'est PAS dans le périmètre

**Les deux écarts où c'est la maquette qui a tort** ne se corrigent pas côté
jeu. Ils sont déjà signalés au designer dans son propre retour `294:2` :

1. Le plateau de `05_Bataille_Combat` fait plus de 12 rangées ; le jeu va de
   5×6 à 8×9 et la taille change à chaque bataille.
2. La maquette du combat n'a ni croix de sortie, ni point `i`, ni ligne d'état.
   Le jeu les a — et c'est le designer lui-même qui les avait demandés.

**Le chantier E** (les popups d'accompagnement) reste après. Le décor : le sacre
différé a été retiré, donc E a un popup de moins à écrire.

---

## Comment le prouver

| Banc | Ce qu'il doit dire |
|---|---|
| `resolutions.tscn` | **d'abord ses trois tailles hors format**, et sur les **quatre écrans neufs** — le seul outil qui voit un problème de format |
| `screenshot.tscn` | écran par écran contre sa frame, **au même état de partie** (`1_village_avance.png`) |
| `ui_test.tscn` | **vert** — une reprise graphique qui casse un bouton ne se voit sur aucune capture, et le chantier touche aux dix boutons de coin |
| `smoke_test.tscn` | 10/10 batailles gagnables, **et les polices se chargent vraiment** — `UiTheme` retombe silencieusement sur Inter gras quand un fichier manque |

**Le critère de fin de F, mesurable** : dérive nulle du label sur son bâtiment
sur les huit formats, et BATAILLE centré partout.

⚠️ **Godot ne réimporte pas un asset remplacé** en ligne de commande :
`--headless --path . --import` après tout PNG ou TTF écrasé.

`screenshot.tscn` et `resolutions.tscn` écrivent des PNG : les lancer **sans**
`--headless`, sinon ils bloquent.

---

## Ce qui reste non tranché après ce chantier

- **La pastille `Codex` du village.** Elle vient de l'intégration, pas du
  designer : elle a été créée en clonant `Missions`. Le jeu met volontairement
  une icône discrète, parce qu'un libellé mettrait le codex au rang de MISSIONS,
  qui dit quoi faire ensuite. **À aligner dans un sens ou dans l'autre**, et §3
  est le bon moment pour poser la question.
- **`stalemate_is_draw`** traîne depuis le chantier A : le joueur doit jouer les
  deux réglages avant de trancher. Sans rapport avec G et F, mais il attend.
