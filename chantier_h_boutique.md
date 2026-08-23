# Chantier H — la boutique

**Spec validée le 22/08/2026.** Elle existe parce que la boutique est le seul
écran du jeu dont la maquette est arrivée AVANT ses règles, et que le manuel
interdit précisément d'en déduire les secondes. Le graphiste a dessiné
`shop-screen` (`347:4`) ; ce document écrit ce qui tourne derrière.

Lis [`CLAUDE.md`](CLAUDE.md) d'abord — les cinq règles qui priment, la
discipline des bancs et les pièges d'import ne sont pas répétés ici.

---

## D'où ça vient, et pourquoi ce n'est pas ce qu'on avait annoncé

Notre propre note de hors-périmètre au graphiste (`294:2`) disait : « une
boutique arrive dans le jeu — **coffres à ouvrir toutes les heures et toutes
les trois heures**, gemmes, **accélération des améliorations**. »

Il a dessiné autre chose : des coffres **achetés** (Commun 50 · Rare 150 ·
Épique 400 · Légendaire 1 000, en gemmes), des **gemmes en euros** (0,99 /
4,99 / 19,99 €), et une section **OR** dont personne n'avait parlé (1 000 /
5 000 / 25 000 or contre 50 / 200 / 800 gemmes). Ni coffre gratuit à minuterie,
ni accélération.

Les deux moitiés se recollent : **ses coffres achetés portent notre
accélération**. C'est la clé de toute cette spec.

## Les six décisions prises

| Question | Réponse |
|---|---|
| Niveau d'ambition | boutique **réelle**, gemmes gagnées en jouant ; les euros attendent un store |
| Que donne un coffre ? | **du temps d'amélioration** — pas d'or, pas de pièces, pas de rareté neuve |
| D'où viennent les gemmes ? | **coffres gratuits à minuterie** (1 h et 3 h) |
| La section OR ? | **gardée, montants recalibrés** |
| La section € ? | **visible, boutons grisés « Bientôt »** |
| Ordre des chantiers | les **règles avant E**, la **peau dans G+F** |

L'ordre a été rediscuté et changé : la demande d'origine était « intégrer la
boutique à F ». La boutique **change le jeu**, or E existe pour l'expliquer au
joueur — livrer E avant elle produirait des popups à réécrire. Les règles
passent donc avant E ; seule la peau reste dans G+F, où l'écran est passé au
crible des formats en même temps que les six autres.

---

## Le principe : le robinet commande tout le reste

C'est le seul chiffre dont dépendent tous les autres : **combien de gemmes une
campagne produit**. Les prix dessinés (coffres 50 → 1 000, or 50 → 800) ne sont
sensés que si ce total est de l'ordre de **1 000 gemmes sur une campagne
entière**. En dessous, la boutique est une vitrine fermée ; au-dessus, le pack
d'or à 800 gemmes s'achète trois fois et l'économie mesurée se rouvre.

Valeurs posées : coffre horaire **4 gemmes**, coffre de 3 h **12 gemmes**.

⚠️ **Ces deux nombres valaient 8 et 25, et ont été divisés par deux après
mesure** — décision du joueur, prise sur le chiffre du point suivant. Diviser
le robinet a rendu deux articles **littéralement inachetables** (le Légendaire
à 1 000 et le plus gros pack d'or à 800 dépassaient les 768 gemmes d'une
campagne) : les deux sont descendus à **600** dans le même geste. Un article
qu'on ne peut jamais s'offrir n'est pas un objet de désir.

**Mesuré depuis** (`tools/shop_probe.tscn`, campagne de 12 jours) :

| Sessions par jour | 7 jours | 12 jours | 21 jours |
|---|---|---|---|
| 2 | 224 | 384 | 672 |
| 3 | 336 | 576 | 1 008 |
| 5 | 560 | **960** | 1 680 |

Campagne de référence (12 jours, 4 sessions) : **768 gemmes** — dans la
fourchette [500, 2000] que cette spec annonçait. Le Légendaire à 600 s'offre
donc **une fois par campagne**, ce qui est exactement le statut qu'on veut lui
donner.

*Une lecture contre-intuitive du tableau* : à 8 sessions par jour le rendement
ne monte plus (960, comme à 5 sessions). Des visites toutes les deux heures
tombent à contretemps de la piste de 3 h. Ce n'est pas un bug de la sonde,
c'est le comportement réel d'un plafond « un seul coffre en attente ».

⚠️ **Un seul coffre en attente par piste.** Sans ce plafond, partir une semaine
rend 168 coffres horaires et le robinet n'a plus de fond.

⚠️ **Les gemmes accélèrent les BÂTIMENTS, jamais les coffres gratuits.** Une
gemme qui raccourcit la minuterie d'un coffre qui rend des gemmes est une
machine à imprimer. C'est une règle, pas une omission : à écrire dans le code
et à vérifier dans `ui_test`.

