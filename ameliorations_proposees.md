# Améliorations proposées — relevé du 25/08/2026

Écrit après le nettoyage du dépôt, en ayant lu le code de bout en bout.
**Rien ici n'est engagé** : c'est une liste de propositions, à trier par le
joueur. Le travail en cours reste celui du carnet (`d3`, `D`, `E`).

Chaque ligne dit **sur quoi elle se fonde**. Je sépare volontairement :

- **MESURÉ** — un banc ou le code donne le chiffre. Ce n'est pas une opinion.
- **CONSTATÉ** — le code contient ou ne contient pas la chose. Vérifiable en une
  commande, mais l'impact sur le joueur reste un jugement.
- **HYPOTHÈSE** — mon avis de conception. À prendre comme tel, et à confirmer sur
  un téléphone avant d'y passer du temps.

---

## 1. Ce qui manque au ressenti (le plus gros écart, et le moins cher)

| # | Proposition | Fondement | Ce que ça change | Effort |
|---|---|---|---|---|
| **A1** | **Le jeu n'a AUCUN son.** Zéro `AudioStreamPlayer`, zéro `AudioStream` dans tout le dépôt, aucun dossier `assets/audio`. | **CONSTATÉ** — `grep -rl 'AudioStream' .` ne rend rien | Une capture sans bruit ne se ressent pas. C'est le plus gros manque sensoriel du jeu, et le moins cher à combler : cinq à huit sons (poser, capturer, promouvoir, victoire, défaite, ouverture de popup) suffisent à changer le jeu de catégorie | **moyen** |
| **A2** | **Aucun retour haptique.** `Input.vibrate_handheld()` n'apparaît nulle part. | **CONSTATÉ** | Sur téléphone, une capture doit se *sentir*. Une vibration de 20-40 ms sur capture et promotion, une plus longue sur la fin de combat. C'est une ligne de code par événement, réglée depuis `Balance` | **très faible** |
| **A3** | Un **son + haptique de refus** quand un coup illégal est tenté | HYPOTHÈSE (dépend de A1/A2) | Aujourd'hui un coup refusé ne produit rien du tout : le joueur ne sait pas s'il a mal visé ou si le coup est interdit | faible |

> ⚠️ Si une seule chose est retenue de cette page, c'est **A2** : quelques
> lignes, aucun asset à produire, et c'est le retour le plus immédiat sur un
> téléphone.

---

## 2. Le combat

