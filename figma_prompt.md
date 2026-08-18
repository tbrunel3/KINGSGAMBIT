# Prompt Figma — King's Gambit (habillage Phase 2)

À copier-coller dans Figma (First Draft / Make, ou en brief pour un designer).
**Les inspirations visuelles sont à ajouter séparément par moi** — ce prompt
décrit uniquement le besoin fonctionnel, pas de direction artistique imposée.

---

## Le jeu en une phrase

King's Gambit est un jeu de stratégie mobile fantasy inspiré des échecs. Le
Roi a perdu sa Dame ; il reconstruit son armée et enchaîne des batailles
automatiques pour la retrouver. Le joueur ne joue que le **placement** avant
chaque combat — le combat lui-même se résout tout seul, comme une simulation
qu'on regarde.

Ton recherché : fantasy médiéval, mélancolique mais pas sombre — un royaume
diminué qui se reconstruit, pas une guerre horrifique. Aucune violence
graphique : la capture d'une pièce est une convention d'échecs, pas une mise
à mort.

## Contraintes techniques (non négociables)

- **Portrait uniquement**, cible iPhone, résolution de référence **393 × 852
  points**, stretch en `canvas_items` / `expand` (donc doit rester lisible si
  étiré sur d'autres formats portrait).
- **Zones de sécurité (safe area)** à respecter en haut et en bas (encoche et
  barre gestuelle iPhone) — rien d'essentiel collé aux bords.
- Rendu final en moteur **Godot 4** (`gl_compatibility`) : les exports
  attendus sont des sprites/textures standards (PNG, si possible avec canal
  alpha), pas de dégradés ou d'effets non reproductibles facilement en temps
  réel (blur lourd, particules complexes).
- Le jeu a 5 écrans, tous doivent partager un seul système visuel cohérent
  (mêmes boutons, mêmes cartes, même typo) — pas un habillage différent par
  écran.

## Ce qui existe déjà (placeholders à remplacer)

Aujourd'hui tout est en formes simples : cercles unis + une lettre, sur fond
sombre. Palette placeholder actuelle (à garder comme base de contraste si
aucune inspiration ne la contredit, sinon à remplacer entièrement) :

| Rôle | Hex |
|---|---|
| Fond général | `#141b28` |
| Panneau | `#1e293b` |
| Panneau clair | `#2c3b52` |
| Bordure | `#3d4f6b` |
| Texte | `#e6ecf5` |
| Texte atténué | `#8fa0b8` |
| Or / accent doré | `#e8c15a` |
| Accent (joueur) | `#4f86c6` |
| Danger | `#c65f5f` |
| Succès | `#5fb37a` |
| Ennemi | `#b5514f` |

Couleurs par pièce (actuellement juste la couleur du cercle) :

| Pièce | Lettre | Hex actuel |
|---|---|---|
| Pion | P | `#4f86c6` |
| Cavalier | C | `#c96f4f` |
| Fou | F | `#8f6fc6` |
| Tour | T | `#6f9f5f` |
| Dame (promotion uniquement) | D | `#d8a0d0` |
| Château / Roi | R | `#c6a84f` |

## Les 5 écrans à concevoir

### 1. Village (écran d'accueil)
- Barre haute : compteur d'or, bouton retour au village (pas de retour ici,
  c'est l'écran racine).
- Carte "Château Royal" en grand, en haut : niveau actuel, nombre d'unités
  déployables.
- Grille 2×2 de **4 bâtiments** : Caserne des Pions, Écuries (Cavalier),
  Cloître (Fou), Donjon (Tour). Chaque carte affiche niveau, effectif
  actuel/max, et un compte à rebours si une amélioration est en cours.
- **États à prévoir par carte bâtiment** : normal / plein (capacité max) /
  amélioration en cours / **verrouillé** (le bâtiment n'existe pas encore,
  affiché grisé avec le niveau de château requis, ex. "Château Nv.2 requis").
- Bouton "BATAILLE" en bas, large, qui indique la prochaine bataille
  débloquée.
- Un bouton "DEV" discret en coin (outils de test réservés au développement —
  esthétique neutre/technique, ne doit pas ressembler à un bouton de jeu).

### 2. Campagne (liste des batailles)
- Liste verticale scrollable de 10 batailles.
- Chaque ligne : numéro, nom, composition ennemie résumée, récompense en or.
- **États** : verrouillée (grisée), débloquée non jouée (mise en avant),
  déjà gagnée (rejouable, badge "déjà gagnée", récompense réduite affichée).