---

## 1. Le modèle

Dans [`scripts/core/game_state.gd`](scripts/core/game_state.gd) :

- `gems` (propriété), `add_gems()`, `spend_gems()`, `can_afford_gems()`,
  signal `gems_changed(amount)` — calqués sur `gold` / `gold_changed`.
- `_state["free_chests"]` : `{ "horaire": <ts>, "trois_heures": <ts> }`, des
  timestamps Unix **de disponibilité**, exactement comme `_state["upgrades"]`.
  Ils tournent jeu fermé : c'est déjà la doctrine des améliorations.
- `claim_free_chest(id) -> int` : rend les gemmes et repose la minuterie ;
  rend `0` si le coffre n'est pas prêt.
- `accelerate_upgrade(type, seconds) -> bool` : retranche des secondes à
  `_state["upgrades"][type]`, puis `check_upgrades()`. `seconds < 0` termine
  **cette** amélioration. Le coffre Légendaire n'a pas de fonction à lui : il
  boucle sur les types en cours et appelle celle-ci avec `-1` sur chacun.

**Tout se lit avec `_state.get(..., 0)`** — une sauvegarde d'avant ce chantier
n'a ni gemmes ni coffres, et doit se charger sans broncher. Le projet a déjà
posé cette règle pour `has_seen_series_warning`.

Dans [`scripts/data/balance.gd`](scripts/data/balance.gd), un bloc `SHOP` neuf.
**Règle 1 du projet : aucune de ces valeurs ailleurs.**

```gdscript
const SHOP := {
    # Le robinet. Cle -> attente en secondes et gemmes rendues.
    "free_chests": {
        "horaire":      {"seconds":  3600, "gems":  4},
        "trois_heures": {"seconds": 10800, "gems": 12},
    },
    # Coffres achetes : des SECONDES d'amelioration, pas un tirage.
    "chests": [
        {"id": "commun",     "gems":   50, "seconds":   900},  # 15 min
        {"id": "rare",       "gems":  150, "seconds":  3600},  # 1 h
        {"id": "epique",     "gems":  400, "seconds": 10800},  # 3 h
        {"id": "legendaire", "gems":  600, "seconds":    -1},  # termine TOUT
    ],
    # Section OR : prix en gemmes du dessin, montants MESURES (cf. point 5).
    "gold_packs": [
        {"gems":  50, "gold":  150},   # 3,00 or/gemme
        {"gems": 200, "gold":  700},   # 3,50
        {"gems": 600, "gold": 3000},   # 5,00
    ],
    # Section GEMMES : dessinee, inerte tant qu'aucun store n'existe.
    "gem_packs": [
        {"gems":  100, "price": "0,99 €"},
        {"gems":  500, "price": "4,99 €"},
        {"gems": 2500, "price": "19,99 €"},
    ],
    "gem_packs_enabled": false,
}
```

## 2. Les coffres gratuits

Deux pistes, 1 h et 3 h. Un coffre prêt s'ouvre d'un doigt et rend ses gemmes ;
la minuterie repart **au moment de l'ouverture**, pas à l'échéance — sinon un
joueur absent trois jours accumulerait un retard qu'il rattraperait d'un coup.

**Ils ne sont dessinés nulle part.** La maquette ne montre que les quatre
coffres achetés. C'est le cas prévu par la règle 2 : *« si une frame montre un
écran sans le bouton dont le gameplay a besoin, on garde le bouton et on
l'habille »*. Ils vivent en haut de la section COFFRES, et leur état finira
dans le brief du point 9.

## 3. Les coffres achetés donnent du temps

Acheter un coffre Commun, Rare ou Épique ouvre le choix d'**une amélioration en
cours** ; les secondes sont retranchées de la sienne. **S'il n'y a aucune
amélioration en cours, les cartes sont désactivées avec la raison écrite** —
acheter du temps quand rien n'attend n'a pas de sens, et un inventaire de
« jetons de temps » serait un concept de plus pour rien.

**Le Légendaire termine TOUTES les améliorations en cours.** Ce n'est pas une
fantaisie, c'est de l'arithmétique : la plus longue amélioration du jeu dure
4 h (14 400 s), et l'Épique en donne déjà 10 800 pour 400 gemmes. Un Légendaire
qui ne finirait qu'une seule amélioration coûterait 1 000 gemmes pour 14 400 s
au mieux — **moins bien que deux Épiques**, donc strictement dominé, donc
jamais acheté. Cinq bâtiments peuvent monter en parallèle (un par type) : tout
terminer d'un coup est le seul contenu qui justifie son prix, et sa valeur
monte avec ce que le joueur a mis en chantier. C'est une décision, pas une
attente : bien joué, ce coffre vaut plusieurs heures.

