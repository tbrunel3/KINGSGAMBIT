# King's Gambit — où en est le jeu

**Ce document est une référence, pas une demande.** Garde-le sous la main : il
dit ce qu'est devenu le jeu, ce qui en est sorti, ce qui y entre. Les demandes
d'écrans arrivent séparément, dans leurs propres briefs, et s'adossent à
celui-ci.

Il remplace le premier brief du projet, qui décrivait un jeu qui n'existe plus
et a été supprimé pour qu'on ne le relise pas par erreur.

---

## Le jeu, aujourd'hui, en un paragraphe

King's Gambit est un jeu de stratégie mobile fantasy inspiré des échecs. Le
Roi a perdu sa Dame ; il reconstruit son armée et enchaîne des batailles pour
la retrouver. Avant chaque combat, le joueur **place son armée** face à une
formation ennemie qu'il voit ; puis il **joue lui-même chaque coup**, une
pièce par camp et par tour, jusqu'à ce qu'un camp n'ait plus rien debout.
Entre deux batailles il rentre au village, recrute, améliore ses bâtiments.
Un pion mené au bout du plateau et **ramené vivant** devient une Dame et
rejoint le Château Royal — le trône vide du début de l'histoire.

Ton : fantasy médiéval, mélancolique mais pas sombre — un royaume diminué qui
se reconstruit, pas une guerre horrifique. Aucune violence graphique : la
capture d'une pièce est une convention d'échecs, pas une mise à mort.

---

## Ce qui a changé depuis le premier brief

| Le premier brief disait | Le jeu fait aujourd'hui | Pourquoi |
|---|---|---|
| Le combat se résout tout seul, on le regarde | **Le joueur joue chaque coup au doigt** | C'est devenu le cœur du jeu. Tout le reste en découle. |
| Une bataille = un combat | À partir de la 4ᵉ, **une série de 2 puis 3 combats** sans retour au village | L'ennemi revient au complet, le joueur avec ses survivants : c'est l'usure qui fait la difficulté |
| Victoire ou défaite | **Trois issues** — la victoire, la défaite, et le **match nul** | À égalité stricte de matériel, personne n'a gagné |
| Résultats en modale sur le plateau assombri | **Écrans pleins** | Décidé à la V2, déjà en place |
| La Dame vit dans une « Tour de la Dame » | **Elle vit au Château Royal**, aux côtés du Roi | C'est de là que vient toute l'histoire |
| Carte de campagne tenant dans un écran | **Parchemin défilant de 2300 points** | Déjà en place |
| Rien ne guide le joueur | **11 missions qui se déverrouillent en chaîne** | Elles remplacent un tutoriel |
| « Déploiement : 12/15 unités » | **« Charge : 7/16 »** — un budget de poids | Pion 1, Cavalier 3, Fou 3, Tour 5, Dame 5 |
| Plateau de 8 × 11 cases | **De 5 × 6 à 8 × 9** | Une case doit rester touchable au pouce : 45 à 72 points de côté |

---

## Ce qui sort du jeu, en ce moment

Tout ce qui jouait à la place du joueur disparaît. C'est une décision de fond,
pas un nettoyage :

- **Le bouton AUTO** du combat, qui confiait les deux camps à l'ordinateur
- **Les vitesses ×1 / ×2 / ×4** — on n'accélère pas une partie qu'on joue
  soi-même
- **PAUSE et FIN DE TOUR** — le combat attend déjà le joueur entre deux coups
- **Le bouton AUTO du placement**, qui rangeait l'armée à la place du joueur.
  Il est remplacé par **DERNIÈRE FORMATION**, qui repose la formation que le
  *joueur* avait choisie la fois d'avant. Ce n'est pas l'ordinateur qui
  décide : c'est sa propre décision, mémorisée.

Ces retraits ont fait l'objet du brief `figma_prompt_bataille.md`, **auquel tu
as déjà répondu** : les deux frames de bataille sont révisées et intégrées au
jeu. Sur la question posée — bandeau fin ou pas de bandeau — c'est **B** qui a
été retenu : l'état du tour est remonté dans le badge (« TOUR 5 · À TOI DE
JOUER ») et le bandeau du bas a disparu de l'écran de combat.

