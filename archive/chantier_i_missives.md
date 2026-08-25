# Chantier I — les missives du Roi

**Le jeu ne dit jamais pourquoi.** Le joueur reçoit quatre pions, un cavalier et
300 or, et rien ne lui explique que c'est ce qui a survécu à l'enlèvement plutôt
qu'un cadeau de départ. Le Roi parle une fois, sur son trône, puis disparaît de
l'existence du joueur pour dix batailles.

Ce chantier lui donne une **voix qui revient** : quatre lettres scellées, posées
aux quatre moments où le jeu bascule.

> Demande du joueur : « l'ux qui explique à l'utilisateur en gros le sens du
> jeu, pourquoi il hérite des troupes au début, ce genre de chose qui donne
> l'impression que le roi l'accompagne ».

Lire [`CLAUDE.md`](CLAUDE.md) d'abord. Ce document ne le répète pas.

---

## Ce que ce chantier n'est PAS

**Il ne remplace pas `GuidePopup`, et ne le touche pas.** La séparation a été
tranchée par le joueur, et elle est la colonne vertébrale du chantier :

| | Porte | Se déclenche | Ton |
|---|---|---|---|
| **La missive** | le **pourquoi** — le sens, l'enjeu, l'héritage | à un jalon d'histoire, hors combat | le Roi, à la première personne |
| **`GuidePopup`** | le **comment** — le pat, la charge, l'aura, le temps réel | à l'instant où la règle mord, combat compris | le jeu, neutre |

⚠️ **Une lettre du Roi n'entre jamais en combat.** Une missive qui se déplie
pour expliquer le pat en fin de partie serait fausse de ton, et c'est exactement
le défaut que les quatre maquettes du chantier E portent déjà côté Figma (fond
de salle du château sous un popup de pat).

---

## Les décisions déjà prises par le joueur

À ne pas rouvrir sans lui.

| Question | Réponse |
|---|---|
| Le support | **Une enveloppe scellée qui se déplie en parchemin.** Idée du joueur, et meilleure que le narrateur en pied que j'avais proposé — voir « Pourquoi pas un Roi en pied » |
| Canal unique ou parallèle ? | **Deux voix séparées** (tableau ci-dessus) |
| Combien de lettres ? | **Quatre**, sur des jalons — ni une seule, ni une par bataille |
| Livraison | **Hybride** : la 1re s'impose, les trois autres attendent |
| Où se rangent-elles ? | **Au Château Royal**, pas au village |
| Le pipeline | **Code d'abord, Figma ensuite.** Les PNG entrent dans `assets/story/` ; la géométrie et le pli se font en jeu ; le designer retouche après, sur des frames dont les proportions sont déjà justes |
| La saturation des assets | **NON TRANCHÉ — à montrer en image.** Voir « Ce qui reste ouvert » |

### Pourquoi pas un Roi en pied

**Le Roi n'a pas de corps dans ce jeu.** Il n'est pas sur le plateau — le codex
d'origine le prétendait, et c'était son erreur la plus grosse. Il est sur son
trône à l'intro et plus jamais. Un narrateur en pied qui accompagne le joueur
écran par écran contredirait la fiction de départ : un royaume diminué dont le
Roi ne peut plus se déplacer.

La lettre dit exactement la bonne chose : **il n'est pas là, mais il te suit.**

Elle a en plus un avantage matériel : le vocabulaire visuel existe déjà. La
carte de campagne est un parchemin (`parchment_map.jpg`), ses étapes sont des
cachets (`campaign_seal.gd`). La missive n'introduit aucune matière neuve.

---

## Les deux assets, mesurés

Fournis par le joueur le 23/08/2026, générés hors Figma. **Mesurés avec PIL, pas
estimés à l'œil.**

### Le parchemin — 1086 × 1448, zone opaque 1040 × 1418

| | |
|---|---|
| Ratio de la zone opaque | **0,733** (proche de 3:4) |
| Plissure haute | **39,5 %** de la hauteur |
| Plissure basse | **65,4 %** |
| Marge latérale **à l'intérieur du filet d'or** | **8,5 %** de la largeur |
| Le texte ne peut pas commencer avant | **13,3 %** du haut (ornement à couronne) |