**Pourquoi le temps et rien d'autre.** C'est le seul contenu qui ne touche
aucun chiffre mesuré — ni `upgrade_cost`, ni les récompenses, ni les 10/10 de
`smoke_test`. Et c'est la vraie friction du jeu : **47,5 heures d'attente
cumulées** pour tout monter au niveau 10, dont **11,1 h rien que pour le
Château Royal**, le bâtiment qui commande la charge de déploiement et qu'on
veut donc monter en premier.

Un coffre à pièces aurait plafonné sur la capacité des casernes et, pour le
Légendaire, offert une **Dame** — ce qui détruirait l'histoire du jeu : la
rareté de la Dame est un résultat mesuré (8 ramenées à 2), pas un accident.
Un coffre à or aurait rouvert le trou de la section OR, en pire.

## 4. Le panneau Légendaire : la maquette dit une règle, on corrige le libellé

`legendaire-featured` (`352:2`) est **entièrement** un tableau de
probabilités : Commun 45 %, Rare 30 %, Épique 18 %, Légendaire 7 %.

Deux raisons de ne pas le porter tel quel :

1. Avec des coffres qui donnent du temps fixe, ces pourcentages n'ont rien à
   décrire.
2. Un tirage aléatoire serait la **première source d'aléa du jeu**. Le manuel
   l'écrit : le combat n'en a aucune.

La mise en page se recycle sans y toucher — quatre lignes, libellé à gauche,
valeur à droite. Elles deviennent la **légende des quatre coffres** :
`Commun · 15 min`, `Rare · 1 h`, `Épique · 3 h`, `Légendaire · termine tout`.
Même panneau, même hiérarchie, même relief. C'est le traitement qu'a déjà reçu
le codex : on garde la peau, on refait les données.

## 5. La section OR

Prix en gemmes **inchangés** (50 / 200 / 800) ; montants d'or ramenés à
**150 / 700 / 3 000**.

⚠️ **Ces montants ont été corrigés deux fois, et la première correction était
fausse.** J'avais d'abord posé 500 / 2 200 / 6 000, en vérifiant qu'aucun pack
seul ne dépassait un cinquième de ce que verse la campagne. `shop_probe` a
montré que le garde-fou portait sur la mauvaise quantité : le budget **entier**
d'une campagne (~1 600 gemmes) achetait alors **15 500 or, soit 39 %** de la
campagne. Le trou se rouvrait par la somme, pas par le pack.

Second défaut de cette version : le petit pack rendait **10 or par gemme** et le
gros **7,5**. Un pack qui grossit doit devenir meilleur, sinon c'est un piège
pour qui ne fait pas la division. Les taux montent maintenant de 3,00 à 3,75.

Le pack dessiné à **25 000 or** vaut plus que le cumul d'améliorations que la
campagne demande à la bataille 10 (19 090). Ce n'était pas un déséquilibre,
c'était une offre de **sauter la campagne** — et comme le jeu est fini en dix
batailles, il n'y a aucun endgame où dépenser cet or ensuite.

**Mesure d'arrivée** (`shop_probe`) : budget entier converti au meilleur taux,
**3 450 or, soit 8,7 %** des 39 450 que verse une traversée simple. Un coup de
pouce, pas un raccourci — et le joueur qui le prend renonce à tout coffre.

Deux garde-fous, à deux endroits, parce qu'aucun des deux ne suffit :

| Où | Ce qu'il vérifie |
|---|---|
| `smoke_test` | qu'aucun pack seul ne dépasse un cinquième de la campagne, et que **le taux monte avec la taille du pack** |
| `shop_probe` | ce que le budget **entier** achète — le seul qui connaisse le robinet, et le seul qui ait vu le vrai défaut |

⚠️ **`economy_probe` reste l'arbitre final.** Il prend plusieurs heures : à
lancer en fond, et à lire sur ses **deux** chiffres — le nombre de replays *et*
l'or qui reste en poche avant la dernière récompense.

## 6. La section GEMMES

Godot n'a pas de facturation native, et le build web ne peut rien vendre. Les
trois cartes restent dessinées, **les boutons grisés portent « Bientôt »**, et
`SHOP.gem_packs_enabled` les rallumera le jour d'un export mobile signé. Aucun
code d'achat n'est écrit dans ce chantier.

## 7. L'écran et la navigation

- `scenes/village/shop.tscn` + `shop.gd`, **écran plein** avec
  `ScrollContainer` : la maquette fait **918 points de haut**, elle ne tient
  dans aucun téléphone. Même raison que le codex, même solution.
- `Router.goto_shop()`.
- Une icône au village, sur le modèle du codex et des missions
  (`village._make_clickable`). Le graphiste l'a explicitement laissée à notre
  charge : « le bouton qui y mènera est provisoire et fabriqué de notre côté ».
