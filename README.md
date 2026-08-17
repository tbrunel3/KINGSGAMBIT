# King's Gambit — MVP Phase 1

Jeu de stratégie mobile fantasy inspiré des échecs. Le Roi a perdu sa Dame ; il
reconstruit son armée et enchaîne les batailles pour la retrouver.

Cette Phase 1 est un **MVP jouable** : la boucle complète tourne de bout en bout.
Les visuels sont des placeholders assumés — formes simples, lettres, couleurs —
et seront remplacés en Phase 2 à partir des maquettes Figma.

**Moteur : Godot 4.7** (testé sur 4.7.1 stable), GDScript, rendu `gl_compatibility`.
**Cible : iPhone portrait**, interface calée sur 393 × 852 points, safe areas gérées.

---

## Lancer le projet

Le projet est à la racine du dépôt. Ouvre Godot 4, `Importer`, puis sélectionne
le fichier `project.godot`. Appuie sur **F5** pour jouer.

En ligne de commande :

```bash
godot --path . 
```

Le banc de test (données, sauvegarde, 10 batailles simulées, chargement des
écrans) tourne sans interface :

```bash
godot --headless --path . tools/smoke_test.tscn
```

Les captures d'écran de `tools/screenshots/` se régénèrent avec :

```bash
godot --path . tools/screenshot.tscn
```

---

## Où régler le jeu

**Tout l'équilibrage est dans un seul fichier : [`scripts/data/balance.gd`](scripts/data/balance.gd).**

Aucune valeur de gameplay n'est écrite ailleurs. Ce fichier contient :

| Section | Contenu |
|---|---|
| `UNITS` | PV, dégâts, portée, type de mouvement, coût de recrutement, capacité, coût et durée d'amélioration — **par niveau** |
| `CASTLE_DATA` | Nombre d'unités déployables par niveau de château, coûts et durées |
| `CAMPAIGN` | Les 10 batailles : taille de grille, composition ennemie, niveau ennemi, récompense |
| `COMBAT` | Durées d'animation, seuil d'enlisement, garde-fou d'activations |
| `STARTING_GOLD`, `STARTING_UNITS`, `DEPLOY_ROWS` | Conditions de départ |

Ajouter un niveau à une unité = ajouter une entrée dans `levels`, `capacity`,
`upgrade_cost` et `upgrade_seconds`. Ajouter une bataille = ajouter une ligne à
`CAMPAIGN`. Rien d'autre à toucher.

L'habillage (couleurs, arrondis, marges) est isolé dans
[`scripts/ui/ui_theme.gd`](scripts/ui/ui_theme.gd) — le seul fichier à remplacer
pour brancher la direction artistique définitive.

---

## Architecture

Principe directeur : **la logique de jeu ne connaît pas l'affichage**. Tous les
fichiers de `scripts/battle/` sont des objets purs, sans aucun nœud Godot. Ils
sont donc simulables en headless — c'est ce qui permet de jouer les 10 batailles
en une seconde dans le banc de test.

```
project.godot            portrait, stretch canvas_items, 4 autoloads

scripts/
  data/balance.gd        [autoload Balance]     toutes les valeurs de réglage
  core/save_manager.gd   [autoload SaveManager] lecture/écriture JSON dans user://
  core/game_state.gd     [autoload Game]        or, unités, niveaux, progression
  core/router.gd         [autoload Router]      changement de scène + contexte

  battle/battle_unit.gd     une pièce en combat (données pures)
  battle/grid_model.gd      occupation du plateau, zones de déploiement
  battle/movement_rules.gd  déplacements par type de pièce (fonctions pures)
  battle/battle_ai.gd       décision d'une activation
  battle/battle_engine.gd   boucle tour par tour, émet des événements
  battle/grid_view.gd       rendu de la grille et des unités, entrées tactiles

  ui/ui_theme.gd         palette et styles (placeholder)
  ui/safe_area.gd        marges d'encoche iPhone

scenes/
  village/village.tscn        village, or, bâtiments, bouton bataille
  village/building_popup.tscn recrutement et amélioration
  battle/battle_prep.tscn     briefing avant combat
  battle/battle.tscn          placement, combat et résultat (une seule scène)

tools/
  smoke_test.tscn        banc de test headless
  screenshot.tscn        génération des captures
```

### Le point important : moteur et vitesse

`BattleEngine.step()` résout **une activation complète** et retourne la liste des
événements correspondants (`move`, `attack`, `death`, `end`). La vue les rejoue
ensuite avec des délais.

Conséquence : **x1, x2, x4 et Pause ne modifient jamais le résultat d'un combat.**
Ils ne touchent que les durées d'affichage. Une bataille est entièrement
déterminée par le placement.

### Trois choix à connaître

