# Passation — l'intro finie, et ce que coûte l'atelier en session cloud

**Ce document existe pour la fenêtre qui arrivera à froid après le 24/08/2026
au soir.** Il dit où en est le carnet, ce qui reste vraiment ouvert, et surtout
**les six pièges d'environnement payés dans cette session** — dont trois qui ne
sont dans aucun autre fichier, et qui font perdre une heure chacun.

Lis [`CLAUDE.md`](CLAUDE.md) d'abord, puis [`carnet/README.md`](carnet/README.md).
Ce document ne les répète pas ; il les prolonge sur ce qu'ils n'avaient pas.

---

## ⚠️ L'ORDRE DE MARCHE EST VIDE, ET C'EST LA CONDITION D'ARRÊT

Au 24/08 22h15 : **14 fiches validées, 6 en attente de verdict, 0 `todo`, 0
`encours`.**

La règle principale du carnet dit de boucler sur les chantiers *jusqu'à ce
qu'il ne lui reste que des vérifs et des retouches*. **C'est le cas.** Ne
rouvre pas une fiche en `attente` pour « avancer » : la reprendre serait
refaire un travail qu'il n'a pas encore jugé, et c'est explicitement interdit
par le README du carnet.

Les six qui l'attendent : **D** (animations), **E** (habillage), **5** (les
lettres du Roi), **6** (popups d'accompagnement), **n1** (l'intro), **n2**
(bouton COMBATTEZ).

### Les deux seules choses réellement ouvertes

1. **E4 — les missions « très modestes ».** La fiche le dit elle-même : « à
   préciser quand on y arrivera ». **Ne l'invente pas.** Il a été relancé et
   n'a pas répondu : la question posée était « la liste ? les récompenses ?
   l'écran entier ? ». Tant qu'il n'a pas tranché, il n'y a pas de chantier.
2. **Le build web n'est pas réexporté.** Le dernier en ligne est celui du
   **24/08 21h05, sur `682595b`** — il ne contient donc **ni n1 finie, ni le
   nettoyage**. Le bandeau du carnet est **orange**, et c'est volontaire.

⚠️ **Sa règle, mot pour mot : ne pas pousser une ligne dans le carnet avant que
le build correspondant soit lançable.** Publier « fait » sur un build qu'il ne
peut pas lancer lui fait perdre un test — c'est arrivé le 24/08, et il a
demandé le bandeau vert **COMMIT ET TEST POSSIBLE** pour ça.

---

## Ce qui a été fait dans cette session

Sept commits, de `6ff5016` à `36ba810`, sur `claude/carnet-travail-tache-r2ac6b`.

### n1 — l'intro est finie

Le blocage n'était pas celui que le carnet annonçait. Détail dans les pièges
ci-dessous ; le résultat : **le joueur a exporté le PNG lui-même** (commit
`e76a2e6`, sous le nom `solitaire.png`), renommé en
`assets/intro/king_before_dialogue.png`.

**852 × 1846, rapport 0,4615 quand l'écran fait 0,4613** — en
`KEEP_ASPECT_COVERED` elle ne perd quasiment rien sur les bords. L'ancienne
(`king_throne_background.png`, 864 × 1821, 0,4745) se faisait rogner davantage.

Vérifié **sur les captures réelles, pas en lisant le code** :

| Capture | Ce qu'elle montre |
|---|---|
| `9a_intro_approche` | le Roi accablé, la main au visage, le trône **vide** de la Dame, et l'invite « S'APPROCHER DU TRÔNE › » |
| `9_intro_typing` | le fondu a basculé, la frappe est en cours, COMMENCER est encore grisé |
| `9_intro_ready` | le Roi redressé, cadré par le zoom, la bulle et COMMENCER débloqué |

**Le fondu `_swap_to_speaking_king` ne s'était jamais joué jusqu'ici** — il
n'avait pas de seconde image à fondre. C'est du code neuf en pratique, même
s'il était écrit depuis la veille.