À pleine largeur utile (361 pt), il fait **361 × 492 pt** — il tient dans les
824 avec de la marge, y compris sur `court-360x620`.

⚠️ **Ne pas mesurer la marge latérale sur le premier pixel non doré.** Le
parchemin a un liseré crème AVANT le filet d'or : un scan naïf rend **3,1 %** au
lieu de 8,5 %, et le texte irait mordre l'ornement. Le relevé se fait sur le
**dernier** pixel doré du premier quart de la ligne.

### L'enveloppe — 1254 × 1254, zone opaque 1159 × 977

Format **paysage**, ratio 1,19. Le cachet de cire est centré à **53,5 % /
53,5 %** de la zone opaque, et il est large : cible au pouce sans discussion.

### L'alpha est propre

Les deux fichiers sont en RGBA, coins transparents, extrema 0–255. **Pas de
redécoupe à faire** — contrairement à `assets/campaign/` et à
`parchment_map.jpg`, qui ont tous deux coûté une correction. Le piège documenté
dans `CLAUDE.md` ne s'applique qu'aux exports Figma ; ces deux-là n'en viennent
pas.

---

## Ce que les mesures imposent à l'écriture

Les trois panneaux valent **194 / 128 / 170 pt**. Une fois retirés l'ornement du
haut (65 pt) et la marge du bas, les trois zones de texte utilisables font
**~129 / 128 / ~131 pt**. Elles sont égales à trois points près.

**Donc le texte ne coule pas.** S'il traverse les plissures, les ombres de pli
tombent en plein milieu des lignes. L'illustration impose **trois blocs** :

1. **l'adresse** — à qui il écrit, et d'où
2. **le corps** — ce qu'il a à dire
3. **la signature** — ce qu'il attend

Environ cinq lignes par bloc en Inter 14. **Aucun défilement** : c'est ce qui
retire à l'approche « modale » son seul inconvénient, et c'est pourquoi
l'écran plein reste quand même le bon choix (voir Architecture).

---

## Architecture

### Les fichiers

| Fichier | Rôle |
|---|---|
| `scenes/story/royal_letter.gd` + `.tscn` | l'écran plein : enveloppe, cachet, dépli, parchemin |
| `scripts/data/letters.gd` | **les quatre textes**, et eux seuls |
| `scenes/village/castle_screen.gd` | *modifié* — la pile de courrier |
| `scripts/core/game_state.gd` | *modifié* — l'état des lettres, et le compteur de défaites |
| `scripts/core/router.gd` | *modifié* — `goto_letter()` |
| `assets/story/letter_envelope.png`, `letter_parchment.png` | les deux PNG |

**Pourquoi les textes dans un fichier à part**, alors que le codex et les
`GuidePopup` gardent les leurs avec leur écran : ce sont les seuls textes du jeu
qui soient de la **prose**, et ce sont ceux que le joueur va relire et retoucher
le plus. Les lire ne doit pas demander de faire défiler du code de tween.
`royal_letter.gd` porterait sinon ~450 lignes d'animation plus 60 lignes de
lettres.

### L'écran plein, et pourquoi pas une `Modal`

`Modal` ne défile pas — piège payé sur le codex (5 549 points dans une boîte qui
n'en montre pas 800, d'où `Router.goto_codex()`). Ici le texte ne défile pas non
plus, donc l'argument tombe ; **ce qui tranche, c'est le dépli.** Une enveloppe
qui s'ouvre dans une boîte de 300 points de large ne se voit pas. L'écran plein
donne au geste la place qu'il lui faut, et `king_intro_dialogue` prouve que le
gabarit tient (bulle qui monte, frappe lettre par lettre, bouton qui se
débloque).

`Router.goto_letter(key, return_to)` : la lettre doit savoir d'où on vient — la
1re arrive depuis le village, les trois autres depuis le Château Royal.

### L'état, dans `GameState`

```
"letters": { "<clé>": {"received": true, "read": false} }
```

Lu avec `.get("letters", {})`, comme `has_seen_guide` : **une sauvegarde écrite
avant ce chantier n'a pas la clé et doit se charger sans broncher.** Même
doctrine que `has_seen_series_warning`.

Deux états et non un : `received` décide de la pastille, `read` décide de la
mise en gras dans la pile. Une lettre reçue et non lue est le seul cas où le
Château Royal réclame l'attention.