- Bouton retour vers le village.

### 3. Préparation de bataille (briefing)
- Numéro et nom de la bataille.
- Bloc "Armée ennemie" : liste des types/quantités/niveaux ennemis.
- Bloc "Ton armée" : ce que le joueur possède, nombre d'unités déployables
  (dépend du niveau du château).
- Récompense en or, taille du terrain (ex. "8 × 11 cases").
- Bouton "PRÉPARER L'ARMÉE" vers l'écran de placement.

### 4. Bataille — 3 phases dans un seul écran

**a) Placement.** Une grille (taille variable selon la bataille, de 6×8 à
9×12 cases). Zone de déploiement du joueur mise en évidence (3 rangées côté
joueur). Pièces ennemies déjà visibles sur leur zone. Sélecteur de type de
pièce à recruter/placer avec compteur restant. Boutons "Auto" (placement
automatique) et "Réinitialiser". **Aperçu d'ouverture** : une flèche fine
part de chaque pièce vers la case où elle ira à sa première activation — verte
pour le joueur, rouge pour l'ennemi, dorée quand c'est une prise annoncée.

**b) Combat.** Même grille, en lecture seule (pas d'interaction sauf
vitesse/pause). Chaque pièce est un jeton rond avec sa lettre. Une pièce
**promue** (pion devenu Cavalier/Fou/Dame par tirage aléatoire) porte un
liseré doré permanent. Quand une capture a lieu, la case marque brièvement
une croix rouge. Quand une promotion a lieu, **un petit badge flottant monte
et s'estompe au-dessus de la pièce**, affichant le résultat du tirage — il
doit rester compact car plusieurs peuvent s'enchaîner rapidement en fin de
partie. Barre de contrôle en bas : Pause, x1, x2, x4, plus un résumé "Roi X -
Ennemi Y".

**c) Résultat.** Une superposition (modale) apparaît sur le plateau final :
"VICTOIRE" ou "DÉFAITE", or gagné, bataille suivante débloquée le cas
échéant, liste des pièces perdues définitivement. Boutons : Réessayer,
Bataille suivante, Retour au village.

### 5. Popup de bâtiment (recrutement / amélioration / construction)
Une modale par-dessus le village. Contenu variable :
- **Château** : description courte, unités déployables actuelles, bouton
  d'amélioration (coût + durée).
- **Bâtiment débloqué** : effectif actuel/max, description du déplacement de
  la pièce, bouton "Recruter" (coût), bouton d'amélioration (coût + durée +
  ce que le niveau suivant apporte), ou "amélioration en cours" avec compte à
  rebours si applicable.
- **Bâtiment pas encore construit** : aperçu du déplacement une fois
  débloqué, message "Apparaît gratuitement au Château niveau X (actuellement
  Y)" — pas de bouton d'achat, c'est automatique.
- Bouton "Fermer" commun.

## Bibliothèque de composants à livrer

- Bouton primaire / secondaire / danger, états normal-survol-pressé-désactivé
- Carte (bâtiment, bataille) avec ses variantes d'état listées plus haut
- Badge de statut (verrouillé, amélioration en cours, déjà gagné)
- Jeton de pièce : joueur vs ennemi (même silhouette, teinte différente),
  état "promu" (liseré doré), état "sélectionné"
- Case de plateau : normale (2 teintes alternées type damier), zone de
  déploiement joueur, zone de déploiement ennemi, case survolée/sélectionnée
- Flèche d'aperçu d'ouverture (3 variantes : joueur, ennemi, prise)
- Modale de résultat (victoire / défaite)
- Icône ou silhouette par pièce : **Pion, Cavalier, Fou, Tour, Dame**, plus
  une icône Château/Roi pour le bâtiment royal
- Compte à rebours / barre de progression pour les améliorations

## Identité et icônes d'app

Le projet a déjà des exports d'icône PWA (144/180/512 px + icône adaptative)
à remplacer par la version finale une fois le style arrêté — même usage,
juste à re-exporter aux mêmes tailles.

## Ce que je fournirai en plus de ce prompt

Des références visuelles (mood board / captures d'inspiration) seront
ajoutées séparément pour cadrer le style final (medieval-fantasy, low-poly,
peint à la main, pixel art, etc. — à définir par les inspirations, pas par ce
prompt).
