# KING'S GAMBIT — Handoff Figma → Godot 4

Tu arrives sur un projet de jeu mobile King's Gambit, un jeu de stratégie fantasy inspiré des échecs. Le Roi a perdu sa Dame (la Reine) ; il reconstruit son armée et enchaîne des batailles pour la retrouver.

Le joueur place son armée avant le combat, puis **joue lui-même chaque coup contre l'IA**, une pièce par camp et par tour, comme aux échecs (tape ou glisser-déposer). Un bouton AUTO laisse l'IA jouer les deux camps pour rejouer vite une bataille déjà gagnée. Un pion mené au bout du plateau devient Dame ; ramenée vivante, elle est stockée à la Tour de la Dame au village et redéployable ensuite.

Le niveau de jeu de l'armée ennemie monte avec la campagne (novice → aguerri → expert, déclaré bataille par bataille dans `Balance.CAMPAIGN`) : les premiers combats doivent être gagnables par quelqu'un qui découvre le jeu. L'armée de départ comprend un cavalier — une armée de pions seuls est une finale d'échecs, donc un mauvais tutoriel — et la dernière bataille offre une Dame à la première victoire.

Un bouton **i** sur l'écran de bataille ouvre l'aide correspondant à la phase en cours (pose et barème des poids ; tour par tour, capture et promotion). C'est le seul endroit du jeu où les règles sont écrites.

Ton : fantasy médiéval, mélancolique mais pas sombre. Aucune violence graphique.

## Contraintes techniques

- Godot 4 (gl_compatibility), portrait uniquement
- Résolution de référence : 393 × 852 points (iPhone), stretch mode canvas_items / expand
- Safe areas iPhone (encoche haut + barre gestuelle bas) à respecter
- Exports : sprites/textures PNG avec alpha, pas de blur lourd ni particules complexes

## Assets fournis

### Pièces d'échecs — SVG (dans pieces/)

Chaque pièce existe en 3 variantes :
- `bleu/` = joueur (allié)
- `rouge/` = ennemi
- `absent/` = grisé/fantôme (slot vide, pas encore recruté)

Fichiers par dossier : `roi.svg`, `dame.svg`, `cavalier.svg`, `fou.svg`, `tour.svg`, `pion.svg`

18 SVG au total. Utilise-les comme Sprite2D ou TextureRect dans Godot.

### Backgrounds — PNG (dans backgrounds/)

| Fichier | Usage | Dimensions originales |
|---|---|---|
| village_background.png | Fond de l'écran Village (01) | 393×852 |
| battlefield_background.png | Fond des écrans Placement (04) et Combat (05) | 393×852 |
| parchment_map.png | Fond parchemin campagne (02) — posé sur des lattes de bois | 363×780 approx |

### Screenshots des écrans (dans screens/)

PNG @2x de chaque écran Figma — utilise-les comme référence visuelle pour reproduire l'UI.

## Palette de couleurs

### Couleurs globales

| Rôle | Hex |
|---|---|
| Fond général / panels | #0f111a |
| Panel foncé | #161926 |
| Panel moyen | #262c3f |
| Bordure | #3d4f6b |
| Texte principal | #e6ecf5 / #f0f3f8 |
| Texte atténué | #8fa0b8 / #a0aabf |
| Or / accent doré | #ffd11a / #ffd700 / #d4af37 |
| Or foncé (texte sur or) | #331f00 |
| Bouton or | #c59b27 |
| Accent joueur (bleu) | #268cd9 / #4f86c6 |
| Danger / ennemi | #c65f5f / #b5514f |
| Succès / gagné | #339940 / #5fb37a |

### Couleurs par pièce

| Pièce | Hex joueur | Hex ennemi |
|---|---|---|
| Pion | #4f86c6 | #b5514f |
| Cavalier | #c96f4f | — |
| Fou | #8f6fc6 | — |
| Tour | #6f9f5f | — |
| Dame | #d8a0d0 | — |
| Roi | #c6a84f | — |

## Typographie

Tout est en Inter (Google Fonts, gratuite). Poids utilisés :
- Inter Black (32px) — titres de section composants
- Inter Bold (11-19px) — noms de bâtiments, boutons, titres
- Inter Semi Bold (10-15px) — status bar, labels, pills
- Inter Medium (11px) — texte secondaire, progression
- Inter Regular (8-14px) — descriptions, texte body

## Les 12 écrans

### 01_Village (écran d'accueil)