### Le nettoyage de `king_intro_dialogue.gd`

Demandé par le joueur. Quatre résidus, **tous confirmés par le code autour
avant d'y toucher** :

- `_fade_overlay` **et son nœud `FadeOverlay` dans la `.tscn`** — restes du
  fondu local retiré quand il a demandé « un petit fade in sur l'ouverture sur
  le village ». Le `ColorRect` était encore là, transparent, tenu en vie par
  une seule référence que personne ne lisait.
- `FADE_DURATION` — plus lue. Le commentaire de `BG_SWAP_DURATION` s'en
  réclamait alors que les deux valeurs diffèrent déjà (0,45 / 0,4).
- `SETTLE_SCALE` / `SETTLE_DURATION` — deux mesures Figma relevées et jamais
  appliquées.
- Une phrase répétée deux fois en tête sur `has_seen_intro`.

⚠️ **La règle qui a guidé ce nettoyage, et qu'il faut garder : le code mort
part, la MESURE reste.** Les deux constantes Figma sont passées dans le bloc
`TIMELINE FIGMA`, à la place qui liste ce qui n'est **pas** repris de la
maquette, avec la raison qui manquait — *le zoom ambiant part de 1 et monte,
une pose qui descend juste avant l'inverserait sous les yeux du joueur*.

Supprimer un commentaire de ce fichier, c'est supprimer un piège payé. La
détection de code mort ne rend plus que `_ready` (appelé par Godot) et
`skip_approach` (appelé par `screenshot.gd`).

---

## Les six pièges payés, avec leurs chiffres

### 1. ⚠️ Godot n'est PAS installé en session cloud, et rien ne le dit

`which godot` ne rend rien. Aucun banc n'est lançable tant qu'on ne l'a pas
posé — et il est trop facile de conclure « je ne peux pas mesurer » et de
livrer sans preuve.

Le conteneur autorise `github.com`, donc c'est une commande (75 Mo, ~30 s) :

```bash
curl -sSL -o /tmp/godot.zip \
  https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip -q /tmp/godot.zip -d /tmp && chmod +x /tmp/Godot_v4.7-stable_linux.x86_64
```

**Prendre 4.7.** `project.godot` déclare `config/features` en `4.7` ; 4.5 et
4.6 se téléchargent aussi bien et mesureraient autre chose que le jeu.

### 2. ⚠️ Le proxy de sortie refuse `figma.com` — ce n'est PAS un défaut de droits

Mesuré : **403 au CONNECT** sur `www.figma.com`, `api.figma.com` et
`s3-alpha-sig.figma.com`, pendant que `github.com` répond. C'est une liste
d'autorisation d'egress qui ne contient pas Figma, et
`/root/.ccr/README.md` **interdit de la contourner**.

**Le serveur MCP Figma, lui, marche parfaitement** — il ne sort pas par ce
proxy. D'où une conséquence précise et piégeuse :

> **On peut LIRE la maquette (`get_metadata`, `get_screenshot`,
> `get_design_context`) et pas RAPATRIER un fichier.** Les URLs que rend
> `download_assets` sont sur `figma.com`.

Tout asset à poser dans le dépôt demande donc un export fait **hors de cette
session**. C'est ce qui a bloqué n1 pendant deux sessions.

### 3. ⚠️ Le siège Figma n'est plus VIEW — ne pas recopier le vieux diagnostic

Une session d'avant a écrit dans le carnet « le compte est en siège VIEW, il
faut les droits d'édition ». C'était vrai à ce moment-là et **ça ne l'est
plus** : `whoami` rend `tbrunel3@gmail.com`, siège **Full**, et la maquette se
lit sans rien demander.

Les deux causes échouent en donnant un **403**, et c'est ce qui les fait
confondre. **Lancer `whoami` AVANT d'accuser le siège.**

### 4. ⚠️ Bâtir le carnet depuis un clone frais l'ampute, en silence

Deux manques indépendants, et **aucun n'arrête `build`** :