- **Une seule scène de bataille**, à trois phases (placement → combat → résultat).
  L'état du placement n'a ainsi jamais à transiter entre deux scènes.
- **Les données d'équilibrage sont des dictionnaires GDScript**, pas des
  ressources `.tres` : éditables dans n'importe quel éditeur de texte, lisibles
  en diff Git, modifiables sans ouvrir Godot.
- **Les améliorations sont stockées comme un timestamp Unix de fin.** Le temps
  passe donc normalement jeu fermé : au retour, on compare l'heure courante à
  l'heure de fin enregistrée.

---

## Règles de jeu implémentées

Les pièces rappellent les échecs sans en respecter les règles. La portée croît
avec le niveau du bâtiment correspondant.

| Pièce | Déplacement | Portée Nv.1 → Nv.3 |
|---|---|---|
| **Tour** | lignes et colonnes, bloquée par les unités | 2 → 3 → 4 |
| **Fou** | diagonales, bloqué par les unités | 2 → 3 → 4 |
| **Pion** | tout droit, plus un pas latéral ou arrière | 1 → 2 → 2 |
| **Cavalier** | sauts en L, ignore les unités du trajet | (1,2) → +(1,3) → +(2,3) |

L'attaque utilise la **distance de Tchebychev** (le plus grand écart en colonne
ou en rangée), sans ligne de vue, pour toutes les pièces. Simplification assumée
du MVP : une seule règle à retenir.

L'IA, identique pour les deux camps, applique dans l'ordre : attaquer une cible
à portée, sinon se déplacer pour attaquer, sinon se rapprocher de l'ennemi le
plus proche, sinon tenir sa position. À cibles égales elle achève l'unité la
plus faible. Pour la rendre plus maligne, seules `_score_target` et le choix de
case dans `battle_ai.gd` sont à modifier.

Un combat se termine quand un camp n'a plus d'unité vivante. Si les deux armées
ne peuvent plus s'atteindre (24 activations sans le moindre dégât), la victoire
va au camp qui conserve le plus de points de vie.

---

## Équilibrage vérifié

Le banc de test simule un joueur suivant la progression normale : batailles 1-3
au niveau 1, 4-7 au niveau 2, 8-10 au niveau 3. Les 10 batailles sont
franchissables, plusieurs se jouent à 2 ou 3 survivants.

```
Bataille  1  L Oree du Bois        Nv.1   6 vs  3  ->  VICTOIRE (5 survivants)
Bataille  3  La Route du Sel       Nv.1   6 vs  6  ->  VICTOIRE (1 survivant)
Bataille  7  Les Marches Grises    Nv.2  10 vs 10  ->  VICTOIRE (2 survivants)
Bataille 10  La Tour de la Dame    Nv.3  14 vs 14  ->  VICTOIRE (3 survivants)
```

---

## Fait en Phase 1

- Projet Godot 4 lançable, portrait iPhone, safe areas
- Village : château, 4 bâtiments cliquables, compteur d'or, bouton bataille
- Économie : or unique, recrutement au coût croissant, capacité par bâtiment
- Améliorations avec durée réelle, **timer qui continue jeu fermé**
- Campagne de 10 batailles, déblocage progressif après victoire
- Écran de préparation : composition ennemie, récompense, armée disponible
- Grille de taille variable par bataille (6×8 à 9×12), zones de déploiement
- Placement : sélection d'un type puis clic sur case, retrait, Auto,
  Réinitialiser, Combattre, limite d'unités liée au niveau du château
- Combat automatique tour par tour, alternance des camps
- 4 types de déplacement distincts, portées liées au niveau
- IA modulaire avec ordre de priorité explicite
- Contrôles x1 / x2 / x4 / Pause sans effet sur les règles
- Victoire/défaite, or crédité, bataille suivante débloquée, rejouer, retour village
- Sauvegarde JSON locale + bouton de remise à zéro pour les tests
- Banc de test headless et générateur de captures

## Reste à faire — Phase 2 (visuelle)

- Remplacer les placeholders par les assets Figma : sprites d'unités, décor du
  village, fond de plateau, icônes de bâtiments
- Drag & drop au placement (le clic-puis-case reste en secours)
- Animations d'attaque et de mort dignes de ce nom, effets de dégâts chiffrés
- Sons et retours haptiques
- Écran de sélection de bataille (carte de campagne) plutôt qu'un bouton unique
- Mise en scène narrative du Roi et de la Dame
- Export web (GitHub Pages) puis export iOS

### Limites connues du MVP

- La pause ne s'applique qu'entre deux activations, pas au milieu d'une animation.
- Le Roi n'est pas une unité jouable : le château est décoratif et fixe le
  nombre d'unités déployables.
- Aucune migration de sauvegarde : changer `SAVE_VERSION` repart de zéro.
- L'IA ne se protège pas et n'anticipe pas le tour adverse.