- Background : village_background.png avec overlay noir semi-transparent + fondus sur les 4 bords (gradient linéaire noir→transparent)
- Status bar : heure iOS (9:41), icônes status
- Top bar (y:38, h:46) : pills noires arrondies (radius 10) contenant or/niveau/gemmes + bouton settings rond (radius 14)
- Fondu sous la top bar (gradient noir)
- Labels bâtiments : 5 labels positionnés sur la map
  - "CHÂTEAU ROYAL" (x:120, y:445) — texte or #ffd933, fond #0a0d14, radius 14, bordure 1.5px
  - "Caserne des Pions" (x:20, y:272) — texte blanc, même style
  - "Écuries" (x:258, y:272)
  - "Cloître des Fous" (x:30, y:542)
  - "Donjon des Tours" (x:248, y:542)
  - Chaque label a un sub-frame avec pill de niveau + barre de progression (effectif/max)
  - Label verrouillé (x:50, y:685) : "🔒 Forge" grisé + "Château Nv.6 requis" en petit
- Bouton BATAILLE (x:87, y:748, w:219, h:59) : fond or #ffd11a, radius 18, stroke 2px, texte "⚔ BATAILLE" noir 19px bold
- **Code actuel** : l'emplacement verrouillé (x:50, y:685) sert à la **Tour de la Dame** — grisé et "Promeus un pion au bout du plateau" tant qu'aucune Dame n'a été ramenée, puis "N Dames au repos" une fois le bâtiment ouvert. Il n'y a pas de Forge.
- **Halo du Château Royal** : dès qu'une Dame est au repos, un dégradé radial doré en mélange additif (300×300 à partir de x:46, y:246, élargi de 12 % par Dame supplémentaire) respire lentement sous les labels. Le label de la Tour de la Dame affiche le niveau, le nombre de Dames et l'or qu'elles rapportent (+15 % par Dame au repos).
- Bouton DEV (x:362, y:14) : discret, 24×24, radius 4, emoji 🛠

### 02_Campagne (carte de progression)