| # | Proposition | Fondement | Ce que ça change | Effort |
|---|---|---|---|---|
| **B1** | **Trancher `stalemate_is_draw`.** Il traîne depuis le chantier A et n'a jamais été joué dans les deux réglages. | **MESURÉ** — à `true`, **6 des 19 parties du banc finissent nulles**, bataille 1 comprise | Presque un tiers des parties se termine sans vainqueur, le plus souvent alors que le joueur *mène largement* et que l'ennemi est réduit à trois pions bloqués. C'est frustrant au moment exact où le joueur devrait être récompensé. À `false`, figer l'adversaire devient une victoire — et le pat cesse d'être une punition du gagnant | **nul** (un booléen) + une soirée de test |
| **B2** | **Le cavalier Nv.1 ne quitte jamais la couleur de sa case** (saut diagonal d'une case). Deux cavaliers Nv.1 sur des couleurs opposées ne peuvent structurellement jamais se prendre. | **MESURÉ** — c'est la cause documentée des positions mortes | Lui donner un pas orthogonal dès le Nv.1, ou faire commencer les cavaliers sur des couleurs opposées, supprimerait une famille entière de nuls. À arbitrer contre la lisibilité de la pièce | moyen |
| **B3** | **Quitter en plein combat le fait recommencer.** La série survit à la fermeture, le combat non. | **CONSTATÉ** — `campaign_run.gd:32` | C'est la friction mobile la plus coûteuse : un appel, une notification, une batterie vide, et dix minutes de combat sont perdues. Sauver l'état du plateau (positions + camp au trait suffisent, le jeu n'a aucun aléa) rendrait le jeu réellement jouable dans les transports | **élevé** |
| **B4** | **Le joueur ne choisit pas la difficulté.** `AI_DEPTH` est fixé par bataille. | CONSTATÉ | Trois profondeurs existent déjà et sont mesurées comme réellement plus fortes l'une que l'autre (`ai_bench` : chaque demi-coup gagne les six duels). Les exposer coûte presque rien et donne de la rejouabilité | faible |
| **B5** | Un **compteur visible « X tours sans prise »** avant l'enlisement | HYPOTHÈSE | Le badge annonce déjà la position morte. L'enlisement, lui, tombe sans prévenir au bout de `stalemate_rounds_manual` tours : le joueur subit un verdict qu'il n'a pas vu venir | faible |

---

## 3. La progression

| # | Proposition | Fondement | Ce que ça change | Effort |
|---|---|---|---|---|
| **C1** | **Vérifier que la Dame n'est pas devenue trop rare.** Le réglage l'a fait passer de 8 à 2 par campagne. | **MESURÉ** — `promo_probe` : 8 → 2 | Le manuel pose lui-même le garde-fou : « elle ne doit pas devenir inaccessible, sinon le Château Royal et l'aura redeviennent du contenu mort ». À 2 par campagne dont 1 offerte à la bataille 10, il n'en reste **qu'une** vraiment gagnée. Relancer `promo_probe` et regarder si le Château sert | **nul** (relancer un banc) |
| **C2** | **Une défaite ne coûte rien d'autre que l'or promis.** | CONSTATÉ — `GameState` compte `defeats` mais ne s'en sert que pour les missives | Perdre une série est sans conséquence durable : on recommence à l'identique. Un coût — même symbolique — donnerait du poids au risque. ⚠️ À manier avec précaution : c'est exactement le genre de règle qui rend un jeu mobile pénible | moyen |
| **C3** | **L'or dormant en fin de campagne** avait été mesuré à 33 593 sur 55 530 encaissés sur une variante écartée. Refaire la mesure sur le réglage actuel. | **MESURÉ** (sur une variante abandonnée) | « Combien reste-t-il en poche à la fin » est le second chiffre que le manuel demande de lire, et il n'a pas été relu depuis. Une économie dont on ne dépense que 40 % n'a plus de décisions dedans | **nul** (relancer `economy_probe`) |

---

## 4. L'interface

| # | Proposition | Fondement | Ce que ça change | Effort |
|---|---|---|---|---|
| **D1** | **Auditer les quatre `ScrollContainer` restants** (préparation, codex, boutique, showcase) | **CONSTATÉ** — c'est la fiche `d3` du carnet, déjà à l'ordre de marche | C'est le patron exact qui a produit le bug des cachets : un enfant cliquable en `MOUSE_FILTER_STOP` avale le geste, et la page ne défile plus. Le bug a déjà été payé une fois sur la carte | moyen |
| **D2** | **Aucun banc ne joue un geste dans le combat.** Le cas `[12]` de `ui_test` ne couvre que la carte de campagne. | **CONSTATÉ** | La grille est l'écran où le joueur passe le plus de temps, et c'est le seul dont le tactile n'est vérifié par rien. `_DRAG_THRESHOLD` vaut 8 pt (le *touch slop* standard d'Android) : la valeur est bonne, mais rien ne prouve que le geste arrive jusqu'à elle | moyen |
| **D3** | **Vérifier le contraste de l'anneau rouge sur les pièces rouges** | HYPOTHÈSE | L'anneau de menace est rouge, et l'ennemi aussi. Le signal qui porte « toute la tension du jeu » est peut-être le moins lisible sur les pièces qu'il désigne. Se vérifie en une capture | **très faible** |
| **D4** | Une **option « pièces en lettres »** ou un second marqueur de camp (forme, liseré) | HYPOTHÈSE | Bleu contre rouge tient pour la plupart des daltonismes, mais un liseré différencié coûte peu et enlève le doute | faible |

---

## 5. La santé du code (pour moi, pas pour le joueur)

| # | Proposition | Fondement | Ce que ça change | Effort |
|---|---|---|---|---|
| **E1** | **`economy_probe` a DÉJÀ divergé des trois autres bancs** : il itère `ARMY_TYPES` là où `tune_probe`, `series_probe` et `smoke_test` itèrent `UNIT_TYPES`, et il fait `pool.get(type, 0)` là où les autres font `pool[type]` — comportement différent sur clé absente. | **MESURÉ** — audit du 25/08 | Le manuel exige que les bancs « parlent de la même armée, sinon leurs chiffres ne se comparent pas ». Les commentaires de `tune_probe` et `economy_probe` promettent tous deux d'être « identiques à `smoke_test` ». **Ils mentent déjà.** La formation de référence vit en **quatre exemplaires** (~48 lignes), le montage du moteur en **dix** (~99 lignes) | moyen |
| **E2** | **`GameState.combat_capacity()` n'a aucun appelant**, alors que son corps est recopié dans `battle.gd` et `battle_prep.gd`. | **MESURÉ** — audit du 25/08 | La règle de la charge gelée — celle qui empêche une amélioration en cours de série d'annuler toute l'usure — existe en **trois exemplaires libres de diverger**. ⚠️ Le branchement n'est PAS trivial : `battle_prep` tient un `CampaignRun` *provisoire* que `Game.current_run()` ne voit pas | moyen |
| **E3** | **Le signal `upgrade_finished` est émis sans un seul auditeur.** | **MESURÉ** | Soit c'est un point d'extension délibéré (le garder coûte 3 lignes), soit un écran qui devait s'y raccrocher ne l'a jamais fait. À trancher, pas à supprimer d'office | **très faible** |
| **E4** | **`.git` pèse 191 Mo** à cause des builds web commités (`index.wasm` 37,7 Mo, quinze `index.pck`). | **MESURÉ** | Un clone neuf télécharge 191 Mo pour 1 Mo de code. Les purger ferait tomber le dépôt sous 40 Mo, **mais exige une réécriture d'historique et un force-push, que le garde-fou interdit explicitement**. À ne faire qu'en décision consciente, une fois, en prévenant toutes les machines | élevé |

---

## Si je devais n'en garder que cinq

| Ordre | Quoi | Pourquoi celui-là |
|---|---|---|
| 1 | **A2** — la vibration | Quelques lignes, aucun asset, effet immédiat au doigt |
| 2 | **B1** — trancher `stalemate_is_draw` | Un booléen, et **32 % des parties** en dépendent |
| 3 | **C1 + C3** — relancer `promo_probe` et `economy_probe` | Deux bancs à relancer, zéro code : ils diront si la Dame et l'or sont encore bien réglés |
| 4 | **A1** — le son | Le plus gros écart de ressenti, mais il demande des assets |
| 5 | **B3** — reprendre un combat interrompu | Le plus cher des cinq, et celui qui décide si le jeu se joue vraiment dans les transports |
