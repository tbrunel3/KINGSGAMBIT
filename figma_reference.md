# Référence Figma — node-ids, animations, polices

⚠️ **Cette page est de la RÉFÉRENCE, pas une règle.** Les règles de
collaboration avec la maquette vivent dans [`CLAUDE.md`](CLAUDE.md) — d'abord
la règle 2, « Figma apporte l'apparence, jamais les règles », et la liste des
endroits où la maquette dit autre chose que le jeu.

Elle a été sortie du manuel le 25/08/2026 parce que `CLAUDE.md` est chargé à
**chaque** session, alors que cette table ne sert qu'aux sessions d'intégration.
Rien n'a été perdu au passage.

**Voir aussi** : [`figma_contexte_projet.md`](figma_contexte_projet.md), qui est
la même matière rédigée pour le **designer**, et les briefs `figma_prompt_*.md`.

---

## Import Figma V2

Fichier : `rqEdH4O2R21TuUFv7OUlF7`. Les écrans se lisent avec `get_design_context`
en passant le node-id ci-dessous (le compte connecté a un siège Full).

⚠️ **Le fichier a TROIS pages, et c'est la DERNIÈRE qui fait foi.**
`get_metadata` sans `nodeId` n'en annonce qu'une ; les autres se découvrent par
`figma.root.children` via `use_figma`. Le designer a rangé le 23/08 tous les
écrans dans une page neuve — **les node-ids des versions précédentes sont
morts**, et un relevé fait sur les anciennes pages parle d'un fichier périmé.

| Page | node-id | Ce qu'elle porte |
|---|---|---|
| **`MAINPROJECT`** | **`410:2`** | **la bibliothèque à jour**, rangée en 7 sections. On travaille ici, et nulle part ailleurs |
| `Écrans triés` | `248:2` | les copies qui portent les **timelines** que les originaux n'ont pas, et le retour du designer `294:2` |
| `KINGS GAMBIT` | `0:1` | la page d'origine : images sources, planche de composants `2:1224`, pièces SVG `32:2`, `KINGSGAMBIT_COIN` `114:2`, `LOGO_STUDIOBNL` `116:573` |

### Les écrans de `MAINPROJECT` — tous portés