### Le déclenchement — un seul endroit

Une fonction unique, appelée à **l'entrée du village**, dérive les quatre
réceptions de l'état courant et n'en impose qu'une :

```
RoyalLetter.deliver_pending(parent)
```

Chaque condition se lit sur `GameState`. Aucun appel à disséminer dans
`battle_result`, `campaign_run` ou `castle_screen` : c'est ce qui garantit
qu'une lettre ne peut pas arriver au mauvais moment (par-dessus l'écran de
défaite, ou en pleine série).

---

## Les quatre missives

| Clé | Déclencheur, lu sur `GameState` | Ce qu'elle dit, et que rien d'autre ne dit | Livraison |
|---|---|---|---|
| `heritage` | `has_seen_intro()` vient d'être posé | **Pourquoi il ne donne que ça.** L'intro dit *« ramenez-la »* ; celle-ci dit *« avec ceci »* — ce qui a survécu, pas un choix | **s'impose** |
| `premiere_dame` | `units_owned(DAME)` passe de 0 à 1 | Un pion a traversé et porte la couronne. Le trône est moins vide sans qu'**elle** soit revenue. Présente le Château Royal | attend |
| `premiere_defaite` | `stats.defeats >= 1` — **compteur à créer** | Il ne reproche rien. Une armée se reconstruit, elle non. Empêche la première défaite d'être un mur | attend |
| `elle_est_la` | `unlocked_battle() >= 10` | Il sait où elle est. Précède l'écran qui montre déjà `dame_captive.png` dans son bandeau d'enjeu (`battle_prep._build_stake_band`) | attend |

### La règle d'écriture, non négociable

**Aucun chiffre en dur dans le texte.** « Quatre pions et un cavalier »
s'interpole depuis `Balance.STARTING_UNITS`, la bourse depuis
`Balance.STARTING_GOLD`. Une transcription se décale dès que le jeu bouge —
c'est exactement ce qui a produit le codex faux, et ce que `GuidePopup` a déjà
verrouillé.

### La lettre 1 ne doit pas répéter l'intro

`king_intro_dialogue.DIALOGUE_TEXT` dit déjà, mot pour mot :

> *« Ma Dame s'est fait enlever… Soulevez une armée et ramenez-la, et je vous
> couvrirai d'or. »*

Si la missive d'héritage redit ça, elle devient un écran à évacuer, et le
chantier a produit l'inverse de ce qu'on cherchait. Elle doit ouvrir sur ce que
l'intro ne dit pas : **l'état de ce qui reste.**

---

## Le compteur de défaites — la seule pièce manquante

`record_battle(victory, ...)` ne bump `battles_won` que sur victoire. **Il n'y a
aucun compteur de défaite dans le jeu.** Des quatre déclencheurs, c'est le seul
qui n'ait pas déjà sa donnée.

À ajouter dans `stats`, aux côtés de `battles_won` et `flawless_wins` — un total
de carrière qui ne retombe jamais, doctrine déjà écrite dans `game_state.gd`.
Il pourra resservir à une mission.

⚠️ **Vérifier qu'un NUL n'appelle pas `record_battle(false, …)`.** Le jeu a trois
issues sans vainqueur, et un nul n'est pas une défaite — au nul « la série n'est
pas rompue ». Si `battle.gd` passe `false` pour un nul, la lettre 3 arrive après
un match nul et son texte ment. Le pat est fréquent (6 des 19 parties du banc,
bataille 1 comprise) : ça arriverait tôt, et à presque tout le monde.

---

## Le dépli

Le pli est **déjà peint** dans l'illustration : deux plissures horizontales avec
leur ombre. Rien à simuler.

Le parchemin est découpé en trois `TextureRect`, chacun avec sa `region_rect`
sur les plissures mesurées (39,5 % et 65,4 %). Chaque tranche s'anime en
`scale:y` de 0 → 1, `pivot_offset` **en haut** de la tranche. Panneau 1 en
place, le 2 se déroule sous lui, puis le 3 sous le 2, en décalé. Les creux
peints deviennent les charnières.

Séquence complète : l'enveloppe se pose → le doigt touche le cachet → le sceau
se brise → le parchemin se déplie en trois temps → le texte s'écrit bloc par
bloc → le bouton de sortie se débloque.

