# BNL Project — le brief Figma du carnet de travaux

**À coller dans Figma Design.** Le texte du prompt commence à
[« Le prompt »](#le-prompt) ; ce qui précède est le contexte dont le designer a
besoin et que le prompt ne répète pas.

⚠️ **Ce brief ne donne AUCUNE direction graphique** — c'est délibéré. Pas de
palette, pas de police, pas de mise en page imposée, pas de liste de choses à ne
pas faire. Il décrit ce que l'outil doit permettre, ce qu'il doit montrer, et
dans quelles conditions il est utilisé. **Le reste appartient au designer**, et
c'est exactement ce qu'on lui demande d'apporter.

---

## Ce qu'est le carnet, et pourquoi il mérite une maquette

Le carnet est **l'outil de travail entre le joueur et moi**. Il n'est pas dans
le jeu : c'est la page où il dit ce qui va, ce qui casse, et dans quel ordre je
dois travailler. Il vit à
`https://claude.ai/code/artifact/47c96d8b-a61a-4222-932d-04430c13692f`, sa
source est dans `carnet/`, et il a été construit d'un trait pendant une nuit —
donc **son ergonomie est celle d'un outil qui a poussé, pas d'un outil dessiné**.

C'est ça qu'on va corriger.

### Qui s'en sert, et dans quelles conditions

Une seule personne. **La nuit, sur un téléphone, en portrait, entre deux tests
du jeu.** Elle vient d'ouvrir la version en ligne, elle a vu quelque chose, et
elle a trente secondes avant de repartir jouer. Elle n'a pas de souris, pas de
survol, et une main.

### Les trois questions

La page répond à trois questions. **Leur importance relative est une décision,
pas un goût** — comment elle se traduit à l'écran est au designer :

1. **Où en est la journée ?**
2. **Qu'est-ce qui attend MA validation ?** — c'est la seule chose que la page
   lui demande ; tout le reste lui rend compte.
3. **Qu'est-ce que je lance maintenant ?**

### Les trois commandes, à égalité

**Ce sont elles la page.** Le joueur l'a dit mot pour mot : *« ajouter un
travail est la fonctionnalité principale, avec lancer le travail et nettoyage
code »*. Elles sont du même rang, et ça doit se comprendre sans les chercher :

- **ajouter un travail** — c'était un lien discret en bas de page, sous les
  filtres : c'est-à-dire là où on ne le voyait pas ;
- **lancer le travail** — on le **nomme**, et une option **groupe
  automatiquement** les chantiers qui correspondent au nom ;
- **nettoyer le code** — une passe de simplification après un gros chantier.

### La boucle de travail, qui explique les états

- une fiche **à faire / rouverte / en cours** entre dans l'ordre de marche ;
- une fiche **à vérifier** en SORT : elle est livrée, elle attend le joueur, et
  la reprendre serait refaire un travail que personne n'a jugé ;
- quand il ne reste plus rien à faire, la page dit qu'elle **attend le joueur**
  au lieu de proposer un chantier ;
- une fiche **validée** se replie.

---

## Le prompt

> Tu dessines **BNL Project**, l'écran unique d'un carnet de suivi de
> développement. **La direction graphique est la tienne** : ce brief ne dit que
> ce que la page doit permettre et montrer.
>
> **Studio BNL** est le studio ; son logo est le nœud `LOGO_STUDIOBNL`
> (`116:573`) du fichier `rqEdH4O2R21TuUFv7OUlF7`.
>
> ### Qui s'en sert
>
> Une seule personne, sur téléphone en portrait, la nuit, trente secondes à la
> fois — entre deux tests d'un jeu qu'elle développe. Pas de souris, pas de
> survol, une main. Elle ouvre la page pour savoir où en est le travail, dire ce
> qui marche, et lancer la suite.
>
> ### Ce que la page doit permettre
>
> - **Voir l'avancement** de la journée en cours, et celui de chaque chantier.
> - **Trancher** ce qui attend son verdict, **sans avoir à descendre** : pour
>   chaque chantier livré, il lui faut sous les yeux un résumé de ce qu'il doit
>   regarder, depuis quand et sur quelle version ça l'attend, de quoi écrire une
>   note, et deux réponses — *ça marche* / *toujours cassé*.
> - **Ajouter un travail** : ce qu'il veut voir corrigé, un détail facultatif,
>   où le ranger, son thème, sa priorité, son état.
> - **Lancer le travail** en le nommant, avec l'option de grouper
>   automatiquement les chantiers qui correspondent à ce nom. Une fois lancé, la
>   liste ordonnée s'affiche, avec le nom donné et l'heure.
> - **Demander un nettoyage du code**, l'annuler tant qu'il est en cours, et
>   voir qu'il est terminé — daté. *Il n'a pas à déclarer fini un travail qu'il
>   ne peut pas voir : c'est le carnet qui l'annonce.*
> - **Savoir si la version en ligne contient le travail dont on parle.** Deux
>   situations, et les confondre coûte un test pour rien : *testable maintenant*
>   ou *pas encore en ligne*. Ce signal existe parce que le joueur a déjà testé
>   une version qui ne contenait pas le travail.
> - **Passer d'une journée de travail à l'autre**, et en ouvrir une nouvelle.
> - **Ranger** : classer par priorité ou à la main, grouper par état, par
>   section ou par thème, filtrer par thème.
>
> ### Ce que la page contient
>
> - Une **journée de travail** porte un nom, un avancement, l'état de sa version
>   en ligne, un ordre de marche et des chantiers. Plusieurs journées coexistent.
> - Un **chantier** porte une référence courte, un titre, un détail, un thème,
>   une priorité (trois niveaux), un avancement, un état, un journal daté et
>   signé — par le joueur ou par moi — et, une fois livré, l'heure et
>   l'identifiant du commit.
> - Les **cinq états** d'un chantier : *à faire*, *en cours*, *à vérifier*,
>   *toujours cassé*, *validé*. Ils doivent se distinguer d'un coup d'œil, et un
>   chantier validé doit prendre le moins de place possible tout en restant
>   réouvrable.
>
> ### Les contraintes du support
>
> - **Portrait, 393 points de large**, sans rien couper ; la page doit aussi
>   tenir sur un écran large.
> - **Toute cible tactile est atteignable au pouce**, et **rien ne dépend d'un
>   survol** : ce qui n'est pas visible n'existe pas.
> - **Aucune ressource externe** : la page se rend sans réseau.
> - Elle est lue **la nuit, luminosité basse**.
>
> ### Livrables
>
> - une frame **mobile 393 × hauteur libre**, l'écran complet ;
> - une frame **large**, la même page pour un écran de bureau ;
> - une planche de **composants** avec leurs états ;
> - les **cinq états de chantier** côte à côte.

---

## Design ou Make ?

**Design.** Le carnet fonctionne déjà : sa valeur est dans sa mécanique — la
boucle de travail, le journal daté, l'export vers le dépôt, la republication
sous l'identité du joueur. Une maquette me donne l'apparence à porter dans
`carnet/page.html` sans toucher à rien de tout ça, et c'est exactement la règle
que le projet suit depuis le début : **Figma apporte l'apparence, jamais les
règles.**

**Make** produirait une application neuve, jolie et cliquable — mais avec sa
propre logique, son propre stockage, et rien de ce qui existe. Il faudrait soit
tout rebrancher à la main, soit jeter le carnet actuel. Il a sa place si un
jour on veut *repartir de zéro* sur cet outil ; pas pour l'habiller.

Le raccourci utile : générer **deux ou trois pistes dans Make pour voir des
mises en page**, puis dessiner la gagnante en Design et me la donner à porter.