- Découpage **ancré** (règle 4) : barre haute de hauteur fixe — retour · plaque
  de titre · panneau des deux monnaies —, contenu défilant qui prend le reste,
  rien en bas.
- Le panneau de monnaies affiche **gemmes et or**. Le village devra montrer les
  gemmes lui aussi, sinon elles n'existent que dans la boutique.

Dans ce chantier, l'écran est **fonctionnel mais brut**. La peau fine et le
passage aux trois formats hors norme se font pendant G+F, avec les six autres
écrans — c'est ce qui évite de le repeindre deux fois.

## 8. Ce qui est renvoyé à G+F

La reprise graphique fine, l'ancrage définitif, et les captures comparatives
avec `347:4`. Rien du modèle.

## 9. Le brief à écrire pour le graphiste

Sur le modèle de [`figma_prompt_codex.md`](figma_prompt_codex.md), un
`figma_prompt_boutique.md` qui demande les quatre choses que la maquette n'a
pas et que le jeu exige :

1. les **coffres gratuits** (prêt / minuterie en cours) en haut de COFFRES ;
2. l'état **désactivé « Bientôt »** des trois cartes en euros ;
3. l'**icône boutique** au village, cohérente avec celles du codex et des
   missions ;
4. la correction du panneau Légendaire — pourcentages remplacés par la légende
   des quatre coffres.

Y rappeler pourquoi : la maquette apporte l'apparence, jamais les règles.

## 10. Ce qu'il faut prouver

| Banc | Ce qu'il doit dire |
|---|---|
| `smoke_test` | toujours **10/10** — c'est un contrôle, pas une mesure : la boutique ne touche pas au combat |
| `ui_test` | ouvrir la boutique · se faire refuser un achat sans gemmes · en réussir un · voir l'amélioration raccourcie · réclamer un coffre gratuit · se le voir refuser une seconde fois · vérifier qu'aucune gemme n'accélère une minuterie de coffre |
| **`shop_probe`** *(neuf)* | combien de gemmes une campagne produit — **le chiffre du point 1**, que rien d'existant ne mesure |
| `economy_probe` | **obligatoire** pour la section OR. Plusieurs heures |
| `resolutions` | l'écran défile-t-il sur `court-360x620` — la maquette fait 918 de haut |

## 11. Les pièges du projet qui s'appliquent ici

- **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` sur tout libellé.** Les quatre
  lignes de la légende du Légendaire sont des colonnes à largeur fixe : repasser
  explicitement en `SIZE_FILL`, sinon « 15 min » et « termine tout » se
  partagent la largeur à parts égales.
- **Un `PanelContainer` ignore les constantes `margin_*`** — sa marge vient des
  `content_margin` de sa `StyleBox`.
- **Un `Control` enfant d'un `ScrollContainer` ne s'étire pas.** Mesurer sur le
  `ScrollContainer`, jamais sur son contenu.
- **Un PNG exporté depuis Figma n'est pas détouré**, et emporte le fond de la
  frame — y compris en JPG. Les neuf illustrations de coffres, de sacs de
  gemmes et de piles d'or sont concernées.
- **Godot ne réimporte pas un asset remplacé** : `--headless --path . --import`
  après tout PNG écrasé.
- **Libérer un nœud pendant que son propre signal émet est refusé par Godot** —
  une carte de coffre qui déclenche la reconstruction qui la libère a besoin
  d'un `call_deferred`. Le chantier C l'a payé.

## 12. Ce qui n'est PAS décidé

- **Les trois montants d'or** du point 5 sont provisoires jusqu'à
  `economy_probe`.
- **Les 8 et 25 gemmes** du robinet : mesurés, dans la fourchette — mais voir
  ci-dessous.
- ✅ **La boutique efface 117 % de l'attente de la campagne, et c'était une
  décision, pas un calcul.** En confrontant les deux sondes : monter les cinq
  bâtiments au niveau que la campagne prête au joueur demande **4 h 55**
  d'attente réelle ; le budget de gemmes en achète **5 h 45**. La boutique
  couvre l'attente sans la pulvériser.

  Le premier réglage donnait **241 %** — les minuteries n'existaient plus pour
  qui ramassait ses coffres. Le joueur a tranché pour un robinet deux fois plus
  maigre. `shop_probe` pose désormais un plafond à **150 %** : au-dessus, il
  échoue.
- **Les achats en euros** : aucune plateforme, aucun plugin, aucun compte
  développeur n'est choisi. Hors de ce chantier.
- **Une accélération depuis le popup de bâtiment** (« terminer maintenant »)
  serait plus naturelle que depuis la boutique, mais demanderait un inventaire
  de coffres. Volontairement écartée pour garder un seul chemin.