- Background : lattes de bois horizontales (12 planches h:72, teintes alternées #3b2b1c / #423324 / #4a3b2b, stroke 1px séparation)
- Parchemin : parchment_map.png posé centré (x:15, y:36, w:363, h:780), radius 4, drop shadow (0,4, blur 16, noir 60%)
- Chemin en pointillés : ellipses de 5×5px couleur #66401f (opacity 0.7), traçant un sentier sinueux de bas en haut
- 5 étapes de bataille positionnées sur le chemin :
  - Gagné (3 premières) : cercle vert 30×30 (#339940), stroke 2px, checkmark "✓" blanc 16px + label nom sur fond #1f140a radius 8, texte #d9cca6
  - Disponible (4ème) : cercle or 38×38 (#ffd11a), stroke 3px, glow or (blur 14, spread 2), numéro noir 17px + label texte #ffe580
  - Verrouillé (5ème) : cercle gris 28×28 (#594d38 opacity 0.7), stroke 1.5px, emoji 🔒 11px + label texte #807361
- Progression (x:345, y:14) : pill noire (radius 10, opacity 0.4), texte "3/8" #ccbf99 11px
- Bouton VILLAGE (centré bas, y:800) : fond #261a0d opacity 0.9, radius 14, stroke #604d33 1.5px, drop shadow, "🏠 VILLAGE" texte or 13px

### 03_Preparation_Bataille (briefing)

- Fond #0f111a
- Header (y:44, h:64) : numéro + nom de bataille
- Enemies-Card (x:16, y:187, w:361, h:168) : fond #161926, radius 16, stroke 1px — liste des ennemis
- Player-Card (x:16, y:375, w:361, h:179) : même style — armée du joueur
- Info-Summary (x:16, y:574, w:361, h:89) : fond #161926, radius 16 — or gagnable, taille terrain
- Gold-Button (x:24, y:742, w:345, h:54) : fond #c59b27, radius 12, stroke 2px — "PRÉPARER L'ARMÉE"

### 04_Bataille_Placement

- Background : battlefield_background.png + overlay noir semi-transparent + fondus 4 bords
- Grille (x:17, y:155, w:360, h:496). **La maquette montre 10 × 16 cases ; le code n'utilise pas ces chiffres** : la taille vient de `Balance.CAMPAIGN` (5×7 pour la première bataille, jusqu'à 8×9 pour la dernière) et la taille de case est calculée à partir de la place disponible. Des plateaux réduits sont indispensables depuis que le joueur joue chaque coup au doigt — une case fait alors 45 à 72 points de côté
  - Zone bleue joueur (dernières rangées) : fond bleu opacity 0.28, bordure bleue pointillée 2.5px
  - Zone rouge ennemi (premières rangées) : fond rouge opacity 0.28, bordure rouge pointillée 2.5px
  - Nombre de rangées de déploiement : `Balance.DEPLOY_ROWS` (2)
- Tour-Badge (x:12, y:52, w:169, h:35) : fond bleu #268cd9, radius 12, stroke 1.5px — "PLACEMENT — Tour 0"
- Stats-HUD (x:333, y:390, w:56, h:67) : fond #0d0f1a, radius 12, stroke 1px — compteurs ennemis/alliés
- Control-Panel (y:635, h:189, fond #0f121f) :
  - Header row : "Sélectionne tes unités" texte
  - Chips row : un chip par type possédé (Pion, Cavalier, Fou, Tour — plus Dame si le joueur en a une en réserve) avec icône + compteur
  - Buttons row : "AUTO", "RÉINITIALISER", "COMBATTRE" (or)
  - Gestes : tape une case de la zone bleue pour poser, tape une pièce posée pour la reprendre, glisse-la pour la repositionner (deux pièces qui se croisent échangent leur case)

### 05_Bataille_Combat

- Même grille et background que 04 (identique pour transition fluide)
- Tour-Badge (x:12, y:52, w:86, h:41) : fond or #ffd11a, radius 14, stroke 1.5px — "TOUR 1"
- Stats-HUD (x:333, y:390, w:52, h:73) : compteurs "×6 / ×7"
- Control-Panel (y:747, h:77, fond #111319) :
  - Separator line
  - **Code actuel** : "À toi de jouer" / "L'ennemi joue…", bouton AUTO (bascule en MANUEL quand il est actif) et vitesses (×1/×2/×4). Pas de PAUSE ni de FIN TOUR : le combat attend déjà le joueur entre deux coups
  - Coups légaux de la pièce sélectionnée : pastille bleue sur une case libre, anneau doré autour d'une pièce à prendre ; la case de départ et la case d'arrivée du dernier coup restent surlignées

### 06_Bataille_Victoire

- Grille en arrière-plan assombrie (#0a0c14)
- Victory-Modal (x:24, y:150, w:345, h:507) : fond #161926, radius 20, stroke or 2px
- Titre "VICTOIRE" doré
- Stats list (fond #262c3f, radius 12) : or gagné, pièces perdues, tours
- 3 boutons empilés : Bataille suivante (or), Réessayer (bleu), Village (gris)

### 07_Bataille_Defaite

- Même structure que Victoire
- Defeat-Modal (x:24, y:150, w:345, h:463) : fond #161926, radius 20, stroke rouge 2px
- Titre "DÉFAITE" rouge
- Diviseur ornemental
- Stats + boutons (Réessayer, Village)

### 08_Popup_Chateau

- Background village + overlay sombre
- Castle-Modal (x:24, y:180, w:345, h:398) : fond #161926, radius 16, stroke 2px
- Close-X (cercle #262c3f, radius 999)
- Header : nom + niveau château
- Ornate divider
- Upgrade details (fond #262c3f, radius 12) : coût, durée, bonus
- Upgrade-Button (fond #c59b27, radius 10, stroke 2px)

### 09_Popup_Batiment (recrutement)

- Même structure modale
- Building-Modal (x:24, y:120, w:345, h:352) :
  - Titre bâtiment + niveau
  - Troop detail box (fond #262c3f, radius 12)
  - Options : Recruter + Améliorer

### 10_Popup_Batiment_Verrouille

- Locked-Modal (fond #1a1c29, radius 16, stroke 2px)
- Header avec icône 🔒
- Preview box (#1c1f2e, radius 12) : aperçu du déplacement
- Unlock condition (#262c3f, radius 12) : "Apparaît au Château Nv.X"

### 11_Popup_Amelioration

- Upgrade-Modal (fond #161926, radius 16, stroke 2px)
- Header : nom + "Nv.X → Nv.Y"
- Progress graphic (#262c3f, radius 12) : barre de progression
- Active progress : compte à rebours
- Bonus preview (#1c1f2e, radius 8) : aperçu du niveau suivant

### 12_Composants (référence design system)

- Frame large (800×1600) servant de fiche technique
- Sections : Boutons & Commandes, Badges & Statuts, Jetons & Unités, Cases du Plateau, Exemples de Cartes
- C'est ta bible — reproduis chaque composant en tant que scène Godot réutilisable

## Composants UI à créer en Godot

### Boutons

| Type | Fond | Texte | Radius | Stroke | Usage |
|---|---|---|---|---|---|
| Primaire | Or #ffd11a | #331f00 bold | 18 | 2px or foncé | BATAILLE, COMBATTRE |
| Action Or | #c59b27 | blanc bold | 12 | 2px | Améliorer, Préparer |
| Action Bleu | #268cd9 | blanc | 10 | — | AUTO |
| Secondaire | #262c3f | #e6ecf5 | 10 | 1px #3d4f6b | Réessayer, Annuler |
| Danger | #c65f5f | blanc | 10 | — | Abandonner |
| Discret/Lien | transparent | #8fa0b8 | — | — | Village (retour) |

### Modales

- Fond #161926, radius 16-20, stroke 2px (couleur selon contexte : or/rouge/bleu)
- Close-X : cercle #262c3f radius 999, "✕" blanc
- Diviseur ornemental entre sections
- Cards internes : fond #262c3f, radius 12

### Pills / Badges

- Fond noir ou #262c3f, radius 8-10
- Texte petit (10-12px) semi-bold
- États : vert gagné, or disponible, gris verrouillé

### Barre de ressources (Top bar)

- Pills noires (radius 10) avec icône emoji + valeur
- Espacement horizontal, alignées en haut

### Grille de bataille

- 10×16, cellW=36, cellH=31, position (17, 155) dans le frame 393×852
- Cases alternées (damier) avec stroke fine
- Zones colorées : bleu joueur (opacity 0.28), rouge ennemi (opacity 0.28)
- Pièces : sprites SVG, taille 24px (grandes) ou 18px (pions), centrées dans la case

### Chips de sélection (placement)

- Frame avec icône pièce SVG + nom + compteur
- Fond #161926, radius 8, stroke quand sélectionné

## Architecture Godot recommandée

```
res://
├── assets/
│   ├── pieces/
│   │   ├── bleu/ (roi.svg, dame.svg, cavalier.svg, fou.svg, tour.svg, pion.svg)
│   │   ├── rouge/ (idem)
│   │   └── absent/ (idem)
│   ├── backgrounds/
│   │   ├── village_background.png
│   │   ├── battlefield_background.png
│   │   └── parchment_map.png
│   └── screens/ (screenshots de reference, non integres au build)
├── scenes/
├── scripts/
└── ...
```

## Ordre de travail suggéré

1. Theme Godot (kings_gambit_theme.tres) : configurer Inter + toute la palette
2. Composants UI : boutons, modales, cards, badges, pills — scènes réutilisables
3. Battle Grid : grille 10×16 avec placement de pièces SVG
4. Écran Village (01) : background + labels + bouton bataille
5. Écran Campagne (02) : parchemin sur bois + chemin + étapes
6. Écran Préparation (03) : briefing cards
7. Écran Placement (04) : grille + zones + sélecteur de pièces
8. Écran Combat (05) : même grille, contrôles de vitesse, mode lecture seule
9. Modales (06-11) : victoire, défaite, popups bâtiments
10. Logique de jeu : placement, combat auto, progression, sauvegarde

## Notes importantes

- Les écrans 04 (Placement) et 05 (Combat) partagent exactement la même grille et le même background pour éviter tout "saut" visuel lors de la transition
- La Dame n'est pas recrutée — elle apparaît uniquement par promotion (un pion qui atteint le bout du plateau), et n'est conservée que si elle survit à la bataille : elle rejoint alors la Tour de la Dame au village. Laissée au village elle rapporte +15 % d'or par bataille ; collectionnée, elle permet d'améliorer la Tour (N Dames requises par palier, jamais dépensées)
- Le niveau d'un bâtiment débloque des CAPACITÉS, pas seulement des chiffres : le pion gagne le double pas d'ouverture au niveau 2 (`first_move_range` dans Balance), le cavalier de nouvelles figures de saut
- Le Roi est unique et lié au Château Royal
- Les SVG sont les assets finaux — ne les remplace pas par des placeholders
- Aucune valeur de gameplay ne doit être écrite ailleurs que dans `scripts/data/balance.gd` (tailles de plateau, compositions ennemies, portées, coûts, durées d'animation)
- Tous les fondus (edge fades) sont des gradients linéaires noir→transparent sur les 4 bords de l'écran
