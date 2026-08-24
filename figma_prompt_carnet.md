# BNL Project — le brief Figma du carnet de travaux

**À coller dans Figma Design.** Le texte du prompt commence à
[« Le prompt »](#le-prompt) ; ce qui précède est le contexte dont le designer a
besoin et que le prompt ne répète pas.

---

## Ce qu'est le carnet, et pourquoi il mérite une maquette

Le carnet est **l'outil de travail entre le joueur et moi**. Il n'est pas dans
le jeu : c'est la page où il dit ce qui va, ce qui casse, et dans quel ordre je
dois travailler. Il vit à
`https://claude.ai/code/artifact/857ffdc3-e16a-485b-8651-853b31916069`, sa
source est dans `carnet/`, et il a été construit d'un trait pendant une nuit —
donc **son ergonomie est celle d'un outil qui a poussé, pas d'un outil dessiné**.

C'est ça qu'on va corriger.

### Qui s'en sert, et dans quelles conditions

Une seule personne. **La nuit, sur un téléphone, en portrait, entre deux tests
du jeu.** Elle vient d'ouvrir la version en ligne, elle a vu quelque chose, et
elle a trente secondes avant de repartir jouer. Elle n'a pas de souris, pas de
survol, et une main.

### Les trois questions, dans cet ordre

La page répond à trois questions, et **l'ordre n'est pas un goût, c'est une
décision** :

1. **Où en est la journée ?** — une jauge, un pourcentage, des compteurs.
2. **Qu'est-ce qui attend MA validation ?** — c'est la seule chose que la page
   lui demande, tout le reste lui rend compte. *Il doit pouvoir trancher sans
   descendre.*
3. **Qu'est-ce que Claude fait maintenant ?** — l'ordre de marche.

Le reste — les fiches, les réglages, l'ajout d'une tâche — vient après.

### La boucle de travail, qui explique les états

- une fiche **à faire / rouverte / en cours** entre dans l'ordre de marche ;
- une fiche **à vérifier** en SORT : elle est livrée, elle attend le joueur, et
  la reprendre serait refaire un travail que personne n'a jugé ;
- quand il ne reste plus rien à faire, la page dit **EN ATTENTE DE TOI** au
  lieu de proposer un chantier ;
- une fiche **validée** se replie.

---

## Le prompt

> Tu dessines **BNL Project**, l'écran unique d'un carnet de suivi de
> développement. Un seul utilisateur, sur téléphone en portrait, la nuit, trente
> secondes à la fois. **Studio BNL** est le studio : son logo (`LOGO_STUDIOBNL`,
> nœud `116:573` du fichier `rqEdH4O2R21TuUFv7OUlF7`) se place en tête, discret,
> jamais en héros géant.
>
> ### L'ordre de l'écran, de haut en bas — à ne pas changer
>
> 1. **Identité** — logo Studio BNL + « BNL Project », sur une ligne. Puis les
>    **onglets de journée** (une journée de travail = un onglet), défilables
>    horizontalement, chacun avec son compteur d'ouverts, plus un onglet
>    « + Nouvelle journée ».
> 2. **L'aperçu** — le pourcentage d'avancement en gros, une **jauge globale**,
>    et des compteurs par état (en cours / à vérifier / cassé / à faire /
>    validé). C'est la première chose qu'on lit.
> 3. **« N chantiers attendent ta validation »** — le bloc le plus important de
>    la page. Une carte par chantier, et **chaque carte se tranche sur place** :
>    - la référence et le titre,
>    - un **résumé d'une ou deux lignes** : ce qu'il faut regarder,
>    - **la date et l'heure de la livraison + le hash du commit**, pour dire
>      depuis quand et sur quelle version ça attend,
>    - un champ de note court,
>    - deux boutons : **« Ça marche »** (vert) et **« Toujours cassé »** (rouge),
>    - un lien discret « Voir la fiche ».
> 4. **AU TRAVAIL** — soit un grand bouton or « AU TRAVAIL ! — N chantiers dans
>    l'ordre », soit, une fois lancé, la liste numérotée de l'ordre de marche
>    avec l'heure du lancement. À côté, un bouton secondaire **« 🧹 Nettoyer le
>    code »**. Et quand il n'y a plus rien à prendre, un état de repos
>    **EN ATTENTE DE TOI** / **JOURNÉE FINIE**.
> 5. **Le bandeau de build** — deux états, et ils doivent être impossibles à
>    confondre : **vert vif « COMMIT ET TEST POSSIBLE — en ligne depuis … »**, ou
>    **ambre « Pas encore en ligne — ne teste pas tout de suite »**. Ce bandeau
>    a été demandé après que le joueur a testé une version qui ne contenait pas
>    le travail : il doit crier.
> 6. **Les réglages** — trois rangées de puces : classer (par priorité / à la
>    main), grouper (par état / par section / par thème), filtrer par thème.
> 7. **Les fiches**, groupées par état, avec leur en-tête de groupe.
>
> ### Les composants à livrer, avec leurs états
>
> - **Onglet de journée** : actif / inactif / « + nouvelle ».
> - **Jauge** : deux tailles (globale, et fine sous chaque fiche), de 0 à 100.
> - **Carte d'attente de validation** (le composant le plus soigné de la page).
> - **Fiche** : cinq états — *à faire*, *en cours*, *à vérifier*, *toujours
>   cassé*, *validé*. La validée est **repliée** : une ligne, plus rien d'autre
>   qu'un bouton « Ça s'est remis à casser ».
> - **Pastille de priorité** : haute / moyenne / basse.
> - **Puce de thème**, cliquable, qui sert de filtre.
> - **Bouton primaire** (AU TRAVAIL), **secondaire** (nettoyage), **verdict
>   vert**, **verdict rouge**, **bouton discret**.
> - **Formulaire d'ajout de tâche** replié / déplié : titre, détail, section,
>   thème, priorité, état.
>
> ### Les contraintes, qui ne se négocient pas
>
> - **Une seule colonne**, 780 points de large au maximum sur grand écran, et
>   qui tient à **393 points** en portrait sans rien couper.
> - **Toute cible tactile fait au moins 44 points de haut.** Pas de survol :
>   ce qui n'est pas visible n'existe pas.
> - **Palette nuit et or**, celle du jeu — fond `#0b0e18`, plaque `#141a2b`,
>   filet `#2f3d5c`, texte `#e6ecf5`, atténué `#8fa0b8`, or `#ffd11a` et
>   `#ffe580`, bleu `#268cd9`, danger `#c65f5f`, succès `#5fb37a`.
> - **Poppins** (600/700) pour les titres, **Inter** pour le corps, chiffres en
>   `tabular-nums` partout où ils s'alignent.
> - **Aucune image externe, aucune icône propriétaire** : la page se rend sans
>   réseau. Emoji ou SVG simple uniquement.
> - Contraste lisible **la nuit, luminosité basse**.
>
> ### Ce qu'il ne faut surtout pas faire
>
> - Cacher une action derrière un menu ou un survol.
> - Mettre la validation en bas de page. C'est le geste principal.
> - Un carrousel, un accordéon pour l'essentiel, une modale pour trancher.
> - Des cartes toutes égales : la page doit hiérarchiser à l'œil nu ce qui
>   attend le joueur et ce qui l'informe.
> - Un héros plein écran : cette page est un poste de travail, pas une page
>   d'accueil.
>
> ### Le mouvement, si tu en mets
>
> Trois moments, et pas un de plus : la **jauge qui se remplit** à l'ouverture,
> la **carte validée qui se replie** dans le groupe *Validé*, et le **bandeau
> vert** qui s'allume quand un build passe en ligne. Rien d'autre ne bouge.
>
> ### Livrables
>
> - une frame **mobile 393 × hauteur libre**, l'écran complet ;
> - une frame **desktop 1280**, la même hiérarchie en plus large ;
> - une planche de **composants** avec tous les états listés plus haut ;
> - les **cinq états de fiche** côte à côte.

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
