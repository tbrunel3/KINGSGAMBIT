# Le carnet de travaux — la console d'atelier

Le suivi des retours de test : une ligne par défaut signalé, son journal daté et
signé, et un verdict que **le joueur coche lui-même**.

Depuis le 24/08/2026, c'est une **console en trois colonnes** — maquette Figma
[`13:373`](https://www.figma.com/design/YTypQjzEG1JG4w9QZUClVk/Sans-titre?node-id=13-373).

| Colonne | Ce qu'elle porte |
|---|---|
| **Le rail** | les registres (une journée de travail chacun) avec leur avancement, et la métrique moteur — le nettoyage |
| **Le centre** | quatre onglets : *tâches actives*, *à vérifier*, *ordre de marche*, *nettoyage*. Les fiches en cartes |
| **L'inspecteur** | la fiche choisie : ses métriques, ses deux gros boutons de verdict, son journal, le résumé des registres |

**Deux adresses, et c'est voulu :**

| | Où | Ce qu'il sait faire |
|---|---|---|
| **L'artefact** | `https://claude.ai/code/artifact/47c96d8b-a61a-4222-932d-04430c13692f` | se republie tout seul à chaque coche. C'est le carnet vivant |
| **Le dépôt** | `https://tbrunel3.github.io/KINGSGAMBIT/carnet/` | ne publie rien — les coches vont dans le navigateur, et l'export les rend. En échange, **personne ne peut le supprimer** |

L'adresse de l'artefact vit aussi dans `carnet.py` (`ADRESSE`), et `build` la
réimprime : elle s'est déjà perdue deux fois.

---

## La règle principale, en deux moitiés

Elle est du joueur, et elle prime sur tout le reste du fonctionnement.

**1. Je ne travaille pas s'il n'a pas lancé le travail.** Le déclencheur est le
bouton **AU TRAVAIL !** de l'onglet *ordre de marche*. Tant qu'il n'est pas
pressé, je ne prends aucun chantier du carnet de ma propre initiative.

**2. Une fois lancé, je ne m'arrête plus.** Je passe sur tous les chantiers en
boucle, sans attendre les verdicts, **jusqu'à ce qu'il ne lui reste que des
vérifs et des retouches**. Une fiche livrée passe en `attente`, sort de l'ordre
de marche, et l'attend — la reprendre serait refaire un travail non jugé.

Deux freins : le bouton **■ ARRÊTER LE TRAVAIL**, aussi gros que l'accélérateur,
et le **crédit** (voir plus bas).

---

## Pourquoi ce dossier existe

Le premier carnet a été supprimé, et **la liste détaillée des vingt-deux retours
du joueur ne vivait que là** : le dépôt n'en gardait rien. Il a fallu la
reconstruire de mémoire, et les coches du joueur sont perdues.

⚠️ **C'est arrivé une SECONDE fois, le 24/08.** Cette fois `etat.json` a tenu :
rien n'était perdu, et le carnet s'est rebâti tel quel.

D'où la règle : **la source est ici, la copie publiée est un instrument.**

### Les quatre gardes, et ce qu'elles ne peuvent pas faire

**⚠️ Aucune n'empêche la suppression.** La page se republie sous l'identité du
joueur, et la plateforme ne nous appartient pas. Ce qu'elles font, c'est que la
suppression **ne coûte plus rien**.

1. **`etat.json`, versionné.** La source. Elle a déjà sauvé le carnet une fois.
2. **Le miroir local.** ⚠️ *C'est celle qui ferme le vrai trou.* Le trou n'a
   jamais été le carnet — c'est la **fenêtre entre une coche du joueur et ma
   relecture** : pendant ce temps, ses verdicts ne vivent qu'à un endroit. La
   page écrit dans son `localStorage` **avant** de publier, à chaque geste. À
   l'ouverture, elle compare les compteurs d'écriture (`serie`) et propose de
   restaurer si le local est plus frais. *Elle ne restaure JAMAIS toute seule :
   écraser la version servie sans le dire serait le même défaut à l'envers.*
3. **Le mode dépôt.** Le carnet tourne depuis git. Insupprimable.
4. **L'archive horodatée.** `build` dépose la page telle qu'elle part dans
   `carnet/build/archive/`. Filet **local** — `build/` est ignoré par git.

Et une discipline : **vérifier que l'adresse répond avant de republier**
(`WebFetch` dessus). Une suppression se voit alors tout de suite.

---

## Les fichiers

| Fichier | Ce qu'il est |
|---|---|
| `page.html` | la page — style, rendu, verdicts, republication. Un **fragment** : ni doctype ni `meta charset`, c'est l'artefact qui les pose |
| `etat.json` | **le contenu** : registres, fiches, statuts, journaux, crédit. C'est ce qu'on édite |
| `carnet.py` | assemble les deux, récupère ce que le joueur a coché, et publie sur gh-pages |

`build/` est un produit, pas une source : ignoré par git. Il contient
`carnet.html` (pour l'artefact), `apercu.html` (la même page emballée, à
regarder en local) et `archive/`.

### Les trois modes de la page

Confondre les deux derniers — ce que faisait la v4 — rendait le carnet
inutilisable dès qu'il sortait de la plateforme.

| Mode | Quand | Ce qui se passe |
|---|---|---|
| `artefact` | `window.claude` existe | publication automatique à chaque coche |
| `depot` | gh-pages, fichier local | **le joueur coche quand même** ; tout va au miroir, et l'export le rend |
| `lecture` | artefact partagé sans droit d'écriture | les boutons disparaissent |

⚠️ **L'export a deux chemins, un par mode.** Dans l'artefact, un `<a download>`
est **inerte** — le bac à sable bloque toute sauvegarde lancée par la page, il
faut la capacité `downloads`. Depuis le dépôt c'est l'inverse : pas de capacité,
mais le lien marche. Et dans les deux cas, un dernier recours qui ne peut pas
échouer : la zone de texte à copier.

---

## Le cycle normal

```bash
python carnet/carnet.py build
```

puis publier `carnet/build/carnet.html` avec l'outil Artifact **en passant
l'URL de l'artefact dans `url`**.

⚠️ **Sans `url`, un SECOND carnet est créé** — et le joueur continue de cocher
l'ancien pendant qu'on lit le nouveau.

### Avant de republier : récupérer ses coches

1. **`WebFetch` sur l'URL rend le HTML BRUT**, `<script id="state">` compris, et
   l'enregistre dans un fichier dont il donne le chemin.
   ⚠️ **Le navigateur d'agent ne sert à rien ici** : il n'est pas connecté au
   compte du joueur et ne voit qu'une page introuvable.
   ⚠️ **`WebFetch` met en cache 15 minutes par URL.** Une relecture juste après
   une coche peut rendre l'état d'avant — ce n'est pas une preuve.
2. `python carnet/carnet.py recupere <la-page-servie.html>` ;
3. éditer, `build`, republier.

Un `conflict` en publiant veut dire qu'il a coché entre-temps : relire,
fusionner, republier. `force` seulement après avoir vraiment fusionné.

### Mettre le carnet sur le dépôt

```bash
python carnet/carnet.py enligne
```

Bâtit, puis pose `carnet/index.html` sur `gh-pages` **via un worktree** et
commite. Il ne pousse pas : c'est au joueur de décider.

⚠️ **JAMAIS `git checkout gh-pages`.** Cette branche ne contient que le build
web ; la basculer dans l'arbre de travail efface tout le code sous les pieds.

---

## Éditer le contenu

Une fiche :

```json
{
  "ref": "C",
  "titre": "Le glisser-déposer",
  "detail": "Caserne → déploiement. <strong>Le paquet le plus lourd.</strong>",
  "statut": "todo",
  "journal": [
    {"quand": "24/08", "qui": "Claude", "texte": "Prochain sur la liste."}
  ]
}
```

- `detail` accepte du HTML (`<strong>`, `<code>`, `<em>`). Le reste est échappé.
- `qui` : `Claude` ou `Toi`. C'est ce qui colore la signature.
- `statut` : `attente` (à vérifier), `todo`, `encours`, `ok`, `ko`. **C'est lui
  qui pilote la boucle de travail** : `todo`, `ko` et `encours` entrent dans
  l'ordre de marche ; **`attente` en sort**.
- `livre` : `{"commit": "940d5ea", "quand": "24/08 à 03h05"}` — **à remplir en
  même temps qu'on passe une fiche en `attente`.** L'inspecteur en tire le
  *temps d'attente* : depuis combien de temps la ligne l'attend.
- ~~`avancement`~~ — **retiré le 24/08**, à la demande du joueur : « les barres
  d'avancement sont buggées ». Elles l'étaient par construction. Un pourcentage
  **déduit** d'un statut (todo 0, encours 50, attente 90) n'est pas une mesure,
  c'est une invention présentée comme un chiffre : une fiche à peine ouverte
  affichait 50 %. Ce qui reste est **comptable** et ne peut pas mentir —
  combien de fiches validées sur combien.
- `exportWeb` : `{"demande": "24/08 à 15h17"}` — **la demande de mise en ligne,
  et c'est LUI qui la fait.** Exporter le jeu coûte une minute de build web plus
  le déploiement ; le faire après chaque livraison mange la séance pour un test
  qu'il ne fera peut-être pas tout de suite. Le bouton
  **⬆ METTRE EN LIGNE POUR TESTER** vit dans le bandeau de build. Quand
  l'export est fait, remplir `fait` et mettre `build` à jour.
- `theme` : un mot, cliquable, qui sert de filtre. C'est le *module contexte* de
  l'inspecteur.
- `priorite` : `haute`, `moyenne`, `basse`. Le tri est **stable** : deux fiches
  de même priorité gardent l'ordre du fichier.
- `build.enLigne` : **la consigne la plus importante du carnet.** `false` tant
  que le travail n'est pas exporté sur `gh-pages` — bandeau orange, « ne teste
  pas tout de suite ». Une date le fait passer au **bandeau vert COMMIT ET TEST
  POSSIBLE**, demandé mot pour mot par le joueur après avoir testé une version
  d'avant. *La maquette le réduisait à un point de 11 px ; il a tranché qu'il
  restait grand.*

  ⚠️ **Ne pas mettre le carnet à jour avant que le build correspondant soit en
  ligne.** Publier une ligne « fait » sur un build qu'il ne peut pas lancer lui
  fait perdre un test — c'est arrivé le 24/08.

### ~~Le crédit, en bas de la console~~ — retiré

Le joueur : « les données en bas avec le temps de session sont erronées ». Il a
raison, et le défaut était dans la nature de la chose : je ne vois mes tokens
qu'au **début d'un tour**, jamais pendant. Le relevé était donc périmé dès
qu'il l'affichait, et une jauge périmée qui a l'air vivante ment.

**La règle, elle, reste** : sous le seuil, je m'arrête, je commite, j'écris la
passation. Elle n'a simplement plus d'affichage — je la tiens, je ne la mesure
pas à l'écran.

La barre du bas porte désormais ce qui est comptable : combien de fiches
attendent son verdict, combien sont encore ouvertes.

---

## Les repères de la maquette

| Rôle | Hex |
|---|---|
| Fond profond / panneaux / filets | `#060913` · `#0d1424` · `#1c2c4e` |
| Puce de thème / onglet actif | `#14213d` · `#2a4d80` |
| Texte / atténué | `#e2e8f0` · `#6b7c96` |
| Cyan (accent, *en cours*) | `#00d2ff` |
| Ambre (*à vérifier*) | `#f59e0b` |
| Rouge (*cassé*) | `#ef4444` |
| Vert (*validé*) | `#10b981` |

Polices : **Geist Mono** pour tout le méta, **Inter** pour les phrases. C'est ce
contraste qui fait lire la page comme une console. Rail 240, inspecteur 440
(380 sous 1320), cadre de 4 px.

Le logo est le **vrai** `assets/intro/studio_bnl_logo.svg`, inliné en data-URI
dans la feuille de style. ⚠️ Il doit vivre dans `#sheet` ou dans `#app` :
`construireDoc()` ne reconstruit la page qu'à partir de ces deux-là, plus
l'état. **Tout ce qu'on pose ailleurs disparaît à la première republication.**

### Les trois formats, mesurés

Le joueur teste le jeu sur son téléphone. Un carnet qu'il ne peut pas cocher là
où il teste est un carnet qu'il coche plus tard, donc jamais.

| | 1280×900 | 900×800 | 375×812 |
|---|---|---|---|
| Débordement horizontal | 0 | 0 | 0 |
| Chrome avant les fiches | 122 | 236 *(361 avant correction)* | 210 *(471 avant)* |
| Place pour les fiches | 740 | 498 | 465 |
| Rail | 240, vertical | bandeau 56 | bandeau 53 |
| Inspecteur | 380 à droite | 380 à droite | feuille plein écran |

⚠️ **Les deux chiffres qui comptent sont le débordement et le chrome.** Un
chrome de 471 px sur un écran de 812 laissait 204 px de fiches — deux lignes et
demie. Quatre coupables, tous mesurés un par un : le rail en bandeau qui gardait
sa hauteur de colonne (100 px), la barre haute repliée sur trois rangées, le
bandeau de mode, et le paragraphe du build.

---

## Un carnet pour un autre chantier

```bash
python carnet/carnet.py neuf boutique
```

écrit `etat_boutique.json`. Le bâtir avec `ETAT=carnet/etat_boutique.json`, et
le publier **sans** `url` — celui-là est un carnet neuf, et c'est voulu. Noter
sa nouvelle adresse ici même.
