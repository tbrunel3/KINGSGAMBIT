# Passation — chantier J : les retours de test du 23-24/08

**Ce document existe parce que le travail change de session.** Une fenêtre neuve
repart à froid : elle aura [`CLAUDE.md`](CLAUDE.md), mais pas ce qui s'est dit
pendant les allers-retours avec le joueur.

Lire [`CLAUDE.md`](CLAUDE.md) en premier. Ce document ne le répète pas.

**Le carnet de suivi est un artefact web INTERACTIF**, et c'est LUI qui fait foi :
`https://claude.ai/code/artifact/47c96d8b-a61a-4222-932d-04430c13692f`. **Le joueur y coche lui-même** « Ça marche » ou « Toujours cassé », et y dépose
ses notes de bug. Chaque ligne porte un **journal daté**, signé *Claude* ou
*Toi*, pour qu'il puisse commenter derrière chaque modification. Les lignes
validées se replient.

⚠️ **Il se publie sous l'identité du joueur quand il clique.** Republier
dessus depuis une session peut donc rendre un `conflict` : dans ce cas
**relire l'artefact (`WebFetch` sur son URL), fusionner ses changements dans
les siens, et republier** — `force` seulement après avoir vraiment fusionné.
C'est arrivé une fois : il avait validé A1, rouvert A3 et signalé deux
nouveaux défauts pendant que je réécrivais la page.

Le modèle est **réutilisable** pour d'autres chantiers, et c'est voulu.

---

## D'où ça vient

Le joueur a testé le jeu sur son téléphone, via la version web publiée sur
`gh-pages`, et a envoyé **dix-huit retours d'un coup**, puis quatre autres en
cours de session. Ils ont été rangés en paquets pour qu'il puisse valider par
points de contrôle plutôt que tout d'un bloc.

**L'ordre a été fixé par lui : A → B → D → C → E → F.** Puis, en cours de route,
il a demandé à ce qu'on **pousse paquet par paquet** pour vérifier au fur et à
mesure.

---

## ⚠️ Ce qu'il faut savoir avant de reprendre

### 1. Le site en ligne peut mentir sur l'état du travail

`docs/` est **gitignoré**. Le build web se publie depuis la branche
**`gh-pages`**, qui ne contient que lui. La procédure :

```bash
godot --headless --path . --export-release "Web" docs/index.html
```

puis recopier `docs/index.*` à la racine de `gh-pages` et pousser. **Passer par
un `git worktree`, jamais par un `git checkout gh-pages`** : cette branche n'a
pas de `.gitignore`, donc un `git add -A` dessus embarquerait `docs/`,
`.godot/` et les captures.

**Le joueur a testé une carte non corrigée** parce que j'avais annoncé un
correctif sans ré-exporter. Un travail qui n'est pas dans le build n'existe pas
pour lui. Le carnet porte désormais un bandeau « en ligne depuis… » pour ça.

### 2. Deux défauts d'instrument, qui invalident des assertions

Trouvés en écrivant un test, et **ils expliquent pourquoi des bugs évidents
n'avaient jamais été vus** :

- **`ui_test._press()` n'appuie sur rien** pour les contrôles qui utilisent la
  méthode virtuelle `_gui_input()`. `gui_input` est un **signal** ; émettre le
  signal n'appelle pas la virtuelle. Seuls `corner_button` et `selection_chip`,
  qui font `gui_input.connect(...)`, répondent. `campaign_seal`, `grid_view` et
  `series_banner` ne répondaient pas. **Pour ceux-là, appeler
  `node._gui_input(event)` directement.**
- **`_press()` n'envoie qu'un appui, jamais de relâchement.** Un banc qui ne
  sait pas lever le doigt ne peut pas distinguer un appui d'un geste.

⚠️ **Conséquence non traitée :** d'autres assertions existantes de `ui_test`
passent peut-être à vide sur ces contrôles. Personne n'a fait l'audit.

