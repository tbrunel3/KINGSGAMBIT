# Archive des chantiers livrés

⚠️ **Rien ici n'est du travail à faire.** Tous ces chantiers sont livrés et
mesurés. Ce dossier existe pour qu'on puisse retrouver *comment* une décision a
été prise — pas pour qu'on rouvre le chantier.

**Les mesures et les pièges qui servent encore ont été remontés dans
[`CLAUDE.md`](../CLAUDE.md).** Si une information de ce dossier contredit le
manuel, c'est le manuel qui fait foi : ces fichiers ont été figés le 25/08/2026
et ne sont plus tenus à jour.

**Le travail en cours vit dans [`carnet/etat.json`](../carnet/README.md), et
nulle part ailleurs.**

| Fichier | Chantier | Livré | Ce qu'il garde d'unique |
|---|---|---|---|
| `passation_chantiers_c_d_e.md` | **C** composition d'armée, **D** polices et animations, **E** popups d'accompagnement | 23/08/2026 | le détail des décisions du joueur sur la composition |
| `chantier_g_f.md` | **G + F** assemblage graphique et format d'écran | 23/08/2026 | le relevé d'animations section par section, et les six pièges découverts en chemin |
| `passation_g_f.md` | passation du même chantier | 23/08/2026 | ⚠️ **périmé par son propre successeur** — il le dit lui-même : « le tableau ci-dessus est périmé sur cinq lignes » |
| `plan_g_f.md` | le plan d'exécution de G + F, en 13 tâches | 23/08/2026 | ⚠️ **ses 80 cases `- [ ]` sont toutes décochées alors que les douze tâches sont faites.** 46 % du fichier est du GDScript recopié, qui vit désormais dans `scripts/ui/cover_fit.gd`, `tools/format_test.gd` et `scenes/ui/components/corner_button.gd` — la copie a divergé, le dépôt fait foi |
| `chantier_h_boutique.md` | **H** la boutique | 23/08/2026 | les règles de prix et de coffres, citées par `figma_prompt_boutique.md` |
| `chantier_i_missives.md` | **I** les quatre lettres scellées du Roi | commit `166773c` | les mesures des deux illustrations : plissures à 39,5 % et 65,4 %, marge intérieure 8,5 % |

## Pourquoi ces six-là

Chacun se déclare terminé dans son propre texte, et le code le confirme :
`scenes/story/royal_letter.gd` existe, `GameState` compte les défaites,
`scenes/village/shop.gd` sert la boutique, le village est en deux calques avec
une dérive mesurée à 0,00.

Les garder dans le chemin de lecture coûtait deux choses : **183 Ko** qu'un agent
peut ouvrir en croyant y trouver du travail, et — plus cher — **trois documents
qui se disputaient le titre de « premier fichier à ouvrir »** alors qu'aucun des
trois n'était le bon.

Ils restent versionnés : rien n'est perdu, `git log` les suit à travers le
déplacement.
