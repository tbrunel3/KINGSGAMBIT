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
| codex-popup | 194:4 | à créer |
| 12-composants | 2:1224 | planche de référence |

**Deux écrans existent dans le jeu sans avoir jamais été dessinés**, et
finiront par avoir besoin de toi :

- **L'écran de match nul.** On l'a fabriqué en reprenant l'écran de victoire
  repeint en acier, sans confettis ni grand lettrage. Ça tient, mais ce n'est
  pas dessiné.
- **La boutique**, quand ses règles seront écrites.

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

**4. Le langage visuel est établi : la plaque royale.** Rectangle arrondi,
dégradé bleu nuit (`#1e3278` → `#0a1230` → `#0e1a40`), cerclé d'un trait d'or
épais `#ffe680`, doublé à l'intérieur d'un filet d'or fin. Elle sert déjà de
brique à la préparation, à la victoire et à la défaite. Les nouveaux écrans en
descendent, ils n'inventent pas un troisième langage.

**5. Contraintes de rendu.** Portrait uniquement, référence 393 × 852 points,
safe areas iPhone respectées. Godot 4 en `gl_compatibility` : PNG avec alpha,
pas de flou lourd, pas de particules complexes.