---

## Ce qui entre dans le jeu — annoncé, pas encore spécifié

### Une boutique

Le jeu devient un jeu **au long cours** : il lui faut une raison de revenir
demain. Ce qui est décidé à ce stade :

- Un **bouton boutique** en bas à droite du village. **Petit, discret, et
  provisoire** — on le fabrique nous-mêmes dans le style existant, tu n'as
  rien à dessiner pour lui. Un vrai visuel de magasin cliquable viendra plus
  tard.
- Dans la boutique, des **coffres à ouvrir gratuitement**, de valeurs
  différentes, à **une heure** et à **trois heures** d'intervalle.
- Des **gemmes**, une seconde monnaie, achetables, et dépensables pour
  **accélérer les améliorations de bâtiment** (qui prennent aujourd'hui de 30
  secondes à 4 heures de temps réel).

**Ne dessine pas encore cet écran, et c'est important.** Les règles ne sont
pas fixées : on ne sait pas encore ce que contient un coffre, ce que coûte une
accélération, ni comment les deux monnaies se répondent. Une maquette faite
maintenant **inventerait ces règles**, et on se retrouverait à discuter du
gameplay avec une image plutôt qu'avec des chiffres. La boutique aura son
brief dédié une fois l'économie mesurée.

### Des niveaux de bâtiment qui donnent du choix, pas de la portée

Aujourd'hui, monter une caserne allonge surtout la portée de sa pièce. La
direction prise est différente : les niveaux doivent donner à une pièce **un
choix de cases d'atterrissage de plus en plus fin** — le traitement que reçoit
déjà le Cavalier, dont chaque palier ouvre de nouvelles figures de saut.

Aucun impact visuel immédiat, sauf peut-être sur la façon dont les popups de
bâtiment montrent « ce que gagne la pièce au niveau suivant ». Signalé pour
que tu ne sois pas surpris.

---

## Le vocabulaire du jeu

Les libellés de la maquette et ceux du jeu divergent sur plusieurs points.
**C'est le jeu qui a raison** — merci d'aligner les futurs écrans dessus.

| La maquette dit | Le jeu dit |
|---|---|
| Atelier | **Caserne des Pions** |
| Académie | **Écuries** |
| Chapelle | **Cloître des Fous** |
| Cathédrale | **Donjon des Tours** |
| Forge (verrouillée) | *n'existe pas* |
| Tour de la Dame | **Château Royal** — la Dame n'a pas de bâtiment à elle |
| « 12/15 unités » | **« Charge : 7/16 »** |
| 9 batailles + « Bientôt disponible » | **10 batailles.** Le médaillon du sommet **est** la bataille 10, La Tour de la Dame — et le libellé disparaît |

---

## Les écrans, et où on en est

| Écran | node-id | État |
|---|---|---|
| splash-screen | 123:7 | en jeu |
| king-intro-before-dialogue | 169:136 | en jeu |
| king-intro-dialogue | 123:32 | en jeu |
| village-avec-dame / sans-dame | 162:4 / 188:2 | en jeu |
| chateau-royal-avec-dame / sans-dame | 178:5 / 178:51 | en jeu |
| 02_Campagne | 58:90 | en jeu |
| preparation-bataille-v2 | 169:4 | en jeu |
| 06_Bataille_Victoire | 2:546 | en jeu |
| 07-bataille-defaite | 2:835 | en jeu |
| 04_Bataille_Placement | 49:2 | en jeu — révision livrée |
| 05_Bataille_Combat | 2:407 | en jeu — révision livrée |
| mission-popup | 228:9 | à intégrer |
| 09 / 10 / 11 — popups de bâtiment | 2:1048 / 2:1115 / 2:1165 | à intégrer |
| confirm-upgrade-modal | 103:15 | à créer |
| codex-popup-v3 | 321:2 | **en jeu** — la v1 (194:4) est conservée intacte à côté |
| preparation-bataille-10-v3 | 330:2 | **en jeu** — la préparation, plus le bandeau de la Dame captive |
| 12-composants | 2:1224 | planche de référence |