### 3. Une correction annoncée trop vite

J'ai dit au joueur que le défilement de la carte était corrigé après avoir
trouvé **un** vrai bug (le cachet qui partait sur l'appui). Ce n'était pas la
cause du symptôme. La vraie cause était un cran au-dessus, sur un nœud que je
n'avais pas regardé.

**La leçon est dans la garde qui a été posée :** elle ne teste plus un nœud mais
**toute la chaîne** entre un cachet et le `ScrollContainer`, et elle **nomme le
maillon coupable**. Vérifiée en réintroduisant la régression.

---

## Ce qui est fait, et mesuré

### Le défilement de la carte — deux bugs, pas un

| | Cause | Mesure |
|---|---|---|
| Le cachet partait sur l'**appui** | `campaign_seal` émettait `pressed` sur `event.pressed`, et `campaign.gd` enchaînait `_play_transition()` | impossible d'annuler en glissant à côté |
| **Le geste n'atteignait jamais le `ScrollContainer`** | `Content` sans `mouse_filter` dans `campaign.tscn` → `STOP` par défaut | la carte ne défilait **nulle part** |

Le cachet décide maintenant au **relâchement**, à moins de `TAP_SLOP` (12 pt) du
départ, et passe en `MOUSE_FILTER_PASS`. `Content` passe en `IGNORE`.

### Le format : le piège n°1 pris par l'autre bout

Le joueur voyait une **ligne nette au bord droit du premier écran**, sur le web
seulement. Les deux vignettes de `king_intro_dialogue` étaient posées en absolu,
**larges de 393 en dur**.

**La largeur ne descend pas sous 393, ce qui fait croire que 393 est sûr. Elle
MONTE.** Dans un navigateur c'est la hauteur qui manque : viewport **478 × 852**
sur `web-393x700`, **495** de large sur `court-360x620`.

Mesuré en réintroduisant la régression : **85,34 pt** de bande nue sur le
premier cas, **101,71 pt** sur le second. Zéro après correction.

Le pivot de zoom du même écran avait le même défaut, à `(196.5, 426)`.

**`format_test` a un cas `[3] Intro`** qui instancie le vrai écran — le banc ne
couvrait que le village, et c'est ce qui a laissé passer le défaut.

### Le socle des transitions

- **`Balance.MOTION`** — vingt-deux durées vivaient dans huit fichiers d'écran.
  La règle 1 l'interdisait depuis le début. `MOTION.scale` est **le** bouton
  pour ralentir tout le jeu.
- **`ScreenVeil`** (`scripts/ui/screen_veil.gd`), autoload — **le seul calque
  qui survit à un changement de scène**. `Router._change` passe par lui, donc
  tous les écrans sont couverts d'un coup. Il prend une **couleur** : la carte
  s'ouvre sur un fondu au **blanc**.
- Le voile local du village a disparu. Le zoom zoome, la modale joue sa propre
  entrée — **une seule apparition** au lieu de deux fondus concurrents (0,22 s
  contre 0,45 s).
- Les écrans de résultat **naissent invisibles** : ils étaient construits à
  pleine opacité puis remis à zéro par l'animation différée, d'où le
  clignotement sur les trois issues.

### La règle du nul a changé

**Décision du joueur, 24/08.** Un nul **rejoue** le combat au lieu de le
consommer. Avant, un nul au dernier combat appelait `finish_run` et le bouton
« REPRENDRE LA SÉRIE » **rouvrait une série neuve au combat 1** — le libellé
promettait de reprendre, le code recommençait.

⚠️ **Le plafond est indispensable, et c'est le joueur qui l'a fixé à trois après
que je lui ai signalé le risque :** sans lui, on ne peut plus jamais perdre une
série par nul, et bloquer la position devient un abri. Le pat est fréquent ici —
6 des 19 parties du banc.

`CampaignRun.draws` compte, survit à la sauvegarde, et `replay()` fait ce
qu'`advance()` fait sans incrémenter le combat.

---

## Les décisions déjà prises par le joueur

À ne pas rouvrir sans lui.

| Question | Réponse |
|---|---|
| Ordre des paquets | **A → B → D → C → E → F** |
| A3 et A4 fusionnés dans B ? | **Oui** — ils ne se corrigeaient pas sans toucher aux transitions |
| Rythme des poussées | **Paquet par paquet**, pour vérifier au fur et à mesure |
| Le nul au dernier combat | **Se rejoue**, plafond de **3 nuls par série** |
| Les fonds de bâtiment | **Les chercher dans `MAINPROJECT`** moi-même |
| Les missions | **Pas un bug** — fermé après vérification |
| Le seuil de glissement du combat | **Ne pas y toucher sans relevé sur appareil** — 8 pt est le *touch slop* standard d'Android |

---

## Ce qui reste

Voir le carnet pour l'état à jour. En résumé :

- **C** — le glisser-déposer : caserne → déploiement, et inventaire → plateau.
  Le paquet le plus lourd.
- **D** — les animations manquantes : retour à l'appui sur **tous** les boutons
  (à poser dans les composants partagés, pas écran par écran), le codex, l'or
  qui monte au lieu de sauter. **D3 est à moitié fait** : le fondu au blanc est
  là, le dézoom d'élévation non.
- **E** — la barre du haut (or + gemmes), l'alignement Boutique/BATAILLE, les
  polices, et l'interface des missions jugée « très modeste ».
- **F** — les fonds par bâtiment, à récupérer dans Figma.
- **Les deux écrans de lettre du Roi**, faits par le graphiste, à placer **entre
  l'intro et le village**. Le reste du chantier est déjà spécifié dans
  [`chantier_i_missives.md`](chantier_i_missives.md) — mesures des
  illustrations, quatre textes, déclencheurs.

### Ce que le code seul ne peut pas trancher

**Le combat au doigt.** Le joueur le trouve mauvais ; je n'ai trouvé aucun
défaut prouvable en lisant :

- la logique de glissement est saine — la sélection se fait sur l'**appui**
  (`cell_pressed` → `_select_unit`), donc un appui tremblé sélectionne quand
  même ;
- le seuil est la valeur standard d'Android.

La seule faiblesse réelle et non mesurable ici : **aucun
`InputEventScreenTouch` dans tout le dépôt.** Tout repose sur l'émulation souris
de Godot, et **un second doigt produit un second appui émulé qui tue le
glissement en cours**.

**Il faut une observation sur appareil, ou un banc de geste dans le combat —
`[12]` ne couvre que la carte.**

---

## Les bancs à relancer

| Banc | Ce qu'il doit dire |
|---|---|
| `tools/format_test.tscn` | dérive nulle sur les huit formats, **intro comprise** (cas `[3]`) |
| `tools/ui_test.tscn` | tout passe, y compris `[12]` la carte au doigt et la nouvelle règle du nul |
| `tools/smoke_test.tscn` | **10/10 batailles gagnables** |

Godot n'est pas dans le `PATH` :

```bash
"$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . tools/ui_test.tscn
```

⚠️ **`--check-only --script` ne voit pas les autoloads** : il rend une erreur
« Identifier not found: Game » sur du code parfaitement valide. Ce n'est pas un
contrôle fiable pour un script qui touche `Game`, `Balance` ou `Router` —
lancer un banc à la place.


---

## Ce que la nuit du 24/08 a ajouté

### Trois règles de jeu ont changé, toutes décidées par le joueur

| Règle | Ce qu'elle dit | Le garde-fou |
|---|---|---|
| **Le nul rejoue le combat** | un nul ne consomme plus le combat : on le rejoue avec ses survivants | **plafond de 3 nuls** (`Balance.RUN_DRAWS_ALLOWED`) — sans lui on ne peut plus jamais perdre une série par nul, et le pat est fréquent (6 des 19 parties du banc) |
| **Le pion promu reste la série** | un promu non-Dame reste en ligne jusqu'au dernier combat, puis redevient pion | **un promu qui tombe coûte le PION qu'il était** — sans ça il supprimerait un vrai Cavalier de l'armée du joueur |
| **Quitter au royaume abandonne** | repartir au village en pleine série la perd | **un avertissement obligatoire** — perdre une série par mégarde serait pire que ce que la règle empêche |

⚠️ **La troisième ne bouche pas l'exploit que le joueur croyait.** Celui-là
n'existe pas : `roster` est un instantané pris à l'ouverture, et la
préparation est en lecture seule mi-série. Je le lui ai dit, il a maintenu la
règle — c'est une décision de jeu, pas un correctif. **La vraie fuite, elle,
n'est pas bouchée : `deploy_capacity()` est relue à chaud, donc améliorer le
Château en pleine série augmente la charge.**

Deux choix d'interprétation que je me suis permis, et qu'il peut corriger :
« partir au royaume » = **aller au village**, pas fermer le jeu ; et abandonner
applique les pertes et garde les Dames, mais ne verse ni or ni consolation.

### Le socle des transitions

- **`Balance.MOTION`** — les durées d'animation, enfin toutes au même endroit,
  avec un `scale` qui les ralentit toutes. La règle 1 le demandait depuis le
  début et n'était pas tenue : vingt-deux constantes dans huit fichiers.
- **`ScreenVeil`** — un autoload, donc **le seul calque qui survit à un
  changement de scène**. `Router._change` passe par lui, ce qui couvre tous les
  écrans d'un coup. Il prend une couleur (la carte s'ouvre au **blanc**), et
  `hold()` / `release()` laissent un écran dire « attends-moi » sans ralentir
  les autres.