Aucun shader. `gl_compatibility` tient.

### Trois pièges de portage, déjà payés ailleurs

1. **`pivot_offset` se pose APRÈS la mise en page**, jamais à la construction.
   C'est ce qui avait collé le bandeau de série en haut de l'écran.
2. **Ne jamais animer la `position` d'un enfant de conteneur.** Les trois
   tranches ne doivent donc pas vivre dans un `VBoxContainer` — elles se posent
   à la main, comme les blocs de `battle_result._slide_in`, qui peut le faire
   précisément parce qu'ils ne sont dans aucun conteneur.
3. **Un banc de capture photographie un écran à moitié apparu.** Si
   `screenshot.tscn` ou `resolutions.tscn` traversent cet écran, ils doivent
   sauter à la fin des tweens (`_finish_animations`), comme ils le font déjà.

---

## Le courrier, au Château Royal

Le village porte déjà Boutique, Codex, Missions, la pastille de gemmes, le
Château Royal, quatre casernes et BATAILLE. Une cinquième entrée de coin irait
contre le nettoyage que G+F vient de faire — l'incohérence des boutons de coin
avait été mesurée à **six tailles pour la même chose**.

**Le trône est l'endroit du Roi**, et `castle_screen.gd` est bien moins chargé.
La pile de courrier s'y range en section. La pastille « n non lues » se pose sur
l'entrée **Château Royal** du village, qui existe déjà : la découverte est
préservée sans nouveau bouton.

Coût : `castle_screen.gd` (434 lignes) prend une section, et il fait partie des
huit écrans convertis en zones ancrées. **`format_test` est à relancer.**

---

## Ce qui reste ouvert

1. **La saturation des assets.** Ils sont nettement plus vifs que la palette du
   jeu : bleu roi saturé et or brillant, là où la plaque royale descend en
   `#1e3278 → #0a1230` et où le ton est « mélancolique mais pas sombre ». Sur le
   village en nuit, la lettre va claquer. Le joueur a demandé à **trancher sur
   image** : deux captures côte à côte, tel quel et avec un `modulate` d'environ
   −12 % de luminosité et de saturation. À faire dès que l'écran tient debout,
   avant d'écrire les textes.

2. **La lettre 4 s'impose-t-elle ?** La règle hybride dit non. Mais c'est le
   climax de la campagne, et l'écran suivant montre la Dame captive. À reposer
   au joueur quand les trois premières seront jouables — la question ne se
   décide bien qu'en la jouant.

3. **Le libellé de la pastille.** « 1 » comme les gemmes, ou un sceau non brisé.
   Détail d'habillage, à voir avec le designer en même temps que les frames.

---

## Ce qu'il faudra mesurer

| Banc | Ce qu'il doit dire |
|---|---|
| `tools/format_test.tscn` | dérive nulle sur les huit formats, **le château compris** — c'est le seul banc de format qui rende des chiffres |
| `tools/ui_test.tscn` | la lettre 1 s'impose une fois et une seule ; les trois autres n'apparaissent qu'à leur jalon ; une sauvegarde sans la clé `letters` se charge |
| `tools/smoke_test.tscn` | **10/10 batailles gagnables** — le signal qu'aucune modale n'est venue bloquer un banc. `RoyalLetter` doit être aussi silencieux que `GuidePopup` en banc |
| `tools/screenshot.tscn` | l'écran de lettre se photographie déplié, pas à mi-animation |

---

## L'ordre de travail

1. Copier les deux PNG dans `assets/story/`, puis `--import` (Godot ne
   réimporte pas un asset posé en ligne de commande).
2. `royal_letter.gd` : l'enveloppe, le cachet, le dépli — **sans texte**, avec
   du faux latin. C'est la partie risquée, elle se voit tout de suite.
3. **Les deux captures de saturation**, et la décision du joueur.
4. `letters.gd` : les quatre textes, interpolés.
5. Le compteur de défaites, et la vérification du nul.
6. `deliver_pending` et le routage.
7. La pile de courrier au château.
8. Les bancs, dans l'ordre du tableau.

Les étapes 2 et 3 valent un commit à elles seules : si le crédit s'épuise, un
dépli qui marche et une décision de ton prise sont ce qui coûte le plus cher à
retrouver.