### Deux demandes ouvertes

- **La carte de campagne illustrée** (`209:423`). Elle est plus belle que le
  parchemin en jeu et on la prendrait volontiers, mais les numéros d'étape sont
  **peints dans le raster** : ce n'est pas un calque qu'on masque. Le jeu trace
  ses propres cachets par-dessus, et ce sont eux qui disent verrouillé /
  disponible / gagné. Il nous faudrait la même carte **régénérée sans les
  pastilles numérotées** — et couvrant les dix étapes, celle-ci s'arrête à la 6ᵉ.
- **La Dame captive est maintenant en jeu** : elle est le bandeau d'enjeu de la
  préparation de la bataille 10, « La Tour de la Dame » — la seule bataille qui
  accorde une Dame. Voir `preparation-bataille-10-v3` (`330:2`). Le PNG détouré
  du dépôt a été reversé dans la maquette : l'image d'origine du fichier arrive
  avec un fond opaque.

**Deux écrans existent dans le jeu sans avoir jamais été dessinés**, et
finiront par avoir besoin de toi :

- **L'écran de match nul.** On l'a fabriqué en reprenant l'écran de victoire
  repeint en acier, sans confettis ni grand lettrage. Ça tient, mais ce n'est
  pas dessiné.
- **La boutique**, quand ses règles seront écrites.

---

## Le codex : la forme était bonne, le contenu décrivait un autre jeu

> **✅ RÉGLÉ.** Le brief qui te manquait existe :
> [`figma_prompt_codex.md`](figma_prompt_codex.md), avec tous les chiffres du
> jeu. La frame **`codex-popup-v3`** (node-id `321:2`) a été posée à côté de la
> tienne — **ton `codex-popup` d'origine n'a pas été touché** — et l'écran est
> en jeu. Ce qui suit reste écrit pour mémoire, parce que c'est le genre
> d'erreur qui revient sans un brief.

`codex-popup` est la plus grande frame du fichier et sa mise en page est juste
— plaque de titre, puces de filtre, une carte par pièce, un tableau par niveau,
puis les bâtiments et les règles. **Mais rien de ce qu'elle écrivait n'était
vrai du jeu** :

| Le codex écrit | Le jeu |
|---|---|
| des colonnes **PV** et **ATK** par niveau | **ni points de vie ni dégâts** — une pièce est debout, ou capturée |
| « Charge inflige +50 % de dégâts », « Soigne les alliés adjacents de 10 PV/tour » | aucun soin, aucun dégât, aucune statistique de combat |
| « champ quadrillé de 8 cases sur 11 » | de 5×6 à 8×9, pour qu'une case reste touchable |
| « commandes de vitesse ×1, ×2, ×4 » | retirées — rien ne joue à la place du joueur |
| « défaite si votre Roi est vaincu » | il n'y a **pas de Roi** sur le plateau |
| Donjon de Fer, Cathédrale, Académie militaire, Chapelle de soins | cinq bâtiments : le Château Royal et quatre casernes |

Ce n'est pas une critique du dessin : c'est le brief qui t'a manqué. **La mise
en page a été gardée telle quelle**, seules les données ont changé.

Ce qui a bougé dans la v3, et pourquoi :

- **La carte du ROI a disparu**, ainsi que sa puce de filtre. Il n'y a pas de
  Roi sur le plateau — il est le narrateur du jeu, pas une pièce.
- **Le tableau passe de `NIVEAU / PV / ATK / BONUS` à
  `NIV. / MOBILITÉ / CASERNE / PRIX`**, et de 3 lignes à **10** : le codex est
  le seul écran qui montre la courbe entière plutôt que le palier suivant.
- **« Attaque » devient « Capture »** : il n'y a pas d'attaque séparée, on
  capture en se déplaçant sur la case adverse.
- **Chaque carte gagne une puce POIDS** (1 / 3 / 3 / 5 / 5) : c'est ce que la
  pièce coûte dans le budget de placement, celui que l'écran de préparation
  affiche déjà en « Charge : 27/28 ».