### ⚠️ Le piège le plus cher de la session

**Nommer une classe d'interface dans un autoload empêche le JEU ENTIER de
démarrer.** Ajouter `ConfirmLeave.ask(...)` dans `Router.goto_village()` a
suffi : un autoload résout ses noms de classe à l'**analyse**, donc le
chargement des autoloads s'est mis à tirer `Modal`, `UiTheme` et leurs scènes.

**Le symptôme est trompeur** — ce n'est pas une erreur, c'est un blocage. Les
bancs n'affichaient plus leur première ligne, et la sortie ne montrait que du
bruit de fermeture. Chercher dans le test était une impasse. Correctif :
`load()` au moment de l'appel. Documenté dans `CLAUDE.md`.

### Ce que le joueur a validé, et ce qu'il a rouvert

**Validé :** la ligne de l'intro, le château, le rythme des transitions, le zoom
des bâtiments, le fondu au noir, le clignotement des écrans de résultat, et
**la carte qui suit le doigt** (mesuré : 100 points de doigt = 100 de carte).

**Rouvert, et c'est le prochain gros morceau :** *« ce n'est pas vraiment une
popup, c'est une transition vers un nouvel écran »*. Les écrans de bâtiment
sont dans Figma au node **`517-2`** — pas `420-7`, que j'avais noté à tort.
Zoom, fondu sortant, fondu entrant, **et un fond différent par bâtiment**.

### Ce qui reste, dans l'ordre convenu

1. **Les écrans de bâtiment** (`517-2`) — englobe A3 et F1.
2. **C** — le glisser-déposer : caserne → déploiement, inventaire → plateau,
   plus le bouton COMBATTEZ qui ne suit pas la maquette.
3. **D** — le retour à l'appui sur **tous** les boutons (dans les composants
   partagés, pas écran par écran), le codex, l'or qui monte.
4. **E** — la barre du haut (or + gemmes), l'alignement, les polices, l'UI des
   missions.
5. **Les deux écrans de lettre du Roi**, entre l'intro et le village.
6. **Les popups d'information** de Figma, jamais intégrés.