| Section | Écran | node-id |
|---|---|---|
| 🎬 Intro `420:2` | splash-screen | `410:3` |
| | king-intro-before-dialogue | `410:35` |
| | king-intro-dialogue | `410:71` |
| 🏘️ Navigation `420:3` | village-avec-dame / sans-dame | `410:153` / `410:196` |
| | chateau-royal-avec-dame / sans-dame | `410:233` / `410:286` |
| 🗺️ Campagne `420:4` | 02_Campagne *(parchemin défilant de 2 300 pt)* | `410:342` |
| ⚔️ Combat `420:5` | preparation-bataille-v2 *(le seul écran clair du jeu)* | `410:7227` |
| | 04_Bataille_Placement | `410:667` |
| | 05_Bataille_Combat | `410:3764` |
| | popup-combat-phase *(le bandeau de série)* | `410:7190` |
| 🏆 Résultats `420:6` | 06_Bataille_Victoire | `410:5121` |
| | 07-bataille-defaite | `410:5430` |
| | 07-bataille-nulle *(peau d'acier, `BattleResult.draw_skin`)* | `410:5551` |
| 📋 Popups `420:7` | mission-popup *(ouverture et réclamation séparées)* | `410:5664` |
| | 09-popup-batiment | `410:7342` |
| | 10-popup-batiment-verrouille *(cerclé d'or)* | `410:7488` |
| | 11-popup-amelioration | `410:7629` |
| | confirm-upgrade-modal | `410:7769` |
| | 12-popup-donjon-tours | `492:2` |
| | popups guide : pat / composition / aura / temps réel | `499:2` `500:2` `500:55` `500:108` |
| 📖 Codex & Shop `420:8` | codex-popup-v3 | `410:6525` |
| | shop-screen | `410:7061` |
| *(hors page)* | écrans de **bâtiment** | `517-2` |

Les quatre états du popup de bâtiment vivent dans **une seule scène**
(`building_popup.gd`), leur entrée commune dans `Modal`.

⚠️ **Deux écrans que la bibliothèque n'a PAS repris**, et qui n'existent que sur
les anciennes pages : `preparation-bataille-10-v3` (`330:2`, la préparation plus
le bandeau de la Dame captive) et la planche `12-composants`. Le code de la
bataille 10 s'appuie sur le premier (`battle_prep._build_stake_band`) : ne pas
conclure qu'il a disparu du jeu parce qu'il a disparu de la page.

**Deux images de la page d'origine `0:1` n'appartiennent à aucune frame :**

- **La Dame captive** — la pièce derrière des barreaux. C'est l'image centrale de
  l'histoire, et elle est **en jeu** : bandeau d'enjeu de la préparation de la
  **bataille 10**, la seule que `Balance.CAMPAIGN` fasse déclarer `dame`.
  ⚠️ *En la ré-exportant* : l'export du nœud arrive avec le fond gris du canvas
  (alpha entièrement opaque) ; c'est l'image SOURCE qu'il faut prendre. Le PNG du
  dépôt (**800 × 1259**, alpha propre) a été reversé dans la maquette.
- **Une carte de campagne illustrée** (`209:423`) — **vérifié, et le verdict est
  non.** C'est un `RECTANGLE` à remplissage image : les numéros d'étape sont
  peints DANS le raster, et elle ne couvre que les batailles 6 à 10. Le jeu trace
  ses cachets par-dessus la carte, et ce sont eux qui disent verrouillé /
  disponible / gagné. Il faudrait une RE-GÉNÉRATION sans les pastilles, demandée
  dans [`figma_prompt_codex.md`](figma_prompt_codex.md). `parchment_map.jpg`
  reste en place jusque-là.

### L'inventaire des animations — relevé du 23/08/2026, tout est porté

⚠️ **Le relevé ne se fait pas sur la page principale.** Une part des timelines
vit sur les **copies** de la page « Écrans triés » (`248:2`). Un relevé fait sur
les seules frames de la page principale concluait « deux écrans animés » — il en
manquait quatre, dont la plus riche du fichier. Passer `get_motion_context` en
`recursive` sur **les deux pages**, section par section (il refuse une page
entière).

| Écran | node-id | Durée | Nœuds |
|---|---|---|---|
| king-intro-before-dialogue | `410:35` | 2,5 s | 3 |
| king-intro-dialogue | `410:71` | 4 s | 9 |
| preparation-bataille-v2 | `410:7227` | 2 s | 12 |
| 04_Bataille_Placement | `410:667` | 3 s | **17** |
| popup-combat-phase | `410:7190` | 2 s | 3 |
| 06_Bataille_Victoire | `410:5121` | 2,507 s | **24** |
| 07-bataille-defaite | `410:5430` | 3,5 s | 8 |
| 07-bataille-nulle | `410:5551` | 3 s | 7 |
| 09/10/11-popup-batiment | `410:7342` etc. | 2 s | 2 |
| mission-popup | `410:5664` | 2 s | 24 |
| shop-screen | `410:7061` | 1,5 s | 15 |
| splash, village-avec-dame, 02_Campagne | — | — | 0 — *aucun mouvement* |

**Les trois écrans de résultat ont TROIS entrées différentes**, et c'était la
trouvaille du relevé — le jeu n'en jouait qu'une, celle du nul, pour les trois :

| | Durée | Le titre | Stats | Boutons |
|---|---|---|---|---|
| **Victoire** | 2,507 s | échelle **0,3 → 1** + montée de **+60**, ressort qui dépasse à **1,36** | +40 à 1,0 s | +50 à 1,3 s |
| **Défaite** | 3,5 s | **tombe de −80**, échelle **1,15 → 1**, sans rebond | +30 à 1,6 s | +25 à 2,2 s |
| **Nulle** | 3 s | échelle **1,8 → 1**, `TRANS_BACK` au délai 0,3 — s'abat comme un tampon | +40 à 1,0 s | +30 à 1,3 s |

La victoire jaillit du bas en rebondissant, la défaite tombe d'en haut lentement
et sans rebond, le nul s'abat. `battle_result.ENTRY`, indexé par `_entry_key`,
porte les trois. La victoire porte en plus **12 confettis et 4 étincelles** qui
tombent en tournant, décalés de ~80 ms.

⚠️ **Les `Fondu au noir` de `village-sans-dame`, des deux château et de `287:308`
ne sont PAS des animations d'écran.** C'est un rectangle noir plein écran à
l'opacité 1 qui s'efface sur les 40-49 premiers % de la timeline — donc l'export
statique capture le voile, et rend noir. Ce sont des transitions **entre** écrans,
rien n'oblige à les porter. **La boucle est un artefact d'aperçu**, pas une
intention : ce qui compte, ce sont les décalages, les durées et les courbes.

**Trois pièges de portage, payés :**

1. **Ne jamais animer la `position` d'un enfant de conteneur.** Le tween se bat
   avec la mise en page — c'est ce qui avait collé le bandeau de série en haut de
   l'écran. `battle.gd` peut le faire parce que `Safe/Overlay` est un `Control`
   NU ; `battle_prep` ne le peut pas, et n'y reprend que les **opacités et les
   échelles**. Poser `pivot_offset` **après** la mise en page, jamais à la
   construction — à la construction `size` vaut encore zéro et tout grandirait
   depuis le coin supérieur gauche.
2. **⚠️ Attendre la mise en page avant de lire la moindre position.** Ces
   contrôles sont placés par ANCRES : tant que Godot n'a pas fait sa passe, leur
   `position` ne vaut rien. Mesuré sur `resolutions` : le bandeau de déploiement
   restait INVISIBLE hors de l'écran et le HUD de charge à demi sorti par la
   droite, **sur tous les formats**.
3. **`Modal.open()` est rappelé pour RECONSTRUIRE, pas pour rouvrir.** Le popup
   de missions le fait à chaque réclamation, celui de bâtiment à chaque
   recrutement, la boutique à chaque achat. Sans garde-fou, l'entrée se rejoue
   dans le dos du joueur au moment précis où il vient d'agir.

### Le codex décrivait un autre jeu — refait, pas porté

La forme de `codex-popup` est bonne : plaque de titre, puces de filtre par pièce,
une carte par pièce, un tableau par niveau, puis les bâtiments et les règles.
**Son contenu contredisait le jeu de bout en bout** :

| Le codex écrit | Le jeu |
|---|---|
| des colonnes **PV** et **ATK** par niveau | ni points de vie ni dégâts |
| « Charge inflige +50 % de dégâts », « Soigne de 10 PV/tour » | aucun soin, aucun dégât |
| « champ quadrillé de 8 cases sur 11 » | de 5×6 à 8×9 |
| « commandes de vitesse ×1, ×2, ×4 » | retirées : rien ne joue à la place du joueur |
| « défaite si votre Roi est vaincu » | il n'y a pas de Roi sur le plateau |
| huit bâtiments (Donjon de Fer, Cathédrale, Académie…) | cinq : le Château et quatre casernes |

Le porter tel quel aurait mis des règles fausses sous les yeux du joueur. **La
mise en page a été gardée, les données refaites** — et **le codex en jeu ne
transcrit rien : il se REGÉNÈRE depuis `Balance` à chaque ouverture** (mobilité
par niveau, capacité de caserne, coût de recrutement et son pas, prix
d'amélioration, poids de déploiement, tailles de plateau lues sur `CAMPAIGN`,
longueur des séries lue sur `fights`). Une transcription se décale dès que le jeu
bouge — c'est exactement ce qui avait produit le codex faux. `ui_test` vérifie
qu'aucun mot de l'ancienne version (`PV`, `ATK`, `Roque`, `Cathédrale`…) n'y est
revenu.

Trois pièges payés en le portant :

1. **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` sur tout libellé.** Les quatre
   colonnes du tableau se partageaient donc la largeur à parts égales — **67
   unités chacune** — et la mobilité, seule colonne à en avoir besoin, se repliait
   sur quatre lignes pendant que « 8 » occupait 67 unités. Toute colonne à largeur
   fixe doit repasser explicitement en `SIZE_FILL`.
2. **Le codex ne tient pas dans une modale.** `Modal` ne défile pas ; le codex
   fait **5 549 points** (4 537 dans la maquette d'origine). C'est un écran plein
   avec `ScrollContainer`, d'où `Router.goto_codex()`.
3. **Les six puces de filtre ne tiennent pas dans 361 points** (404 dans la
   maquette, ROI compris). La rangée défile horizontalement, et le rembourrage
   des puces est passé de **14 à 10** côté maquette.

### Quatre pièges d'import, déjà payés

1. **Les halos de la maquette sont des ellipses floutées** (`feGaussianBlur`), et
   Godot n'applique pas les filtres SVG : importés tels quels, ils ne s'allument
   pas. Les reproduire en `GradientTexture2D` radial avec un `CanvasItemMaterial`
   en `BLEND_MODE_ADD` — c'est ce que rend `UiTheme.additive_material()`.
2. **Un PNG exporté depuis Figma n'est pas détouré** : `download_assets` rend le
   nœud *avec le fond de la frame derrière lui*. Redécouper l'alpha après coup
   (cf. `assets/campaign/`), ou ne prendre en image que ce qui porte un filtre SVG
   et redessiner le reste au trait.
3. **Un label ne peut pas être rempli d'un dégradé** sans un shader par glyphe.
   `UiTheme.gold_label()` garde l'or médian à plat, avec l'ombre portée — à 9-19
   points la différence ne se voit pas.
4. **Les polices viennent de la maquette, et le relevé se refait.** Celui qui
   concluait « tout le fichier est en Inter, il n'y a rien à faire » portait sur
   les **anciennes pages**. Relevé refait sur les ~600 nœuds de texte de
   `MAINPROJECT` :

   | Police | Occurrences | Où | Décision |
   |---|---|---|---|
   | Inter, 6 graisses | 589 | partout | embarquée |
   | **Poppins Bold 16 / SemiBold 14** | 14 | les cinq noms de bâtiments du village, Château Royal, Missions, Codex | **embarquée** — 151 + 150 = **302 Ko**, l'ordre de grandeur de Lora (212 Ko pour deux usages) |
   | Comic Relief | 1 | la voix du Roi | embarquée |
   | ~~Jua Regular 13~~ | 2 | `07-bataille-nulle` | **abandonnée** |

   `UiTheme.font_display()` rend Poppins Bold, `font_display_medium()` la
   SemiBold. **Jaro** tenait ce rôle et ne sert plus : le fichier reste dans le
   dépôt, sans référence.

   ✅ **Jua est tranchée : abandonnée, c'est la MAQUETTE qu'on corrige.** Décision
   du joueur le 23/08/2026 — **2,1 Mo pour deux mots de 13 points** sur le seul
   écran de match nul, le tiers du poids de toutes les autres polices réunies.
   C'était le seul endroit où « les polices de Figma, point final » se heurtait à
   une mesure, et la mesure a gagné. Aucun code n'a changé : Jua n'était ni
   embarquée ni référencée.