- **Les huit bâtiments deviennent cinq**, avec leur palier de déverrouillage.
- **Les cinq règles deviennent six**, réécrites, et l'anneau rouge y entre —
  c'est la mécanique de tension du jeu et elle n'était nulle part.

Trois réglages d'adaptabilité, et ce sont des défauts mécaniques, pas des choix
de goût :

- **La rangée de puces débordait** : 404 points de puces dans un conteneur de
  361. Rembourrage ramené de 14 à 10, et le ROI en moins.
- **La colonne `BONUS / INFO` faisait 100 points** pour du texte qui en demande
  le double. Les quatre colonnes ont été redistribuées au profit de la
  mobilité, et les colonnes chiffrées alignées à droite.
- **La frame est passée en Inter.** Elle était en **Geist**, que le jeu
  n'embarque pas : il n'a qu'Inter, Comic Relief et Jaro. La maquette montrait
  donc une typo qui ne pouvait pas être livrée.

---

## Les règles permanentes de la collaboration

**1. La maquette apporte l'apparence, jamais les règles.** Couleurs, typo,
illustrations, mise en page, hiérarchie, composants : ça vient de toi. Ce
qu'on peut faire dans le jeu, quand, et avec quel effet : ça vient du code. Si
un écran te semble avoir besoin d'un bouton que le gameplay n'a pas, on ne
l'ajoutera pas. Si un libellé annonce une règle différente de celle du jeu,
c'est le libellé qu'on corrige.

**2. Ancrer, ne pas positionner.** Un écran posé en coordonnées absolues
calées sur 852 points se décale dès que l'appareil fait 880. Découpe chaque
écran en zones ancrées — barre haute de hauteur fixe, contenu central qui
prend la place restante, bandeau bas de hauteur fixe. Dessine dans un cadre
utile de **361 × 824** (393 × 852 moins les marges de zone sûre), ou donne les
positions en pourcentages.

**3. Quatre pièges d'import, rencontrés pour de vrai :**

- Un **PNG exporté depuis Figma n'est pas détouré** : le nœud arrive avec le
  fond de la frame derrière lui. Livre sur fond transparent, ou dis-nous quoi
  redécouper.
- **Les filtres SVG ne sont pas appliqués** par Godot. Un halo en
  `feGaussianBlur` arrive éteint : les halos doivent être des dégradés radiaux,
  ou être cuits dans la texture.
- **Un label ne peut pas être rempli d'un dégradé** sans un shader par glyphe.
  Donne l'or médian à plat, avec son ombre portée — à 9-19 points, la
  différence ne se voit pas.
- **Pas de nouvelle police.** Inter (variable), Comic Relief pour la voix du
  Roi, Jaro pour les enseignes. Jua avait servi pour un seul mot et pesait
  2,1 Mo.

⚠️ **CORRECTION DEMANDÉE — `07-bataille-nulle`.** Les deux mots « ROYAUME » et
« CAMPAGNE » y sont en **Jua Regular 13**. Jua pèse **2,1 Mo** : le tiers du
poids de toutes les autres polices du jeu réunies, pour deux mots de 13 points
sur l'écran le plus rare. Décision du joueur le 23/08/2026 : **on ne l'embarque
pas**. Peux-tu les repasser en Inter, ou en Poppins qui est déjà dans le jeu ?

C'est le seul endroit où « tu utilises les polices de Figma, point final » s'est
heurté à une mesure — et partout ailleurs la consigne tient : Poppins a été
embarquée pour les enseignes du village sans discuter.

**4. Le langage visuel est établi : la plaque royale.** Rectangle arrondi,
dégradé bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un trait d'or
épais `#ffe680`, doublé à l'intérieur d'un filet d'or fin. Elle sert déjà de
brique à la préparation, à la victoire et à la défaite. Les nouveaux écrans en
descendent, ils n'inventent pas un troisième langage.

**5. Contraintes de rendu.** Portrait uniquement, référence 393 × 852 points,
safe areas iPhone respectées. Godot 4 en `gl_compatibility` : PNG avec alpha,
pas de flou lourd, pas de particules complexes.