- `tools/screenshots/` est **ignoré par git** (`.gitignore:27`) : un conteneur
  qui vient de cloner n'a aucune capture.
- **Pillow peut ne pas être là.** Sans lui, `build` écrit une ligne d'alerte au
  milieu de sa sortie normale, **puis continue** et rend une page valide.

Mesuré : la page fait alors **124 Ko au lieu de 232**, et republier **efface la
galerie des 35 écrans**. Le seul témoin est le chiffre : `build` annonce
`galerie : 35 ecrans embarques` quand tout va bien, et rien du tout sinon.

```bash
pip install Pillow
xvfb-run -a --server-args="-screen 0 800x1200x24" godot --path . tools/screenshot.tscn
python carnet/carnet.py build   # doit dire : galerie : 35 ecrans embarques
```

### 5. ⚠️ `serie` ne se touche JAMAIS à la main

`build` l'incrémente lui-même (`carnet.py:254`), et c'est ce compteur qui
arbitre entre la page publiée et la source. J'ai ajouté deux `+1` en éditant
`etat.json`, sans le savoir.

**Sans conséquence cette fois, et c'est instructif :** `recupere` a refusé la
fusion tout seul en voyant la page à 95 et la source à 97, **et a listé ce
qu'elle aurait écrasé** (`n1 source attente -> page encours`). L'outil est bien
fait ; l'écart n'en ment pas moins sur le nombre de builds.

### 6. ⚠️ Une capture peut photographier un écran qui n'existe pour personne

`9a_intro_approche` était prise **à 0,6 s**, alors que l'invite n'arrive
qu'après `HINT_DELAY` (**1 s**) puis met **0,8 s** à monter à 0,7. Elle
photographiait donc l'écran pendant que l'invite valait **exactement 0** — un
état qui n'existe à aucun moment pour le joueur.

C'est le piège n°2 des animations que le manuel décrit déjà, sur un chemin qui
n'avait pas été bouché. **Et `_finish_animations` ne pouvait pas servir là** :
la respiration de l'invite est une boucle **infinie**, et la pousser de dix
secondes la laisse à un point arbitraire de son cycle. L'attente se lit
maintenant sur `intro.HINT_DELAY`, pas sur un chiffre écrit à la main.

### Bonus — un asset livré arrive sous le nom de son export

Le joueur a commité `solitaire.png`. Le code attendait
`king_before_dialogue.png`. **Ne pas changer la constante pour coller au nom
livré** : les assets du dossier portent leur **rôle**, c'est ce qui les rend
trouvables depuis le code. Renommer le fichier, et le dire.

---

## Les mesures à relancer

Toutes vertes au 24/08 22h10, sur Godot 4.7, **0 `SCRIPT ERROR` sur les
trois** :

| Banc | Verdict |
|---|---|
| `tools/ui_test.tscn` | 19 cas, toutes les interactions répondent |
| `tools/format_test.tscn` | les huit formats, 0,00 pt de dérive |
| `tools/smoke_test.tscn` | 10/10 batailles, 17 promotions |
| `tools/screenshot.tscn` (xvfb) | 35 captures |

⚠️ Rappel du manuel, qui a resservi ici : **un banc vert peut avoir sauté la
moitié de ses questions.** Compter les `SCRIPT ERROR` séparément du verdict —
rien ne les compte à la place.

---

## Si le joueur redonne la main

1. **Relire l'artefact** (`Artifact action:"read"`), puis
   `carnet.py recupere <la-page>`. Ses coches ne réveillent personne : c'est le
   défaut le plus coûteux du carnet, et il lui a déjà fait perdre deux heures.
2. Regarder ses verdicts sur les six fiches en attente. Un `ko` rouvre un
   chantier ; un `ok` le replie.
3. S'il demande l'export web, le faire **avant** de toucher au bandeau.

L'adresse du carnet :
`https://claude.ai/code/artifact/47c96d8b-a61a-4222-932d-04430c13692f`
