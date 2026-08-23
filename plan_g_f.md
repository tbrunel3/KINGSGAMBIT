# Plan d'implémentation — chantier G + F

> **Pour l'agent qui exécute :** utiliser `superpowers:subagent-driven-development`
> (recommandé) ou `superpowers:executing-plans`, tâche par tâche. Les étapes
> sont en cases à cocher (`- [ ]`).

**But :** rendre chaque écran du jeu indifférent à la taille de l'appareil, et
lui donner la peau de la bibliothèque Figma — les deux dans le même passage,
parce que c'est le même geste sur le même fichier.

**Architecture :** le village passe de un calque à deux (`DecorLayer` ancré sur
le rectangle réellement affiché par l'illustration, `UiLayer` ancré sur
l'écran). La géométrie de ce rectangle sort dans une fonction **pure et
statique**, ce qui la rend mesurable sans fenêtre ni rendu — c'est ce qui donne
à F un banc numérique en plus de ses captures. Les dix boutons de coin se
ramènent à un composant unique à deux tailles. Les animations de modale se
posent une seule fois dans `Modal`, qui a six appelants.

**Pile :** Godot 4.7, GDScript, `gl_compatibility`, portrait. Aucune dépendance
externe.

**Spec :** [`chantier_g_f.md`](chantier_g_f.md) — à lire avec ce plan.
**Manuel :** [`CLAUDE.md`](CLAUDE.md) — les quatre règles priment sur tout.
**Inventaire et pièges :** [`passation_g_f.md`](passation_g_f.md).

---

## Contraintes globales

Elles s'appliquent implicitement à **toutes** les tâches.

- **Aucune valeur de gameplay hors de `scripts/data/balance.gd`.** Ce chantier
  est graphique : il ne doit ajouter **aucune** constante de gameplay ailleurs.
  Les tailles de boutons, durées d'animation et géométries d'écran ne sont pas
  du gameplay et restent dans leurs fichiers d'UI.
- **Figma apporte l'apparence, jamais les règles.** Si une frame montre un écran
  sans un bouton dont le gameplay a besoin, on garde le bouton et on l'habille.
- **Rien ne joue à la place du joueur.** Aucune tâche n'introduit de résolution
  automatique ni de vitesse accélérée.
- **Ancrer, ne pas positionner.** Cadre utile : **361 × 824** (393 × 852 moins
  les marges de zone sûre).
- **`window/stretch/aspect` reste à `expand`.** Décision du 23/08. Ne pas la
  rouvrir.
- **La largeur en unités de jeu ne descend jamais sous 393** — c'est la
  **hauteur** qui varie, et sur un écran court c'est la **largeur qui monte**
  (fenêtre 393 × 700 → viewport **478 × 852**).
- **Ne jamais animer la `position` d'un enfant de conteneur.** Opacité et
  échelle seulement. *Exception* : un enfant de `Control` **nu**.
- **Aucune lecture de `position` ni pose de `pivot_offset` avant**
  `await get_tree().process_frame`.
- **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` et `AUTOWRAP_WORD_SMART` sur
  tout libellé.** Toute largeur fixe doit repasser en `SIZE_FILL` et couper
  l'autowrap.
- **Un PNG exporté depuis Figma n'est pas détouré.** Prendre l'image **source**
  (`download_assets` > `rawImages`), jamais l'`export`.
- **Godot ne réimporte pas un asset remplacé** : `--import` après tout PNG/TTF
  écrasé.
- **Commits fréquents**, un par tâche, message en français, sans accents dans le
  sujet (convention du dépôt).

### Lancer Godot

Godot est installé par winget et n'est **pas** dans le `PATH`. Poser l'alias une
fois par session :

```bash
GODOT="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
```

⚠️ `screenshot.tscn` et `resolutions.tscn` écrivent des PNG : **les lancer sans
`--headless`**, sinon ils bloquent. Tous les autres bancs se lancent avec.

---

## Structure des fichiers

| Fichier | Créé / Modifié | Responsabilité |
|---|---|---|
| `scripts/ui/cover_fit.gd` | **créé** | La géométrie du `KEEP_ASPECT_COVERED`, en fonctions pures et statiques. Aucune dépendance à la scène |
| `tools/format_test.gd` + `.tscn` | **créés** | Le banc **numérique** du format : il mesure des coordonnées, là où `resolutions.tscn` produit des images qu'un humain doit regarder |
| `scenes/village/village.gd` | modifié | Deux calques ; la conversion Figma → écran sort en fonctions **statiques**, donc testables sans instancier l'écran |
| `scenes/village/village.tscn` | modifié | `Overlay` → `DecorLayer` + `UiLayer` |
| `scenes/ui/components/corner_button.gd` | **créé** | Le bouton de coin unique, deux tailles, quatre variantes |
| `scenes/ui/components/modal.gd` | modifié | Le gabarit d'entrée de modale, pour ses six appelants |
| `tools/resolutions.gd` | modifié | Quatre écrans de plus dans `SCREENS` |
| `scenes/village/shop.gd` | modifié | Entrée animée, puis la peau |
| `scenes/village/mission_popup.gd` | modifié | Les **deux** animations, séparées |
| `scenes/battle/battle.gd` | modifié | Le lettrage « COMBATTEZ » ; `_corner_button_style()` déménage |
| `scenes/village/building_popup.gd` | modifié | Le cerclage d'or de l'état verrouillé |
| `scenes/village/castle_screen.gd` | modifié | Son bouton retour passe au composant |

---

## Tâche 1 : compléter le relevé des animations

**Fichiers :**
- Modifier : `chantier_g_f.md` (le tableau d'inventaire), `passation_g_f.md`
  (§2)

**Interfaces :**
- Produit : un inventaire d'animations **complet**, dont dépendent les tâches
  7, 8, 9 et 10 pour savoir ce qu'elles doivent porter.

⚠️ **Un relevé d'animations a déjà été faux DEUX fois.** La première par
mauvaise page (les timelines vivent sur les copies), la seconde par
péremption. **Un relevé périme dès que le designer touche au fichier.**

⚠️ `get_motion_context` **refuse une page entière** (« nothing selected »).
Il faut l'appeler **section par section**.

- [ ] **Étape 1 : relever les quatre sections jamais interrogées**

Appeler `get_motion_context` sur le fichier `rqEdH4O2R21TuUFv7OUlF7`, une
section à la fois, en `recursive` :

| Section | node-id | Ce qu'elle contient |
|---|---|---|
| 🎬 Intro | `420:2` | splash, king-intro ×2 — **à reconfirmer**, les deux connues datent |
| 🏘️ Navigation | `420:3` | village ×2, château royal ×2 |
| 🗺️ Campagne | `420:4` | 02_Campagne |
| 🏆 Résultats | `420:6` | victoire, défaite, nulle |

- [ ] **Étape 2 : reconfirmer les six timelines déjà connues**

Sur les sections `420:5` Combat, `420:7` Popups et `420:8` Codex & Shop. Noter
toute durée ou tout compte de nœuds qui aurait bougé depuis le relevé de la
passation.

- [ ] **Étape 3 : réécrire le tableau d'inventaire dans `chantier_g_f.md`**

Une ligne par frame : node-id, durée, nombre de nœuds, état (porté / à porter),
et **la section d'où vient le relevé**. Si une section rend « aucune donnée de
mouvement », l'écrire explicitement — c'est une information, pas un trou.

⚠️ **Écrire le tableau tel qu'il est mesuré, pas tel qu'on l'attendait.** Si le
relevé contredit la passation, c'est la passation qui est périmée.

- [ ] **Étape 4 : marquer §2 de `passation_g_f.md` comme relevé complet**

Remplacer l'avertissement « QUATRE SECTIONS N'ONT PAS ÉTÉ RELEVÉES » par un
renvoi vers le tableau à jour de `chantier_g_f.md`.

- [ ] **Étape 5 : commit**

```bash
git add chantier_g_f.md passation_g_f.md
git commit -m "L'inventaire des animations, complet pour la premiere fois"
```

---

## Tâche 2 : `CoverFit` — la géométrie du fond, en fonction pure

**Fichiers :**
- Créer : `scripts/ui/cover_fit.gd`
- Créer : `tools/format_test.gd`, `tools/format_test.tscn`

**Interfaces :**
- Produit :
  - `CoverFit.rect(viewport: Vector2, texture: Vector2) -> Rect2`
  - `CoverFit.scale(viewport: Vector2, texture: Vector2) -> float`
  - `CoverFit.to_texture(point: Vector2, viewport: Vector2, texture: Vector2) -> Vector2`
  - `CoverFit.from_texture(point: Vector2, viewport: Vector2, texture: Vector2) -> Vector2`
- Consommé par : tâche 4 (le village), tâche 3 (le banc).

**Pourquoi une fonction pure.** `resolutions.tscn` produit des images qu'un
humain doit regarder ; une image ne casse pas un banc quand elle régresse. En
sortant la géométrie du rendu, elle devient mesurable **sans fenêtre, sans
rendu, en headless** — et F gagne un test qui échoue tout seul.

- [ ] **Étape 1 : écrire le banc et son test, qui échoue**

Créer `tools/format_test.gd` :

```gdscript
extends Node
##
## BANC DE FORMAT - la geometrie des ecrans, en chiffres.
##
## resolutions.tscn rend des IMAGES : il faut un humain pour les regarder, et
## une image ne casse pas un banc quand elle regresse. Celui-ci mesure des
## COORDONNEES, et il echoue tout seul.
##
## Lancement :
##   godot --headless --path . tools/format_test.tscn
##

const CoverFit := preload("res://scripts/ui/cover_fit.gd")

## Les huit formats de resolutions.tscn, convertis en VIEWPORT (unites de jeu).
##
## ⚠️ Ce ne sont pas les tailles de fenetre. En "canvas_items / expand", Godot
## choisit l'echelle sur le plus contraint des deux axes puis AGRANDIT le
## viewport : une fenetre de 393x700 donne un viewport de 478x852, plus LARGE
## que la reference. C'est le piege n1 de CLAUDE.md, et c'est pourquoi la
## largeur ne descend jamais sous 393.
const VIEWPORTS := [
	{"name": "base-393x852",      "size": Vector2(393, 852)},
	{"name": "android-360x800",   "size": Vector2(393, 873)},
	{"name": "iphone-375x812",    "size": Vector2(393, 851)},
	{"name": "pixel-412x915",     "size": Vector2(393, 873)},
	{"name": "iphone-430x932",    "size": Vector2(393, 852)},
	# --- hors format : c'est ici que ca casse ---
	{"name": "web-393x700",       "size": Vector2(478, 852)},
	{"name": "court-360x620",     "size": Vector2(495, 852)},
	{"name": "tres-long-430x1080","size": Vector2(393, 987)},
]

var _failures: int = 0


func _ready() -> void:
	print("=== KING'S GAMBIT - banc de format ===")
	_test_cover_fit()

	print("")
	if _failures == 0:
		print("RESULTAT : la geometrie tient sur les huit formats.")
	else:
		print("RESULTAT : %d probleme(s) de format." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  OK   %s" % label)
	else:
		_failures += 1
		print("  ECHEC %s" % label)


func _near(a: float, b: float, tolerance: float = 0.5) -> bool:
	return absf(a - b) <= tolerance


# ---------------------------- LA GEOMETRIE DU FOND ---------------------------

func _test_cover_fit() -> void:
	print("\n[1] CoverFit : le rectangle reellement affiche par un fond")

	var texture := Vector2(864, 1821)

	# A la reference, le fond est plus ETROIT en rapport que l'ecran (0,4745
	# contre 0,4613) : c'est donc la HAUTEUR qui commande, et l'image deborde
	# de 11 points en largeur.
	var base := CoverFit.rect(Vector2(393, 852), texture)
	_check(_near(base.size.x, 404.24), "base : largeur affichee 404,24 (%.2f)" % base.size.x)
	_check(_near(base.size.y, 852.0), "base : hauteur affichee 852 (%.2f)" % base.size.y)
	_check(_near(base.position.x, -5.62), "base : deborde de 5,62 a gauche (%.2f)" % base.position.x)
	_check(_near(base.position.y, 0.0), "base : cale en haut (%.2f)" % base.position.y)

	# Sur un ecran COURT, le viewport s'elargit : c'est la LARGEUR qui commande,
	# et l'image deborde en hauteur.
	var court := CoverFit.rect(Vector2(478, 852), texture)
	_check(_near(court.size.x, 478.0), "court : largeur affichee 478 (%.2f)" % court.size.x)
	_check(_near(court.size.y, 1007.45), "court : hauteur affichee 1007,45 (%.2f)" % court.size.y)
	_check(_near(court.position.y, -77.72), "court : deborde de 77,72 en haut (%.2f)" % court.position.y)

	# Sur un ecran TRES LONG, la hauteur commande a nouveau, plus fort.
	var long := CoverFit.rect(Vector2(393, 987), texture)
	_check(_near(long.size.x, 468.30), "tres long : largeur affichee 468,30 (%.2f)" % long.size.x)
	_check(_near(long.position.x, -37.65), "tres long : deborde de 37,65 a gauche (%.2f)" % long.position.x)

	# L'aller-retour doit etre exact sur les huit formats : c'est la propriete
	# dont depend tout l'ancrage du village.
	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		var point := Vector2(133.84, 512.96)   # un point DANS l'image
		var screen := CoverFit.from_texture(point, size, texture)
		var back := CoverFit.to_texture(screen, size, texture)
		_check(back.distance_to(point) < 0.05,
			"%s : l'aller-retour image <-> ecran est exact (%.3f)"
				% [String(entry["name"]), back.distance_to(point)])

	# Le fond COUVRE toujours l'ecran : jamais de bande vide.
	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		var r := CoverFit.rect(size, texture)
		_check(r.size.x >= size.x - 0.01 and r.size.y >= size.y - 0.01,
			"%s : le fond couvre l'ecran entier" % String(entry["name"]))
```

Créer `tools/format_test.tscn` : un `Node` racine nommé `FormatTest`, script
`res://tools/format_test.gd`.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/format_test.gd" id="1_test"]

[node name="FormatTest" type="Node"]
script = ExtResource("1_test")
```

- [ ] **Étape 2 : le lancer pour vérifier qu'il échoue**

```bash
"$GODOT" --headless --path . tools/format_test.tscn
```

Attendu : **échec au chargement** — `res://scripts/ui/cover_fit.gd` n'existe
pas encore. C'est le rouge qu'on veut.

- [ ] **Étape 3 : écrire `CoverFit`**

Créer `scripts/ui/cover_fit.gd` :

```gdscript
class_name CoverFit
##
## LA GEOMETRIE DU "KEEP_ASPECT_COVERED", en fonctions pures.
##
## Godot sait deja poser un fond en couverture - mais il ne dit pas OU il l'a
## pose. Or le village colle ses etiquettes a des batiments PEINTS DANS
## l'image : sans ce rectangle, les etiquettes et le decor suivent deux lois
## d'echelle differentes, et se decollent des que le format change.
##
## Mesure du defaut, avant correction : ~34 points de derive sur un ecran
## court, et le bouton BATAILLE a 42 points du centre.
##
## Aucune fonction ici ne touche a la scene : c'est ce qui les rend mesurables
## en headless, sans fenetre et sans rendu (cf. tools/format_test.gd).
##


## Facteur d'echelle applique a la texture pour qu'elle COUVRE le viewport.
##
## Le plus GRAND des deux rapports, jamais le plus petit : c'est ce qui fait
## la difference entre couvrir (aucune bande vide, ca deborde) et contenir
## (ca rentre, avec des bandes).
static func scale(viewport: Vector2, texture: Vector2) -> float:
	if texture.x <= 0.0 or texture.y <= 0.0:
		return 1.0
	return maxf(viewport.x / texture.x, viewport.y / texture.y)


## Le rectangle que la texture occupe REELLEMENT dans le viewport, centre.
## Sa position est negative sur l'axe qui deborde.
static func rect(viewport: Vector2, texture: Vector2) -> Rect2:
	var factor := scale(viewport, texture)
	var size := texture * factor
	return Rect2((viewport - size) * 0.5, size)


## Un point de l'ECRAN, exprime dans le repere de l'image.
static func to_texture(point: Vector2, viewport: Vector2, texture: Vector2) -> Vector2:
	var factor := scale(viewport, texture)
	if factor <= 0.0:
		return point
	return (point - rect(viewport, texture).position) / factor


## Un point de l'IMAGE, place sur l'ecran. Reciproque exacte de to_texture.
static func from_texture(point: Vector2, viewport: Vector2, texture: Vector2) -> Vector2:
	return rect(viewport, texture).position + point * scale(viewport, texture)
```

- [ ] **Étape 4 : le relancer pour vérifier qu'il passe**

```bash
"$GODOT" --headless --path . tools/format_test.tscn
```

Attendu : `RESULTAT : la geometrie tient sur les huit formats.`, code de
sortie 0. Les 23 lignes en `OK`.

⚠️ Si une valeur attendue ne tombe pas, **relire le calcul avant de changer la
constante**. Les quatre erreurs de la sonde économique étaient toutes dans
l'instrument, jamais dans le jeu.

- [ ] **Étape 5 : commit**

```bash
git add scripts/ui/cover_fit.gd tools/format_test.gd tools/format_test.tscn
git commit -m "La geometrie du fond devient mesurable"
```

---

## Tâche 3 : `resolutions.tscn` voit les quatre écrans manquants

**Fichiers :**
- Modifier : `tools/resolutions.gd` (la constante `SCREENS`)

**Interfaces :**
- Consomme : rien.
- Produit : des captures pour château, victoire, défaite, nulle et les quatre
  popups, sur les huit formats — la matière première des tâches 7 à 11.

- [ ] **Étape 1 : lancer le banc tel quel, pour avoir l'avant**

```bash
"$GODOT" --path . tools/resolutions.tscn
```

Sans `--headless`. Les PNG atterrissent dans `tools/screenshots/echelle/`.
Noter combien de fichiers sont produits : `ls tools/screenshots/echelle | wc -l`
doit rendre **72** (9 entrées × 8 formats).

- [ ] **Étape 2 : ajouter les écrans manquants à `SCREENS`**

Dans `tools/resolutions.gd`, après la ligne du combat, ajouter :

```gdscript
	# --- LES ECRANS QUE LE BANC NE REGARDAIT PAS ---------------------------
	#
	# Le chateau, les trois resultats et les quatre popups n'ont jamais ete
	# passes au crible des formats. Ils heritent ici des huit tailles ET de
	# _finish_animations(), sans quoi une entree animee les photographierait
	# a moitie apparus (piege deja paye sur la preparation).
	{"scene": "res://scenes/village/castle_screen.tscn", "name": "chateau", "battle": 1},
	{"scene": "res://scenes/village/building_popup.tscn", "name": "popup-batiment",
		"battle": 1, "popup": Balance.PION},
	# Le DONJON DES TOURS est verrouille sur une sauvegarde neuve : c'est
	# l'etat qu'on veut photographier, et c'est celui dont la maquette cercle
	# le cadre d'or (cf. tache 10).
	{"scene": "res://scenes/village/building_popup.tscn", "name": "popup-verrouille",
		"battle": 1, "popup": Balance.TOUR},
	{"scene": "res://scenes/village/confirm_upgrade.tscn", "name": "popup-amelioration",
		"battle": 1},
	{"scene": "res://scenes/village/mission_popup.tscn", "name": "popup-missions",
		"battle": 1},
	# LES TROIS RESULTATS N'ONT PAS DE SCENE : BattleResult est un script qui
	# etend Control, monte a la main par battle.gd (BattleResult.new(), trois
	# appels). On le construit donc pareil ici - sans quoi ce banc
	# photographierait un montage qui n'existe nulle part dans le jeu.
	{"result": "win",  "name": "victoire", "battle": 3},
	{"result": "loss", "name": "defaite",  "battle": 3},
	{"result": "draw", "name": "nulle",    "battle": 3},
```

- [ ] **Étape 3 : brancher les clés neuves dans la boucle**

✅ **API vérifiée dans le code** — pas de méthode à inventer :

| Écran | Ce qu'il expose réellement |
|---|---|
| `building_popup.gd:48` | `open(type: String)` |
| `battle_result.gd:185` | `open(victory: bool, title_text: String = "")` |
| `battle_result.gd:190` | `open_draw(title_text: String)` |

Dans `_ready()`, remplacer la ligne `var instance := load(...).instantiate()`
par une construction qui accepte les deux formes :

```gdscript
			var instance: Node
			if screen.has("result"):
				instance = BattleResultScript.new()
			else:
				instance = load(String(screen["scene"])).instantiate()
			add_child(instance)

			# Un popup de batiment ne montre rien tant qu'on ne lui a pas dit
			# QUEL batiment : sans ca les huit captures sont vides.
			if screen.has("popup"):
				instance.open(String(screen["popup"]))

			# L'ecran de resultat prend sa peau a l'ouverture - c'est elle qui
			# fait la difference entre la victoire, la defaite et l'acier du
			# match nul, qui a ses propres assets (assets/results/draw_*).
			match String(screen.get("result", "")):
				"win":
					instance.open(true, "VICTOIRE")
				"loss":
					instance.open(false, "DEFAITE")
				"draw":
					instance.open_draw("NULLE")
```

Et en tête de fichier, à côté de `const Driver` :

```gdscript
const BattleResultScript := preload("res://scenes/battle/battle_result.gd")
```

⚠️ **`battle_result.gd` a déjà son `_animate_entry()`** (ligne 247) et son
`_slide_in()`. Les trois captures seraient donc prises à mi-apparition sans
`_finish_animations()` — qui est déjà appelé dans la boucle. Ne pas le
retirer.

- [ ] **Étape 4 : relancer et vérifier le compte**

```bash
"$GODOT" --path . tools/resolutions.tscn
ls tools/screenshots/echelle | wc -l
```

Attendu : **128** fichiers (16 entrées × 8 formats), et aucune erreur dans la
sortie.

- [ ] **Étape 5 : regarder les trois tailles hors format en premier**

Ouvrir, dans cet ordre, `*_web-393x700.png`, `*_court-360x620.png`,
`*_tres-long-430x1080.png` pour les huit écrans neufs. Noter dans
`chantier_g_f.md` ce qui déborde, se centre mal ou se coupe — **par écran et
par format**. C'est la liste de travail des tâches 7 à 11.

⚠️ **Une comparaison n'est valable qu'à ÉTAT DE PARTIE ÉGAL.** Le banc part
d'un `Game.reset_progress()` : tout au niveau 1, deux bâtiments verrouillés.
Ne pas conclure qu'un écran diffère de la maquette alors que c'est le même
écran à un autre moment de la partie.

- [ ] **Étape 6 : commit**

```bash
git add tools/resolutions.gd chantier_g_f.md
git commit -m "Le banc de format regarde enfin le chateau, les resultats et les popups"
```

---

## Tâche 4 : le village en deux calques

**Fichiers :**
- Modifier : `scenes/village/village.tscn` (`Overlay` → `DecorLayer` + `UiLayer`)
- Modifier : `scenes/village/village.gd`
- Modifier : `tools/format_test.gd` (le test qui échoue d'abord)

**Interfaces :**
- Consomme : `CoverFit.rect / scale / to_texture / from_texture` (tâche 2).
- Produit :
  - `Village.BACKGROUND_SIZE: Vector2` = `Vector2(864, 1821)`
  - `Village.DESIGN_SIZE: Vector2` = `Vector2(393, 852)`
  - `Village.decor_rect(viewport: Vector2) -> Rect2` — **statique**
  - `Village.design_to_decor(point: Vector2, viewport: Vector2) -> Vector2` — **statique**
  - `Village.battle_center_x(viewport: Vector2) -> float` — **statique**

**Pourquoi statiques.** Un banc headless ne peut pas redimensionner une vraie
fenêtre de façon fiable. En rendant la conversion statique, elle se teste avec
des nombres, sans instancier l'écran — et le test devient un vrai garde-fou de
régression plutôt qu'une capture à regarder.

⚠️ **Honnêteté sur ce que ce test prouve.** Il garde la **formule** contre une
régression ; il ne remplace pas l'œil. La preuve que les étiquettes tombent bien
sur leurs bâtiments reste la comparaison visuelle de l'étape 7.

- [ ] **Étape 1 : écrire le test du village, qui échoue**

Ajouter à `tools/format_test.gd`, dans `_ready()` après `_test_cover_fit()` :

```gdscript
	_test_village_anchoring()
```

Et la fonction, en fin de fichier :

```gdscript
# ------------------------------- LE VILLAGE ----------------------------------

const Village := preload("res://scenes/village/village.gd")

## Le village colle ses etiquettes a des batiments PEINTS DANS le fond. La
## seule chose qui doive rester vraie sur tous les formats, c'est donc : une
## etiquette tombe toujours sur le MEME POINT DE L'IMAGE.
func _test_village_anchoring() -> void:
	print("\n[2] Village : les etiquettes suivent le decor, pas l'ecran")

	var texture: Vector2 = Village.BACKGROUND_SIZE
	var design: Vector2 = Village.DESIGN_SIZE

	# Les quatre casernes, le chateau, et une lumiere de fenetre - relevees sur
	# la maquette, donc exprimees dans le repere de la REFERENCE.
	var points := {
		"caserne des pions": Vector2(57, 240),
		"ecuries": Vector2(235, 230),
		"cloitre des fous": Vector2(45, 628),
		"donjon des tours": Vector2(252, 619),
		"chateau": Vector2(120, 425),
		"fenetre centrale": Vector2(186, 385),
	}

	for label in points:
		var design_point: Vector2 = points[label]
		var expected := CoverFit.to_texture(design_point, design, texture)

		# A la reference, la conversion doit etre l'identite : sinon le village
		# a bouge par rapport a sa propre maquette.
		var at_base: Vector2 = Village.design_to_decor(design_point, design)
		_check(at_base.distance_to(design_point) < 0.5,
			"%s : inchange a la reference (%.2f)" % [label, at_base.distance_to(design_point)])

		# Sur les huit formats, le point d'image vise doit rester le meme.
		var worst := 0.0
		for entry in VIEWPORTS:
			var size: Vector2 = entry["size"]
			var placed: Vector2 = Village.design_to_decor(design_point, size)
			var landed := CoverFit.to_texture(placed, size, texture)
			worst = maxf(worst, landed.distance_to(expected))
		_check(worst < 1.0, "%s : derive maximale %.2f pt sur les huit formats" % [label, worst])

	# Le bouton BATAILLE suit l'ECRAN, pas le decor : il doit rester centre.
	for entry in VIEWPORTS:
		var size: Vector2 = entry["size"]
		var center: float = Village.battle_center_x(size)
		_check(_near(center, size.x * 0.5, 1.0),
			"%s : BATAILLE centre (%.1f pour un centre a %.1f)"
				% [String(entry["name"]), center, size.x * 0.5])
```

- [ ] **Étape 2 : le lancer pour vérifier qu'il échoue**

```bash
"$GODOT" --headless --path . tools/format_test.tscn
```

Attendu : échec au chargement — `design_to_decor`, `battle_center_x`,
`BACKGROUND_SIZE` et `DESIGN_SIZE` n'existent pas sur `village.gd`.

**Noter la sortie.** Une fois les fonctions ajoutées mais avant que la scène ne
les utilise, ce test chiffre la dérive réelle : c'est la mesure annoncée dans la
spec (~34 pt attendus sur `web-393x700`). **Si le chiffre mesuré s'écarte
franchement de 34, relire le calcul de la spec avant de coder la correction.**

- [ ] **Étape 3 : découper la scène en deux calques**

Dans `scenes/village/village.tscn`, remplacer le nœud `Overlay` par **deux**
nœuds frères, dans cet ordre (le décor est dessiné dessous) :

```
[node name="DecorLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 0
mouse_filter = 2

[node name="UiLayer" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
```

`DecorLayer` n'a **aucune ancre** : son rectangle est posé par le code à chaque
redimensionnement. `UiLayer` couvre l'écran.

- [ ] **Étape 4 : poser la géométrie dans `village.gd`**

Remplacer `const DESIGN_HEIGHT := 852.0` et toute la fonction
`_fit_overlay_to_design()` par :

```gdscript
const CoverFit := preload("res://scripts/ui/cover_fit.gd")

## Taille REELLE du fichier de fond, relevee sur le PNG - pas la taille de la
## maquette. Le rapport 0,4745 differe de celui de la reference (0,4613), et
## c'est tout le probleme : en KEEP_ASPECT_COVERED l'illustration GROSSIT avec
## la hauteur du viewport pendant que des coordonnees calees sur 852 ne
## bougent pas. Mesure avant correction : ~34 points de derive sur un ecran
## court, et le bouton BATAILLE a 42 points du centre.
const BACKGROUND_SIZE := Vector2(864, 1821)

## La reference du projet, celle dans laquelle toutes les coordonnees Figma de
## ce fichier sont exprimees.
const DESIGN_SIZE := Vector2(393, 852)


## Le rectangle que l'illustration occupe reellement, pour un viewport donne.
## STATIQUE : c'est ce qui la rend mesurable sans instancier l'ecran
## (cf. tools/format_test.gd).
static func decor_rect(viewport: Vector2) -> Rect2:
	return CoverFit.rect(viewport, BACKGROUND_SIZE)


## Une coordonnee de la MAQUETTE, placee la ou elle tombe reellement sur le
## decor. Elle passe par le repere de l'image, qui est son repere d'origine -
## c'est pour ca qu'elle redevient vraie sur tous les formats.
static func design_to_decor(point: Vector2, viewport: Vector2) -> Vector2:
	var in_texture := CoverFit.to_texture(point, DESIGN_SIZE, BACKGROUND_SIZE)
	return CoverFit.from_texture(in_texture, viewport, BACKGROUND_SIZE)


## Le bouton BATAILLE suit l'ECRAN, pas le decor : un bouton d'action qui
## glisse parce que l'illustration a grossi serait faux. Il est donc centre,
## et non plus pose a x=102 comme le voulait un Rect2 cale sur 393 de large.
static func battle_center_x(viewport: Vector2) -> float:
	return viewport.x * 0.5


## Recale le calque de decor sur le rectangle du fond. Appelee au demarrage et
## a chaque redimensionnement : c'est le seul endroit du fichier qui connaisse
## la taille de l'ecran.
func _fit_decor_to_background() -> void:
	var r := decor_rect(get_viewport_rect().size)
	_decor.position = r.position
	_decor.size = r.size
	_decor.scale = Vector2.ONE * CoverFit.scale(get_viewport_rect().size, BACKGROUND_SIZE)
	# Le calque porte l'echelle : ses enfants gardent donc les coordonnees de
	# l'IMAGE, jamais celles de l'ecran. On ne recalcule aucune position.
	_decor.size = BACKGROUND_SIZE
```

⚠️ **Le calque porte l'échelle, ses enfants gardent les coordonnées de
l'image.** C'est ce qui évite de recalculer six halos et cinq étiquettes à
chaque redimensionnement — et donc d'avoir cinq endroits où se tromper.

- [ ] **Étape 5 : répartir les enfants entre les deux calques**

Remplacer `@onready var _overlay: Control = $Overlay` par :

```gdscript
@onready var _decor: Control = $DecorLayer
@onready var _ui: Control = $UiLayer
```

Puis, dans chaque fonction de construction, remplacer `_overlay.add_child(...)`
par le calque qui convient :

| Va dans `_decor` | Va dans `_ui` |
|---|---|
| `_build_castle_glow()` (halo + six lumières) | `_build_top_bar()` (fondus, or, gemmes, missions, réglages, codex) |
| `_build_castle_label()` | `_build_battle_button()` |
| `_build_building_label()` × 4 | `_build_dev_button()` |
| | `_build_icon_button()` (boutique) |

Et convertir les coordonnées **une seule fois**, à la construction, avec :

```gdscript
CoverFit.to_texture(point, DESIGN_SIZE, BACKGROUND_SIZE)
```

Concrètement : `CASTLE_POS`, les quatre `BUILDING_POS`, `CASTLE_GLOW_RECT` et
les six `GLOW_LIGHTS` passent par cette conversion avant d'être posés.

⚠️ **`_refresh_castle_glow()` repositionne le halo à chaque seconde** (le ticker
de `_ready`). Il relit `CASTLE_GLOW_RECT` : le convertir là aussi, sinon le halo
saute à sa position d'origine une seconde après l'ouverture.

- [ ] **Étape 6 : ancrer le bouton BATAILLE et brancher le redimensionnement**

Dans `_build_battle_button()`, remplacer les deux lignes de position par un
ancrage centré-bas :

```gdscript
	# ANCRE, pas positionne : son Rect2 d'origine (102, 765, 189, 59) avait un
	# centre a 196,5 - exactement 393/2. Sur un viewport de 478 de large, ca le
	# mettait a 42 points du centre reel.
	_battle_button.anchor_left = 0.5
	_battle_button.anchor_right = 0.5
	_battle_button.anchor_top = 1.0
	_battle_button.anchor_bottom = 1.0
	_battle_button.offset_left = -BATTLE_RECT.size.x * 0.5
	_battle_button.offset_right = BATTLE_RECT.size.x * 0.5
	_battle_button.offset_top = -(DESIGN_SIZE.y - BATTLE_RECT.position.y)
	_battle_button.offset_bottom = _battle_button.offset_top + BATTLE_RECT.size.y
```

Dans `_ready()`, remplacer `_fit_overlay_to_design()` par :

```gdscript
	_fit_decor_to_background()
	get_viewport().size_changed.connect(_fit_decor_to_background)
```

- [ ] **Étape 7 : relancer le banc, puis regarder**

```bash
"$GODOT" --headless --path . tools/format_test.tscn
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : le banc de format passe (dérive < 1 pt partout, BATAILLE centré sur
les huit), et `ui_test` reste **vert** — le village y ouvre un bâtiment,
recrute et améliore, et ce sont ces étiquettes-là qu'on vient de déplacer.

Puis, l'œil :

```bash
"$GODOT" --path . tools/resolutions.tscn
```

Comparer `village_web-393x700.png` et `village_tres-long-430x1080.png` avec
leur version d'avant (tâche 3, étape 1) : les étiquettes doivent être **sur**
leurs bâtiments, et BATAILLE au milieu.

- [ ] **Étape 8 : commit**

```bash
git add scenes/village/village.gd scenes/village/village.tscn tools/format_test.gd
git commit -m "Le village en deux calques : le decor suit l'image, l'interface suit l'ecran"
```

- [ ] **Étape 9 : fermer la règle 4 de `CLAUDE.md`**

Le village était le dernier écran en coordonnées absolues. Remplacer
« Reste à convertir : village » par la liste complète des écrans convertis.

```bash
git add CLAUDE.md
git commit -m "Tous les ecrans sont ancres"
```

---

## Tâche 5 : le bouton de coin unique

**Fichiers :**
- Créer : `scenes/ui/components/corner_button.gd`
- Modifier : `scenes/battle/battle.gd` (retirer `_corner_button_style()`, deux
  appels), `scenes/village/village.gd` (codex, réglages, boutique),
  `scenes/village/castle_screen.gd` (retour), `scenes/village/codex_popup.gd`,
  `scenes/village/shop.gd`, `scenes/battle/battle_prep.gd` (les trois retours)

**Interfaces :**
- Produit :
  - `CornerButton.floating(glyph: String, on_press: Callable, tone := CornerButton.Tone.NIGHT) -> CornerButton`
  - `CornerButton.back(on_press: Callable) -> CornerButton`
  - `CornerButton.with_texture(path: String, on_press: Callable, tone: Tone) -> CornerButton`
  - `CornerButton.FLOATING_SIZE := 34.0`, `CornerButton.BACK_SIZE := 52.0`

⚠️ **L'énumération s'appelle `Tone`, surtout pas `Variant`** — `Variant` est un
type intégré de GDScript, et le nom entrerait en collision. `Pill` du même
dossier utilise bien `Variant`, mais comme énumération *imbriquée* référencée
`Pill.Variant` : ne pas en déduire que le nom est libre ici.

✅ **Vérifié** : `Icon` connaît déjà `arrow_left`, `gear`, `info` et `close` —
les quatre glyphes dont le composant a besoin. Rien à ajouter à `icon.gd`.

**Le défaut, mesuré :** la même classe de contrôle existe en **six tailles et
quatre habillages**. Le joueur l'a signalé dans ces mots : « il faudra aussi
aligner les boutons des paramètres etc., sur les écrans, parce que là c'est
n'importe quoi ».

**Ce qui bouge :** codex 28 → 34 ; réglages 28 → 34 ; boutique 45 → 34 ; retour
du château 44 → 52. Les trois retours déjà à 52 (préparation, codex, boutique)
ne bougent pas. Sortie ✕ et aide `i` de la bataille restent à 34.

- [ ] **Étape 1 : écrire le test, qui échoue**

Ajouter à `tools/ui_test.gd`, dans `_ready()` :

```gdscript
	await _test_corner_buttons()
```

Et la fonction :

```gdscript
# --------------------------- LES BOUTONS DE COIN -----------------------------

## Le meme controle existait en SIX tailles et quatre habillages selon l'ecran.
## Ce test ne regarde pas a quoi ils ressemblent - il verifie qu'ils n'ont plus
## que DEUX tailles, et qu'ils repondent toujours.
func _test_corner_buttons() -> void:
	print("\n[7] Boutons de coin : deux tailles, pas six")

	const CornerButton := preload("res://scenes/ui/components/corner_button.gd")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	var sizes: Array[float] = []
	for node in _all_corner_buttons(village):
		sizes.append(node.size.x)
		_check(node.size.x == node.size.y, "un bouton de coin est carre (%.0f)" % node.size.x)

	_check(sizes.size() >= 3, "le village porte au moins trois boutons de coin (%d)" % sizes.size())
	for value in sizes:
		_check(value == CornerButton.FLOATING_SIZE or value == CornerButton.BACK_SIZE,
			"taille %.0f : c'est une des deux tailles autorisees" % value)

	# Et ils repondent toujours : une reprise graphique qui casse un bouton ne
	# se voit sur aucune capture.
	_check(is_instance_valid(village._codex_button), "le bouton codex existe encore")
	_check(is_instance_valid(village._shop_button), "le bouton boutique existe encore")

	village.queue_free()
	await _frames(2)


func _all_corner_buttons(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	const CornerButton := preload("res://scenes/ui/components/corner_button.gd")
	for node in root.find_children("*", "Control", true, false):
		if node.get_script() == CornerButton:
			found.append(node)
	return found
```

- [ ] **Étape 2 : le lancer pour vérifier qu'il échoue**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : échec au chargement — `corner_button.gd` n'existe pas.

- [ ] **Étape 3 : écrire le composant**

Créer `scenes/ui/components/corner_button.gd` :

```gdscript
extends PanelContainer
class_name CornerButton
##
## LE BOUTON DE COIN, en un seul exemplaire.
##
## Avant lui, la meme chose - un bouton rond ou carre qui sort d'un ecran ou
## ouvre un panneau - existait en SIX tailles et QUATRE habillages : 24, 28,
## 34, 44, 45 et 52 points, selon l'ecran ou on l'avait ecrit. C'est ce que le
## joueur a resume par "la c'est n'importe quoi".
##
## Il n'y a plus que DEUX tailles, et elles ont chacune une raison :
##   - 34 : le bouton FLOTTANT, pose sur un coin. C'est la taille de la
##     bataille, la plus juste au pouce sans manger l'ecran.
##   - 52 : le RETOUR en tete d'ecran, sur plaque royale. Il ouvre la lecture,
##     il a droit a la place.
##
## Un PanelContainer et non un Button : c'est le seul moyen d'y inserer une
## Icon, qui se DESSINE (meme raison que _make_clickable dans village.gd).
##

## Bouton flottant pose sur un coin d'ecran.
const FLOATING_SIZE := 34.0
## Retour en tete d'ecran, sur plaque royale.
const BACK_SIZE := 52.0

## Espacement vertical entre deux boutons de la meme colonne.
const STACK_GAP := 8.0

enum Tone {
	NIGHT,   ## bleu nuit translucide - le defaut, sur un decor
	GOLD,    ## plaque royale doree - le retour en tete d'ecran
	ACCENT,  ## bleu plein - une entree vers un autre ecran (boutique)
	DANGER,  ## rouge sourd - quitter
}

const FILL := {
	Tone.NIGHT: Color("174971", 0.92),
	Tone.GOLD: Color("1e3278"),
	Tone.ACCENT: Color("3873f2"),
	Tone.DANGER: Color("b5514f"),
}
const EDGE := {
	Tone.NIGHT: Color("3d4f6b"),
	Tone.GOLD: Color("ffe680"),
	Tone.ACCENT: Color("b6c0f3"),
	Tone.DANGER: Color("c65f5f"),
}
const GLYPH_COLOR := {
	Tone.NIGHT: Color("ffe580"),
	Tone.GOLD: Color("ffe580"),
	Tone.ACCENT: Color("ffe580"),
	Tone.DANGER: Color("f2dede"),
}

var _pressed: Callable = Callable()


## Bouton flottant : 34 points, coins arrondis a la moitie (donc rond).
static func floating(glyph: String, on_press: Callable,
		tone: Tone = Tone.NIGHT) -> CornerButton:
	return _make(glyph, "", on_press, tone, FLOATING_SIZE)


## Retour en tete d'ecran : 52 points, plaque royale doree.
static func back(on_press: Callable) -> CornerButton:
	return _make("arrow_left", "", on_press, Tone.GOLD, BACK_SIZE)


## Bouton flottant dont le glyphe est une IMAGE et non un trace - la boutique,
## dont le picto vient de la maquette.
##
## ⚠️ Prendre l'image SOURCE de Figma, jamais l'export du noeud : celui-ci
## arrive avec le fond du bouton cuit dedans, alpha entierement opaque.
static func with_texture(path: String, on_press: Callable,
		tone: Tone = Tone.ACCENT) -> CornerButton:
	return _make("", path, on_press, tone, FLOATING_SIZE)


static func _make(glyph_name: String, texture_path: String, on_press: Callable,
		tone: Tone, side: float) -> CornerButton:
	var button := CornerButton.new()
	button.custom_minimum_size = Vector2(side, side)
	button.size = Vector2(side, side)
	button._pressed = on_press

	var box := StyleBoxFlat.new()
	box.bg_color = FILL[tone]
	box.set_corner_radius_all(int(side * 0.5) if tone != Tone.GOLD else 12)
	box.border_color = EDGE[tone]
	box.set_border_width_all(1)
	box.set_content_margin_all(side * 0.26)
	button.add_theme_stylebox_override("panel", box)

	var glyph: Control
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var image := TextureRect.new()
		image.texture = load(texture_path)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph = image
	else:
		var icon := Icon.new()
		icon.icon_name = glyph_name
		icon.color = GLYPH_COLOR[tone]
		glyph = icon
	glyph.custom_minimum_size = Vector2(side * 0.42, side * 0.42)
	button.add_child(glyph)

	UiTheme.ignore_mouse_recursive(glyph)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.gui_input.connect(button._on_gui_input)
	return button


## Pose le bouton dans une colonne ancree au coin haut-droit de son parent.
## `rank` vaut 0 pour le premier, 1 pour celui d'en dessous, et ainsi de suite -
## c'est ce qui remplace les six couples de coordonnees ecrits a la main.
func stack_top_right(rank: int, margin: Vector2 = Vector2(12, 12)) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -(margin.x + size.x)
	offset_right = -margin.x
	offset_top = margin.y + float(rank) * (size.y + STACK_GAP)
	offset_bottom = offset_top + size.y


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _pressed.is_valid():
			_pressed.call()
```

✅ **Les quatre glyphes existent déjà** dans `scenes/ui/components/icon.gd` :
`arrow_left`, `gear`, `info`, `close`. Rien à ajouter.

⚠️ **`icon.gd` connaît AUSSI `i`, `cle` et `wrench`** — trois noms très proches
de ceux qu'on utilise. Prendre `info` et non `i`, sans quoi le codex change de
picto sans que personne ne l'ait demandé.

- [ ] **Étape 4 : remplacer les dix appels**

Un fichier à la fois, en relançant `ui_test` entre chaque.

Dans `scenes/village/village.gd`, remplacer `_build_codex_button()`, le bloc
`settings` de `_build_top_bar()` et l'appel `_build_icon_button` par :

```gdscript
	_codex_button = CornerButton.floating("info", _on_codex_pressed)
	_ui.add_child(_codex_button)
	_codex_button.stack_top_right(1)

	var settings := CornerButton.floating("gear", _on_settings_pressed)
	_ui.add_child(settings)
	settings.stack_top_right(2)

	_shop_button = CornerButton.with_texture(SHOP_ICON, _on_shop_pressed)
	_ui.add_child(_shop_button)
	_shop_button.stack_top_right(3)
```

⚠️ **Le rang 0 est réservé** : c'est celui du bouton de développement, qui
disparaît en tâche 6. Commencer la colonne à 1 laisse sa place libre, et évite
de renuméroter trois lignes dans une tâche.

⚠️ **La boutique CHANGE de coin.** Elle était en bas à gauche, « posée à gauche
de BATAILLE parce que le bas de l'écran est la zone du pouce » — c'est un choix
du joueur, documenté dans le code. **Lui reposer la question avant de la
déplacer** : si elle doit rester en bas, elle garde 34 points mais reçoit un
ancrage bas-gauche au lieu d'un rang dans la colonne.

Puis, dans `scenes/battle/battle.gd`, supprimer `_corner_button_style()` et
remplacer ses deux appelants par `CornerButton.floating("close", …, CornerButton.Tone.DANGER)`
au rang 0 et `CornerButton.floating("info", …)` au rang 1.

Dans `scenes/village/castle_screen.gd`, `codex_popup.gd`, `shop.gd` et
`battle_prep.gd`, remplacer chaque bouton retour par `CornerButton.back(…)`.

- [ ] **Étape 5 : relancer les deux bancs**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
"$GODOT" --headless --path . tools/smoke_test.tscn
```

Attendu : `ui_test` vert, y compris le nouveau bloc `[7]` ; `smoke_test` rend
**10/10 batailles gagnables** — la sortie de bataille et l'aide `i` sont sur son
chemin.

- [ ] **Étape 6 : commit**

```bash
git add scenes/ui/components/corner_button.gd scenes/village scenes/battle tools/ui_test.gd
git commit -m "Six tailles de boutons de coin deviennent deux"
```

---

## Tâche 6 : le bouton de développement passe derrière un geste

**Fichiers :**
- Modifier : `scenes/village/village.gd` (`_build_dev_button()` → une zone de
  geste)

**Interfaces :**
- Consomme : `CornerButton` (tâche 5) — pour le retirer de la colonne.
- Produit : rien de public.

**Décision du joueur :** masqué derrière un geste, **pas** derrière
`OS.is_debug_build()`. La raison est mesurée : il teste sur son téléphone via le
**build web exporté**, donc en release — un masquage en debug lui retirerait son
seul raccourci.

- [ ] **Étape 1 : remplacer le bouton par une zone de geste**

Dans `scenes/village/village.gd`, remplacer tout le corps de
`_build_dev_button()` par :

```gdscript
## LE PANNEAU DE DEVELOPPEMENT N'A PLUS DE BOUTON.
##
## Il n'etait dans aucune maquette, il chevauchait la rangee des reglages, et
## c'est un des ecarts que le joueur a signales. Mais le masquer hors build de
## debug ne marche pas ici : il teste sur son telephone via le build web
## EXPORTE, donc en release. Le raccourci doit survivre a l'export.
##
## D'ou un geste : un appui long dans le coin haut-droit, sur une zone
## invisible. Rien a voir dans la maquette, et l'acces reste.
const DEV_GESTURE_SIZE := Vector2(60, 60)
const DEV_GESTURE_HOLD := 1.2

var _dev_hold: float = 0.0


func _build_dev_gesture() -> void:
	var zone := Control.new()
	zone.name = "DevGesture"
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.anchor_left = 1.0
	zone.anchor_right = 1.0
	zone.anchor_top = 0.0
	zone.anchor_bottom = 0.0
	zone.offset_left = -DEV_GESTURE_SIZE.x
	zone.offset_right = 0.0
	zone.offset_top = 0.0
	zone.offset_bottom = DEV_GESTURE_SIZE.y
	_ui.add_child(zone)

	zone.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_dev_hold = 0.0 if event.pressed else -1.0
	)
	zone.set_process(true)
	zone.process_priority = 0

	# Le compte se tient ici plutot que dans la zone : un Control nu n'a pas de
	# _process a lui sans script, et ajouter un script pour trois lignes ferait
	# un fichier de plus a lire.
	var ticker := Timer.new()
	ticker.wait_time = 0.1
	ticker.timeout.connect(func():
		if _dev_hold < 0.0:
			return
		_dev_hold += 0.1
		if _dev_hold >= DEV_GESTURE_HOLD:
			_dev_hold = -1.0
			_on_dev_pressed()
	)
	add_child(ticker)
	ticker.start()
```

Dans `_ready()`, remplacer `_build_dev_button()` par `_build_dev_gesture()`.

- [ ] **Étape 2 : écrire le test du geste**

Ajouter au bloc `[7]` de `tools/ui_test.gd` :

```gdscript
	# Le bouton de developpement ne doit plus etre VISIBLE, mais son acces doit
	# survivre - le joueur teste sur un build web, donc en release.
	var gesture := village.find_child("DevGesture", true, false)
	_check(gesture != null, "la zone de geste du panneau dev existe")
	_check(village.find_child("DevButton", true, false) == null,
		"le bouton dev n'est plus a l'ecran")
	village._on_dev_pressed()
	await _frames(3)
	_check(is_instance_valid(village._popup), "le panneau dev s'ouvre encore")
	if is_instance_valid(village._popup):
		village._popup.queue_free()
		await _frames(2)
```

- [ ] **Étape 3 : relancer**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : vert.

- [ ] **Étape 4 : le vérifier à la main, dans le vrai jeu**

Un geste ne se teste pas au banc : le banc appelle la fonction, pas le doigt.
Lancer le village et **maintenir 1,2 s dans le coin haut-droit**. Le panneau
doit s'ouvrir. Si le geste est trop dur ou trop facile à déclencher par
accident, ajuster `DEV_GESTURE_HOLD` et le dire au joueur.

- [ ] **Étape 5 : commit, et redire le geste au joueur**

```bash
git add scenes/village/village.gd tools/ui_test.gd
git commit -m "Le bouton dev quitte l'ecran sans emporter le raccourci"
```

⚠️ **Dire au joueur, en clair, quel est le geste.** Un raccourci qu'on oublie
n'existe pas, et c'est son outil de test sur téléphone.

---

## Tâche 7 : le gabarit d'entrée de modale

**Fichiers :**
- Modifier : `scenes/ui/components/modal.gd`

**Interfaces :**
- Produit : `Modal.open()` joue désormais une entrée. Aucun changement de
  signature — **les six appelants en héritent sans être touchés**.

**Le meilleur rapport du chantier :** un fichier, six écrans animés. Vérifié,
les appelants sont `building_popup.gd` (qui couvre les quatre états de popup de
bâtiment dans une seule scène), `confirm_upgrade.gd`, `mission_popup.gd`,
`series_popup.gd`, l'aide `i` de `battle.gd`, et `ui_kit_showcase.gd`.

**Relevé Figma** (identique sur les trois popups de bâtiment) : `Dark-Overlay`
en opacité 0 → 1 sur 20 % de la timeline ; la modale en opacité 0 → 1,
`translate 0/+30 → 0`, `scale 0,92 → 1`, de 0,15 s à 0,6 s, courbe
`cubic-bezier(0, 0, 0.2, 1)`.

- [ ] **Étape 1 : écrire le test, qui échoue**

Ajouter à `tools/ui_test.gd` :

```gdscript
	await _test_modal_entry()
```

```gdscript
# ------------------------- L'ENTREE DES MODALES ------------------------------

## Une modale qui apparait d'un coup se lit comme un bug d'affichage. Ce test
## ne juge pas l'esthetique - il verifie que l'entree EXISTE (l'ecran part
## transparent) et qu'elle SE TERMINE (il finit opaque et a l'echelle 1).
func _test_modal_entry() -> void:
	print("\n[8] Modales : l'entree se joue, et elle se termine")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	village._on_building_pressed(Balance.PION)
	await _frames(1)

	var modal: Control = village._popup.find_child("Modal", true, false)
	if modal == null:
		modal = village._popup
	_check(modal.modulate.a < 0.9, "la modale part transparente (%.2f)" % modal.modulate.a)

	# Sauter a la fin des tweens plutot qu'attendre : instantane, et exact.
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(10.0)
	await _frames(2)

	_check(modal.modulate.a > 0.99, "elle finit opaque (%.2f)" % modal.modulate.a)
	_check(absf(modal.scale.x - 1.0) < 0.01, "elle finit a l'echelle 1 (%.3f)" % modal.scale.x)

	village.queue_free()
	await _frames(2)
```

- [ ] **Étape 2 : le lancer pour vérifier qu'il échoue**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : `ECHEC la modale part transparente (1.00)` — elle apparaît d'un coup
aujourd'hui.

- [ ] **Étape 3 : poser le gabarit dans `Modal`**

Dans `scenes/ui/components/modal.gd`, ajouter en tête :

```gdscript
## L'ENTREE DE MODALE DU JEU ENTIER, posee ici une seule fois.
##
## Relevee sur les trois popups de batiment (410:7342, 410:7488, 410:7629),
## qui portent exactement la meme timeline. Elle sert aussi la confirmation
## d'amelioration, le popup de missions, le popup de serie et l'aide de la
## bataille : six appelants, un seul endroit.
const ENTRY_DURATION := 0.45
const ENTRY_DELAY := 0.15
const DIM_SHARE := 0.20
const ENTRY_RISE := 30.0
const ENTRY_SCALE := 0.92
```

Et, à la fin de `open()` :

```gdscript
	_animate_entry()
```

Puis la fonction :

```gdscript
## ⚠️ PAS DE TRANSLATION ICI, et ce n'est pas un oubli.
##
## La maquette fait monter la modale de 30 px (translate 0/+30 -> 0). Mais
## _panel est $Center/Panel, donc enfant d'un CenterContainer : un tween de
## position s'y battrait avec la mise en page, exactement comme sur le bandeau
## de serie. L'opacite et l'echelle suffisent a lire le mouvement, et ce sont
## les deux que la maquette anime aussi.
func _animate_entry() -> void:
	# La position ne se lit qu'une fois les ancres posees : relevee a la
	# construction, elle ne veut rien dire.
	await get_tree().process_frame

	_panel.pivot_offset = _panel.size * 0.5

	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * ENTRY_SCALE

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, ENTRY_DURATION * DIM_SHARE)
	tween.tween_property(_panel, "modulate:a", 1.0, ENTRY_DURATION) \
		.set_delay(ENTRY_DELAY)
	tween.tween_property(_panel, "scale", Vector2.ONE, ENTRY_DURATION) \
		.set_delay(ENTRY_DELAY) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
```

✅ **Noms vérifiés dans `modal.gd`** : `_dim: ColorRect = $Dim` et
`_panel: PanelContainer = $Center/Panel`. Rien à chercher.

⚠️ **`ENTRY_RISE` n'est donc jamais utilisée.** Elle est dans les constantes
pour documenter ce que la maquette demande et **pourquoi on ne le porte pas** —
si quelqu'un sort un jour le panneau du `CenterContainer`, la valeur est là.
Si ça gêne, la retirer et garder l'explication dans le commentaire.

- [ ] **Étape 4 : relancer**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : le bloc `[8]` vert. Et **tous les blocs précédents restent verts** —
si `ui_test` échoue soudain sur le recrutement ou l'amélioration, c'est que
l'entrée retarde un bouton que le banc presse : le banc saute à la fin des
tweens, pas le clic.

- [ ] **Étape 5 : vérifier que les captures n'ont pas menti**

```bash
"$GODOT" --path . tools/resolutions.tscn
```

Les quatre popups ajoutés en tâche 3 doivent apparaître **entiers**, pas à
moitié. `resolutions.gd` appelle déjà `_finish_animations()` — c'est ce qui le
protège, et c'est le piège n°3 de la passation.

- [ ] **Étape 6 : commit**

```bash
git add scenes/ui/components/modal.gd tools/ui_test.gd
git commit -m "Une entree de modale, six ecrans animes"
```

---

## Tâche 8 : l'entrée de la boutique

**Fichiers :**
- Modifier : `scenes/village/shop.gd`

**Interfaces :**
- Consomme : rien.
- Produit : `Shop._animate_entry()`.

**Relevé Figma** (`shop-screen`, `410:7061`, 1,5 s, 15 nœuds) : en-tête qui
tombe de −40 px avec ressort ; panneau des monnaies en `scale 0,5 → 1` ; chaque
section monte de +35/+40 px avec `scale 0,92 → 1` (coffres 0,15 s, gemmes
0,5 s, or 0,75 s) ; chaque carte éclôt en `scale 0,5 → 1` à 100 ms d'écart ; le
bandeau légendaire en ressort élastique.

⚠️ **Les sections et les cartes sont des enfants de conteneur** : opacité et
échelle **seulement**. Les translations ne sont pas portables telles quelles.

- [ ] **Étape 1 : écrire le test, qui échoue**

Ajouter au bloc boutique existant de `tools/ui_test.gd` :

```gdscript
	# L'entree doit exister et se terminer. Le banc de capture saute a la fin
	# des tweens ; un joueur, lui, la voit.
	var fresh: Node = load("res://scenes/village/shop.tscn").instantiate()
	add_child(fresh)
	await _frames(1)
	var faded := 0
	for card in fresh.find_children("*", "Control", true, false):
		if card.modulate.a < 0.9:
			faded += 1
	_check(faded > 0, "la boutique part en fondu (%d elements)" % faded)
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(10.0)
	await _frames(2)
	var still_faded := 0
	for card in fresh.find_children("*", "Control", true, false):
		if card.modulate.a < 0.99:
			still_faded += 1
	_check(still_faded == 0, "tout est visible a la fin (%d en retard)" % still_faded)
	fresh.queue_free()
	await _frames(2)
```

- [ ] **Étape 2 : le lancer pour vérifier qu'il échoue**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : `ECHEC la boutique part en fondu (0 elements)`.

- [ ] **Étape 3 : porter la cascade**

Dans `scenes/village/shop.gd`, à la fin de la construction :

```gdscript
## L'ENTREE DE LA BOUTIQUE - cascade de haut en bas (shop-screen, 410:7061).
##
## ⚠️ Sections et cartes sont des ENFANTS DE CONTENEUR : opacite et echelle
## seulement. La maquette les fait aussi monter de 35 a 40 px, mais un tween
## de position se bat avec la mise en page - c'est ce qui avait colle le
## bandeau de serie en haut de l'ecran.
const ENTRY_SECTIONS := [
	{"delay": 0.15},   # les coffres
	{"delay": 0.50},   # les gemmes
	{"delay": 0.75},   # l'or
]
const ENTRY_CARD_GAP := 0.10
const ENTRY_DURATION := 0.40


func _animate_entry() -> void:
	# Les pivots ne se posent qu'une fois la mise en page faite.
	await get_tree().process_frame

	var tween := create_tween().set_parallel(true)

	for index in range(_sections.size()):
		var section: Control = _sections[index]
		var delay: float = float(ENTRY_SECTIONS[index]["delay"]) \
			if index < ENTRY_SECTIONS.size() else 0.75
		section.pivot_offset = section.size * 0.5
		section.modulate.a = 0.0
		section.scale = Vector2(0.92, 0.92)
		tween.tween_property(section, "modulate:a", 1.0, ENTRY_DURATION).set_delay(delay)
		tween.tween_property(section, "scale", Vector2.ONE, ENTRY_DURATION) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		for card_index in range(_cards_of(section).size()):
			var card: Control = _cards_of(section)[card_index]
			card.pivot_offset = card.size * 0.5
			card.modulate.a = 0.0
			card.scale = Vector2(0.5, 0.5)
			var card_delay := delay + 0.10 + float(card_index) * ENTRY_CARD_GAP
			tween.tween_property(card, "modulate:a", 1.0, ENTRY_DURATION).set_delay(card_delay)
			tween.tween_property(card, "scale", Vector2.ONE, ENTRY_DURATION) \
				.set_delay(card_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

✅ **Vérifié dans `shop.gd`** : les trois sections naissent toutes dans
`_section(title: String) -> VBoxContainer` (ligne 205), appelée par
`_build_chests()`, `_build_gem_packs()` et `_build_gold_packs()` — **dans cet
ordre**, qui est exactement celui de la cascade de la maquette. Il n'y a pas de
liste : la créer là où les sections naissent, jamais par `find_children` (qui
rendrait l'ordre imprévisible).

Ajouter en tête de `shop.gd` :

```gdscript
## Les trois sections, dans l'ordre ou elles sont construites - et c'est aussi
## l'ordre de la cascade de la maquette : coffres, gemmes, or.
var _sections: Array[Control] = []
```

Et à la fin de `_section()`, juste avant son `return` :

```gdscript
	_sections.append(section)
```

⚠️ **Vider `_sections` au début de `_build_body()`.** L'écran se reconstruit à
chaque `_refresh()` : sans ça, la liste enfle et l'animation tente d'animer des
nœuds libérés.

Les cartes se collectent de la même façon — chaque section est un
`VBoxContainer` dont les cartes sont les enfants directs :

```gdscript
func _cards_of(section: Control) -> Array[Node]:
	return section.get_children()
```

Appeler `_animate_entry()` à la fin de `_ready()`.

- [ ] **Étape 4 : relancer les deux bancs**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
"$GODOT" --path . tools/resolutions.tscn
```

Attendu : `ui_test` vert (y compris les achats de coffres, qui suivent), et
`boutique_*.png` **entière** sur les huit formats.

- [ ] **Étape 5 : commit**

```bash
git add scenes/village/shop.gd tools/ui_test.gd
git commit -m "La boutique s'ouvre en cascade"
```

---

## Tâche 9 : `mission-popup` — deux animations, pas une

**Fichiers :**
- Modifier : `scenes/village/mission_popup.gd`

**Interfaces :**
- Consomme : `Modal` (tâche 7) pour l'ouverture.
- Produit : `MissionPopup._animate_claim(row: Control)`.

**Relevé Figma** (`410:5664`, 2 s, 24 nœuds — la plus riche du fichier).

⚠️ **Ce sont DEUX animations dans une seule timeline de maquette**, et les
porter comme une entrée d'écran serait une erreur :

| Quand | Quoi |
|---|---|
| **à l'ouverture** | la modale jaillit du coin haut-droit (`translate 97,5 / −394`, `scale 0,05 → 1`, ressort) ; croix, titre, séparateur et liste montent de 10 px en cascade à 30 ms d'écart |
| **quand le joueur RÉCLAME** | les cinq barres se remplissent (`width: 0 → N`) à 75 ms d'écart ; le badge se comprime à 0,85, gonfle à 1,15, disparaît ; dix pièces d'or éclosent, s'éparpillent, **volent vers la bourse** ; la bourse rebondit — huit impulsions de `scale` entre 1,09 et 1,14 |

⚠️ **Les pièces traversent l'écran** : elles partent de la ligne de mission et
atterrissent sur la bourse, en barre haute. **Elles ne peuvent pas vivre dans la
modale** — il leur faut une couche au-dessus de tout.

- [ ] **Étape 1 : écrire le test, qui échoue**

```gdscript
# --------------------------- LE POPUP DE MISSIONS ----------------------------

## Deux animations, pas une : l'ouverture, et la reclamation. Ce test verifie
## surtout la SECONDE, parce que c'est celle qu'un portage naif fondrait dans
## l'entree - et elle se jouerait alors sans que le joueur ait rien reclame.
func _test_mission_claim() -> void:
	print("\n[9] Missions : la reclamation a sa propre animation")

	Game.reset_progress()
	var village: Node = load("res://scenes/village/village.tscn").instantiate()
	add_child(village)
	await _frames(3)

	village._on_missions_pressed()
	await _frames(2)
	var popup: Node = village._popup
	_check(is_instance_valid(popup), "le popup de missions s'ouvre")
	if not is_instance_valid(popup):
		village.queue_free()
		return

	# A l'ouverture, RIEN de la reclamation ne doit avoir demarre.
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(10.0)
	await _frames(2)
	_check(popup.find_child("CoinFlight", true, false) == null,
		"aucune piece ne vole tant que rien n'est reclame")

	village.queue_free()
	await _frames(2)
```

Ajouter `await _test_mission_claim()` dans `_ready()`.

- [ ] **Étape 2 : le lancer**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : vert sur les deux lignes **si** rien n'est encore porté. C'est un test
de non-régression posé **avant** le portage : il empêche précisément l'erreur
que la maquette invite à commettre.

- [ ] **Étape 3 : porter l'ouverture**

L'entrée générique vient déjà de `Modal` (tâche 7). Ajouter par-dessus la seule
chose qui lui est propre — la cascade des lignes :

```gdscript
## La cascade d'ouverture : croix, titre, separateur puis les lignes, a 30 ms
## d'ecart. Les lignes sont dans un conteneur : OPACITE SEULEMENT.
const OPEN_STAGGER := 0.03
const OPEN_DURATION := 0.25


## Les lignes de mission, dans l'ordre de la liste. `body` est le VBoxContainer
## que Modal expose publiquement (cf. modal.gd : `@onready var body`), donc ses
## enfants directs SONT les lignes, dans l'ordre ou elles ont ete ajoutees.
func _cascade_nodes() -> Array[Node]:
	return _modal.body.get_children()


func _animate_open() -> void:
	await get_tree().process_frame
	var tween := create_tween().set_parallel(true)
	var rank := 0
	for node in _cascade_nodes():
		node.modulate.a = 0.0
		tween.tween_property(node, "modulate:a", 1.0, OPEN_DURATION) \
			.set_delay(float(rank) * OPEN_STAGGER)
		rank += 1
```

⚠️ **Appeler `_animate_open()` APRÈS avoir rempli `body`.** Appelée avant, elle
met à 0 l'opacité d'une liste vide et les lignes arrivent ensuite à pleine
opacité — l'animation ne se voit pas, et rien ne le signale.

⚠️ **Le jaillissement depuis le coin haut-droit** (`translate 97,5 / −394`)
**ne se porte pas.** Vérifié : le panneau de `Modal` est `$Center/Panel`, enfant
d'un `CenterContainer` — un tween de position s'y battrait avec la mise en page.
Porter `scale 0,05 → 1` avec `TRANS_BACK`, qui rend déjà le jaillissement, et
laisser tomber la translation. C'est la même décision qu'en tâche 7, pour la
même raison.

- [ ] **Étape 4 : porter la réclamation, avec sa couche de pièces**

```gdscript
## LA RECLAMATION - la seconde animation, qui ne se joue QUE sur un geste du
## joueur. Barres qui se remplissent, badge qui pulse, dix pieces qui volent
## vers la bourse, bourse qui rebondit.
const CLAIM_BAR_GAP := 0.075
const CLAIM_COINS := 10
const CLAIM_FLIGHT := 0.55


## ⚠️ Les pieces PARTENT de la ligne de mission et ATTERRISSENT sur la bourse,
## en barre haute : elles traversent l'ecran. Elles ne peuvent donc pas vivre
## dans la modale, qui les couperait a son bord. On les pose sur une couche au
## -dessus de tout, et on la retire quand le vol est fini.
func _animate_claim(row: Control, purse: Control) -> void:
	await get_tree().process_frame

	var flight := Control.new()
	flight.name = "CoinFlight"
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(flight)

	var start := row.get_global_rect().get_center()
	var target := purse.get_global_rect().get_center()
	var tween := create_tween().set_parallel(true)

	for index in range(CLAIM_COINS):
		var coin := TextureRect.new()
		coin.texture = load("res://assets/ui/kg_coin.png")
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(18, 18)
		coin.global_position = start
		flight.add_child(coin)

		# L'eparpillement d'abord, le vol ensuite : c'est ce qui fait qu'elles
		# ne partent pas toutes en ligne droite au meme instant.
		var scatter := start + Vector2(randf_range(-40, 40), randf_range(-30, 10))
		var delay := float(index) * 0.03
		tween.tween_property(coin, "global_position", scatter, 0.18).set_delay(delay)
		tween.tween_property(coin, "global_position", target, CLAIM_FLIGHT) \
			.set_delay(delay + 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# La bourse rebondit a l'arrivee - huit impulsions entre 1,09 et 1,14.
	purse.pivot_offset = purse.size * 0.5
	var bounce := create_tween()
	bounce.tween_interval(CLAIM_FLIGHT * 0.7)
	for i in range(4):
		bounce.tween_property(purse, "scale", Vector2(1.12, 1.12), 0.07)
		bounce.tween_property(purse, "scale", Vector2.ONE, 0.07)

	tween.finished.connect(func(): flight.queue_free())
```

⚠️ **`purse` n'est pas dans le popup — il est dans le VILLAGE.** C'est la
pastille d'or de la barre haute (`village._gold_pill`), et c'est ce qui rend
cette animation particulière : elle part d'un écran et atterrit dans un autre.
Le popup est instancié par `village._on_missions_pressed()` : lui passer la
pastille à ce moment-là, plutôt que d'aller la chercher par `get_parent()` — un
popup qui fouille son parent casse dès qu'on l'ouvre d'ailleurs.

⚠️ **Si la pastille n'est pas fournie, ne pas faire voler les pièces** : verser
l'or sans animation vaut mieux qu'un vol vers `Vector2.ZERO`, c'est-à-dire vers
le coin haut-gauche de l'écran.

⚠️ **`flight` est enfant de `root`, pas de la modale.** Il doit être libéré même
si le joueur ferme le popup pendant le vol : brancher aussi la libération sur
`tree_exiting` du popup.

⚠️ **Les pièces sont un enfant de `Control` NU** (`flight`) : c'est
l'**exception** qui autorise à animer leur `position`. Ne pas généraliser.

- [ ] **Étape 5 : relancer, et regarder**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
"$GODOT" --path . tools/resolutions.tscn
```

Puis, à la main : ouvrir les missions, en réclamer une, et vérifier que les
pièces **atteignent la bourse** — sur un écran court comme sur un écran long.
C'est le seul endroit du jeu où une animation traverse deux calques.

- [ ] **Étape 6 : commit**

```bash
git add scenes/village/mission_popup.gd tools/ui_test.gd
git commit -m "Les missions : l'ouverture et la reclamation sont deux animations"
```

---

## Tâche 10 : « COMBATTEZ » et le cerclage d'or

**Fichiers :**
- Modifier : `scenes/battle/battle.gd` (le lettrage)
- Modifier : `scenes/village/building_popup.gd` (l'état verrouillé)

**Interfaces :**
- Consomme : rien.
- Produit : rien de public.

Deux morceaux d'apparence pure, réunis parce qu'ils sont petits et qu'ils se
prouvent avec la même capture.

- [ ] **Étape 1 : relever le lettrage dans la maquette**

`get_design_context` sur `05_Bataille_Combat` (`410:3764`). Relever : la
police, le corps, la couleur, l'ombre, et **la durée pendant laquelle le mot
reste** — c'est la seule valeur qui change ce que le joueur ressent.

⚠️ Si la maquette ne donne pas de durée, en choisir une et **l'écrire dans
`Balance.COMBAT`** : c'est une durée que le joueur voudra régler, donc c'est du
gameplay (règle 1).

- [ ] **Étape 2 : écrire le test**

```gdscript
	# Le lettrage d'ouverture barre le plateau, puis s'efface. S'il reste, il
	# masque le premier coup.
	_check(battle.find_child("OpeningWord", true, false) != null,
		"le lettrage COMBATTEZ apparait au lancement")
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(10.0)
	await _frames(2)
	var word := battle.find_child("OpeningWord", true, false)
	_check(word == null or word.modulate.a < 0.01, "il s'efface tout seul")
```

À insérer dans le bloc bataille existant de `tools/ui_test.gd`, juste après le
lancement du combat.

- [ ] **Étape 3 : le lancer pour vérifier qu'il échoue**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
```

Attendu : `ECHEC le lettrage COMBATTEZ apparait au lancement`.

- [ ] **Étape 4 : poser le lettrage**

Dans `scenes/battle/battle.gd`, au démarrage du combat :

```gdscript
## LE LETTRAGE D'OUVERTURE - il barre le plateau une seconde, puis s'efface.
##
## Apparence pure, relevee sur 05_Bataille_Combat (410:3764). Il marque le
## passage du placement au combat : sans lui, le joueur pose sa derniere piece
## et se retrouve deja en train de jouer, sans transition.
##
## ⚠️ Enfant de Safe/Overlay, un Control NU : c'est ce qui autorise a animer sa
## position (l'exception du piege n1).
func _show_opening_word() -> void:
	var word := UiTheme.make_label("COMBATTEZ", 40, UiTheme.GOLD)
	word.name = "OpeningWord"
	word.add_theme_font_override("font", UiTheme.font_display())
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.size_flags_horizontal = Control.SIZE_FILL
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(word)
	word.set_anchors_preset(Control.PRESET_CENTER)

	await get_tree().process_frame
	word.pivot_offset = word.size * 0.5
	word.scale = Vector2(1.35, 1.35)
	word.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(word, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(word, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(Balance.COMBAT.get("opening_word_seconds", 0.9))
	tween.tween_property(word, "modulate:a", 0.0, 0.30)
	tween.tween_callback(word.queue_free)
```

⚠️ **`UiTheme.make_label` pose `SIZE_EXPAND_FILL` et l'autowrap** : les deux
lignes qui les annulent ne sont pas décoratives. Sans elles, « COMBATTEZ » se
replie sur plusieurs lignes.

- [ ] **Étape 5 : cercler d'or le popup verrouillé**

Dans `scenes/village/building_popup.gd`, l'état verrouillé :

```gdscript
	# LA MAQUETTE CERCLE D'OR le cadre verrouille (10-popup-batiment-verrouille,
	# 410:7488), la ou le jeu le laissait en bordure sourde. Ce n'est pas de la
	# decoration : un batiment verrouille est ce que le joueur VEUT, et un
	# cadre gris se lit comme "indisponible pour toujours".
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(2)
```

⚠️ Poser cette bordure **uniquement** sur l'état verrouillé. Les trois autres
états du même fichier gardent la leur — `building_popup.gd` couvre les quatre
dans une seule scène.

- [ ] **Étape 6 : relancer et regarder**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
"$GODOT" --headless --path . tools/smoke_test.tscn
"$GODOT" --path . tools/resolutions.tscn
```

Comparer `combat_*.png` et `popup-verrouille_*.png` à leurs frames.

- [ ] **Étape 7 : commit**

```bash
git add scenes/battle/battle.gd scenes/village/building_popup.gd scripts/data/balance.gd tools/ui_test.gd
git commit -m "Le mot qui ouvre le combat, et l'or autour de ce qui est verrouille"
```

---

## Tâche 11 : la peau de la boutique

**Fichiers :**
- Modifier : `scenes/village/shop.gd`
- Créer : `assets/shop/*.png` (les illustrations)

**Interfaces :**
- Consomme : l'entrée animée (tâche 8).
- Produit : rien de public.

**C'est le gros morceau de G.** L'écran est fonctionnel et mesuré (chantier H
terminé), mais **brut** : ses neuf illustrations sont des glyphes tracés au
trait.

- [ ] **Étape 1 : relever les neuf illustrations**

`get_design_context` sur `shop-screen` (`410:7061`), puis `download_assets`.

⚠️ **Prendre les `rawImages`, jamais les `export`.** Un export de nœud arrive
avec le fond de la frame cuit dedans, alpha entièrement opaque — vérifié encore
sur le picto de boutique. Si seule une version exportée existe, redécouper
l'alpha après coup.

- [ ] **Étape 2 : les importer**

```bash
"$GODOT" --headless --path . --import
```

⚠️ **Godot ne réimporte pas un asset remplacé** quand on lance le jeu en ligne
de commande. Sauter cette étape fait afficher l'ancienne image sans aucun
message d'erreur.

- [ ] **Étape 3 : vérifier l'alpha avant de brancher quoi que ce soit**

Pour chaque PNG, confirmer qu'il a de la transparence :

```bash
python -c "
from PIL import Image
import glob
for f in sorted(glob.glob('assets/shop/*.png')):
    im = Image.open(f).convert('RGBA')
    a = im.getchannel('A')
    print(f, im.size, 'min alpha', a.getextrema()[0])
"
```

Attendu : `min alpha 0` sur chaque fichier. **Un `min alpha 255` signale un
export non détouré** — reprendre l'étape 1 avec l'image source.

- [ ] **Étape 4 : remplacer les glyphes par les images**

Dans `scenes/village/shop.gd`, remplacer chaque `Icon` de carte par un
`TextureRect` en `STRETCH_KEEP_ASPECT_CENTERED`.

⚠️ **`shop.gd` a son `_text()` maison qui coupe l'autowrap**, et c'est une
correction payée : dans une pastille de 66 points, « 145 » se repliait **à un
caractère par ligne**, la pastille triplait de hauteur et l'en-tête s'étirait
avec elle. Garder ce réflexe pour tout libellé neuf.

- [ ] **Étape 5 : relancer les trois bancs**

```bash
"$GODOT" --headless --path . tools/ui_test.tscn
"$GODOT" --headless --path . tools/shop_probe.tscn
"$GODOT" --path . tools/resolutions.tscn
```

`ui_test` couvre les coffres gratuits, l'achat de coffre et les packs d'or :
**une reprise graphique qui casse un bouton ne se voit sur aucune capture.**

- [ ] **Étape 6 : commit**

```bash
git add scenes/village/shop.gd assets/shop
git commit -m "La boutique cesse d'etre dessinee au trait"
```

---

## Tâche 12 : clôture — les documents disent la vérité

**Fichiers :**
- Modifier : `CLAUDE.md`, `chantier_g_f.md`, `passation_g_f.md`,
  `figma_contexte_projet.md`, `README.md`

**Interfaces :**
- Consomme : tout ce qui précède.

- [ ] **Étape 1 : lancer les quatre bancs, une dernière fois**

```bash
"$GODOT" --headless --path . tools/format_test.tscn
"$GODOT" --headless --path . tools/ui_test.tscn
"$GODOT" --headless --path . tools/smoke_test.tscn
"$GODOT" --path . tools/resolutions.tscn
```

**Ne rien déclarer terminé avant d'avoir lu ces quatre sorties.** `smoke_test`
doit dire **10/10 batailles gagnables** et que les polices se chargent
vraiment — `UiTheme` retombe **silencieusement** sur Inter gras quand un
fichier manque, et un écran en Inter là où la maquette veut Poppins se lit
« l'intégration n'a pas été faite ».

- [ ] **Étape 2 : fermer Jua**

Aucun code : Jua n'est ni embarquée ni référencée, le jeu rend déjà « ROYAUME »
et « CAMPAGNE » en Inter. Retirer la question de `CLAUDE.md` (« le cas non
tranché »), de `passation_g_f.md` (§7) et l'écrire dans
`figma_contexte_projet.md` comme **une correction demandée au designer** sur
`07-bataille-nulle`.

- [ ] **Étape 3 : mettre `CLAUDE.md` à jour**

- Règle 4 : la liste des écrans convertis, village compris.
- Ajouter `tools/format_test.tscn` au tableau des bancs, avec sa question :
  « la géométrie tient-elle sur les huit formats ? ».
- Ajouter le geste du panneau de développement, là où un lecteur le cherchera.
- Section « Repères visuels » : les **deux** tailles de bouton de coin.

- [ ] **Étape 4 : ajouter le banc au `README.md`**

Il s'adresse à un humain qui veut lancer, jouer, régler, tester. Un banc qui
n'y figure pas ne sera pas lancé.

- [ ] **Étape 5 : écrire ce qui reste**

Dans `chantier_g_f.md`, une section finale : ce que le chantier a livré, **ce
qu'il a laissé**, et les deux questions encore ouvertes (la pastille `Codex`,
`stalemate_is_draw`). Plus le chantier **E**, qui vient après.

⚠️ **Écrire ce qui a été mesuré, pas ce qui était espéré.** Si un écran résiste
encore sur un format, le dire — un document qui se tait sur un défaut le fait
repayer à la fenêtre suivante.

- [ ] **Étape 6 : commit**

```bash
git add CLAUDE.md chantier_g_f.md passation_g_f.md figma_contexte_projet.md README.md
git commit -m "G et F : ce qui est livre, et ce qui reste"
```

---

## Ce que le plan ne couvre pas, et pourquoi

- **Les deux écarts où c'est la maquette qui a tort** (le plateau de 12 rangées,
  l'absence de croix de sortie sur le combat). Déjà signalés au designer dans
  son retour `294:2`. La règle 2 tranche : le jeu garde ses boutons.
- **Le chantier E**, les popups d'accompagnement. Il vient après, sur un jeu
  déjà habillé.
- **`stalemate_is_draw`.** Le joueur doit jouer les deux réglages avant de
  trancher. Sans rapport avec G et F, mais il attend depuis le chantier A.
