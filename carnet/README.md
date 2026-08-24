# Le carnet de travaux

Le suivi des retours de test : une ligne par défaut signalé, son journal daté
et signé, et un verdict que **le joueur coche lui-même** — « Ça marche » ou
« Toujours cassé ». Les lignes validées se replient.

**Le carnet vivant est ici :**
`https://claude.ai/code/artifact/857ffdc3-e16a-485b-8651-853b31916069`

---

## Pourquoi ce dossier existe

Le premier carnet a été supprimé, et **la liste détaillée des vingt-deux
retours du joueur ne vivait que là** : le dépôt n'en gardait rien. Il a fallu
la reconstruire de mémoire, et les coches du joueur sont perdues.

D'où la règle : **la source est ici, la copie publiée est un instrument.**
Une liste qui n'existe que dans un artefact n'existe qu'à moitié.

---

## Les trois fichiers

| Fichier | Ce qu'il est |
|---|---|
| `page.html` | la page — style, rendu, verdicts, republication. Elle ne change presque jamais. |
| `etat.json` | **le contenu** : sections, fiches, statuts, journaux. C'est ce qu'on édite. |
| `carnet.py` | assemble les deux, et récupère ce que le joueur a coché. |

`build/` est un produit, pas une source : il est ignoré par git.

---

## Le cycle normal

```bash
python carnet/carnet.py build
```

puis publier `carnet/build/carnet.html` avec l'outil Artifact **en passant
l'URL ci-dessus dans `url`**.

⚠️ **Sans `url`, un SECOND carnet est créé** — et le joueur continue de cocher
l'ancien pendant qu'on lit le nouveau. C'est le genre de défaut qui se voit
trois jours plus tard.

### Avant de republier : récupérer ses coches

La page **se republie elle-même sous l'identité du joueur** à chaque verdict.
Le `etat.json` du dépôt vieillit donc dès qu'il touche un bouton. Republier
sans relire, c'est effacer ses réponses.

1. **`WebFetch` sur l'URL du carnet rend le HTML BRUT**, `<script id="state">`
   compris — vérifié le 24/08. C'est le chemin normal. Enregistrer la réponse
   dans un fichier.
   ⚠️ **Le navigateur d'agent, lui, ne sert à rien ici** : il n'est pas connecté
   au compte du joueur et ne voit qu'une page introuvable.
   ⚠️ **`WebFetch` met en cache 15 minutes par URL.** Une relecture juste après
   une coche peut donc rendre l'état d'avant — ce n'est pas une preuve que rien
   n'a bougé.
2. `python carnet/carnet.py recupere <la-page-servie.html>` — l'état redescend
   dans `etat.json`, et la commande liste ce qui a été tranché ;
3. éditer, `build`, republier.

Le carnet a aussi, dans son pied de page, un bouton **« Exporter l'état pour le
dépôt »** : le joueur peut envoyer lui-même son `etat.json` quand la relecture
coince.

Un `conflict` au moment de publier veut dire qu'il a coché entre-temps :
relire, fusionner, republier. `force` seulement après avoir vraiment fusionné.

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
- `statut` : `attente` (à vérifier), `todo`, `encours`, `ok`, `ko`.
- `qui` : `Claude` ou `Toi`. C'est ce qui colore la signature.
- `statut` : **c'est lui qui pilote la boucle de travail.** `todo`, `ko` et
  `encours` entrent dans l'ordre de marche ; **`attente` en sort** — la fiche
  est livrée, elle attend le joueur, et la reprendre serait refaire un travail
  que personne n'a jugé. Quand il ne reste plus rien à faire, le carnet dit
  *EN ATTENTE DE TOI* au lieu de proposer un chantier.
- `livre` : `{"commit": "940d5ea", "quand": "24/08 à 03h05"}` — **à remplir en
  même temps qu'on passe une fiche en `attente`.** C'est ce qui dit au joueur
  depuis quand et sur quelle version une ligne l'attend.
- `avancement` : un entier de 0 à 100. Absent, il se déduit de l'état (todo 0,
  ko 10, encours 50, attente 90, ok 100). La barre globale est la **moyenne**
  des fiches, pas la part de fiches validées : sinon une journée de dix
  chantiers reste à 0 % jusqu'à la première validation.
- `theme` : un mot, cliquable, qui sert de filtre.
- `priorite` : `haute`, `moyenne`, `basse`. Le tri est **stable** : deux fiches
  de même priorité gardent l'ordre du fichier, donc l'ordre convenu avec le
  joueur survit. Le joueur peut changer la priorité depuis la page.
- `build.enLigne` : **la consigne la plus importante du carnet.** `false` tant
  que le travail n'est pas exporté sur `gh-pages` — bandeau orange, « ne teste
  pas tout de suite ». Une date la fait passer au **grand bandeau vert
  « COMMIT ET TEST POSSIBLE »**, demandé mot pour mot par le joueur après avoir
  testé une version d'avant.

  ⚠️ **Règle qu'il a posée : ne pas mettre le carnet à jour avant que le build
  correspondant soit en ligne.** Publier une ligne « fait » sur un build qu'il
  ne peut pas encore lancer lui fait perdre un test — c'est arrivé le 24/08.

## Un carnet pour un autre chantier

```bash
python carnet/carnet.py neuf boutique
```

écrit `etat_boutique.json`. Le bâtir avec `ETAT=carnet/etat_boutique.json`,
et le publier **sans** `url` — celui-là est un carnet neuf, et c'est voulu.
Noter sa nouvelle adresse ici même.
