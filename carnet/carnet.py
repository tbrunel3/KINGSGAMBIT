#!/usr/bin/env python3
"""
LE CARNET DE TRAVAUX - outil de suivi des retours de test.

    python carnet/carnet.py build     assemble page.html + etat.json -> build/carnet.html
    python carnet/carnet.py recupere  relit l'etat d'un carnet publie et le reverse ici
    python carnet/carnet.py enligne   pose le carnet sur gh-pages, a cote du jeu
    python carnet/carnet.py neuf NOM  demarre un carnet vierge pour un autre chantier

DEUX ENDROITS OU IL TOURNE, ET C'EST VOULU :

  - l'ARTEFACT sur claude.ai, qui se republie a chaque coche. C'est le carnet
    vivant, et c'est celui qui a deja ete SUPPRIME DEUX FOIS.
  - le DEPOT, via gh-pages : `https://tbrunel3.github.io/KINGSGAMBIT/carnet/`.
    Pas de publication automatique la-bas - les coches vont dans le miroir du
    navigateur, et le joueur exporte l'etat pour le renvoyer. En echange,
    PERSONNE NE PEUT LE SUPPRIMER : il vit dans git.

⚠️ DEUX COPIES EXISTENT, ET ELLES DIVERGENT. Le depot porte la SOURCE ; la
copie publiee est celle que le joueur COCHE - elle se republie elle-meme sous
son identite a chaque verdict. Le premier carnet a ete supprime avec la seule
liste des vingt-deux retours qu'il y avait : depuis, ce qui est tranche
redescend ici.

Avant de republier apres que le joueur a coche quelque chose : `recupere`
d'abord, sinon on ecrase ses verdicts avec un etat perime.
"""

import io
import json
import os
import re
import sys
import time

RACINE = os.path.dirname(os.path.abspath(__file__))
PAGE = os.path.join(RACINE, "page.html")
ETAT = os.path.join(RACINE, "etat.json")
SORTIE = os.path.join(RACINE, "build", "carnet.html")
ARCHIVES = os.path.join(RACINE, "build", "archive")
APERCU = os.path.join(RACINE, "build", "apercu.html")
# Le meme fichier, range la ou le build web du jeu attend le sien. `/docs/` est
# ignore par git (55 Mo de wasm) : c'est une zone de preparation, pas une
# source. `enligne` recopie de la sur gh-pages.
DEPOT = os.path.dirname(RACINE)
DOCS = os.path.join(DEPOT, "docs", "carnet", "index.html")
BRANCHE = "gh-pages"

# L'ADRESSE DU CARNET VIVANT. Elle vit ici, dans le depot, parce qu'elle s'est
# deja perdue deux fois : publier SANS elle cree un second carnet, et le joueur
# continue de cocher l'ancien pendant qu'on lit le nouveau.
#
# Le carnet publie a ete SUPPRIME deux fois (24/08). D'ou deux gardes :
#   - `build` depose une copie horodatee dans build/archive/ - la page telle
#     qu'elle part, pour qu'une suppression ne laisse pas les mains vides ;
#   - avant de republier, VERIFIER QUE L'ADRESSE REPOND (WebFetch dessus). Une
#     suppression se voit alors tout de suite, et pas trois jours plus tard.
ADRESSE = "https://claude.ai/code/artifact/857ffdc3-e16a-485b-8651-853b31916069"

# Le trou de la page, a l'endroit exact ou l'etat s'insere.
MARQUE = "__ETAT__"


def _lire(chemin):
    return io.open(chemin, encoding="utf-8").read()


def _ecrire(chemin, contenu):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    io.open(chemin, "w", encoding="utf-8", newline="\n").write(contenu)


def _horodatage():
    return time.strftime("%Y%m%d-%H%M%S")


def _autonome(doc):
    """Emballe le fragment dans une vraie page.

    `page.html` n'a NI doctype NI `meta charset` : c'est l'artefact qui les pose
    au moment de publier. Servi tel quel par un serveur ordinaire, il s'affiche
    en accents casses - et on croit la page cassee alors que seul l'emballage
    manque. C'est cette version-la qui part sur gh-pages.
    """
    return "\n".join([
        '<!doctype html>',
        '<html lang="fr">',
        '<head>',
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        '<meta name="color-scheme" content="dark">',
        '</head>',
        '<body style="margin:0">',
        doc,
        '</body>',
        '</html>',
    ])


def _journees(etat):
    """Le carnet est fait de JOURNEES depuis le 24/08 - un onglet par seance.

    Les carnets d'avant n'avaient qu'un seul niveau ; on les enveloppe plutot
    que de les convertir, pour qu'un vieil etat reste lisible.
    """
    if "journees" in etat:
        return etat["journees"]
    return [{"nom": "Journée 1", "sections": etat.get("sections", [])}]


def build():
    page = _lire(PAGE)
    if MARQUE not in page:
        raise SystemExit("page.html n'a plus son trou %s" % MARQUE)
    etat = json.loads(_lire(ETAT))
    # ⚠️ LE COMPTEUR D'ECRITURE MONTE A CHAQUE BUILD, ET C'EST VITAL.
    #
    # La page garde un miroir dans le navigateur du joueur et compare `serie`
    # a l'ouverture : si le miroir est plus haut, elle propose de restaurer.
    # Sans cette ligne, le depot publiait TOUJOURS `serie` inchange - donc le
    # navigateur du joueur se croyait plus recent en permanence, et lui
    # proposait de revenir a son etat d'avant ma livraison. Le filet de
    # securite pouvait ANNULER le travail qu'il devait proteger.
    #
    # Paye le 24/08 : la fiche D livree et publiee s'affichait "en cours" chez
    # lui, parce que son navigateur restaurait le 14h24 par-dessus.
    etat["serie"] = int(etat.get("serie", 0)) + 1
    _ecrire(ETAT, json.dumps(etat, ensure_ascii=False, indent=2) + "\n")
    # `<` echappe : l'etat porte du HTML (<strong>, <code>) dans ses details, et
    # un `</script>` litteral y fermerait la balise qui le contient.
    texte = json.dumps(etat, ensure_ascii=False, indent=1).replace("<", "\\u003c")
    doc = page.replace(MARQUE, texte)
    _ecrire(SORTIE, doc)
    # La copie horodatee. build/ est ignore par git : c'est un filet LOCAL, pas
    # une sauvegarde. La vraie source reste etat.json, lui versionne.
    archive = os.path.join(ARCHIVES, "carnet-%s.html" % _horodatage())
    _ecrire(archive, doc)
    # L'APERCU LOCAL. `page.html` est un FRAGMENT : c'est l'artefact qui pose le
    # doctype et le `meta charset` au moment de publier. Servi tel quel par un
    # serveur local, il s'affiche donc en accents casses - ce qui fait douter de
    # la page alors que seul l'emballage manque. On ecrit une version complete,
    # a regarder AVANT de publier.
    autonome = _autonome(doc)
    _ecrire(APERCU, autonome)
    _ecrire(DOCS, autonome)
    for j in _journees(etat):
        ouvertes = sum(1 for sec in j["sections"]
                       for it in sec["items"] if it["statut"] != "ok")
        print("  %-32s %2d fiches, %2d ouvertes" % (
            j.get("nom", "?"), sum(len(sec["items"]) for sec in j["sections"]), ouvertes))
    print("build/carnet.html ecrit, copie dans %s"
          % os.path.relpath(archive, RACINE).replace(os.sep, "/"))
    print("build/apercu.html : la meme page, emballee, pour la regarder en local")
    print("")
    print("A publier avec l'outil Artifact, en passant CETTE adresse dans `url` :")
    print("  %s" % ADRESSE)
    print("Sans elle, un SECOND carnet est cree et le joueur coche le mauvais.")
    print("Avant de publier : verifier que l'adresse repond, puis `recupere`.")


def recupere(chemin):
    """Reverse dans etat.json l'etat lu dans une page publiee.

    Le fichier attendu est la page telle qu'elle est servie - recuperee par
    WebFetch sur l'URL du carnet, ou enregistree depuis le navigateur.
    """
    servie = _lire(chemin)
    m = re.search(r'<script id="state" type="application/json">\s*(.*?)\s*</script>',
                  servie, re.S)
    if m is None:
        raise SystemExit("aucun etat trouve dans %s" % chemin)
    etat = json.loads(m.group(1).replace("\\u003c", "<"))
    _ecrire(ETAT, json.dumps(etat, ensure_ascii=False, indent=2) + "\n")
    coches = [(it["ref"], it["statut"]) for j in _journees(etat)
              for sec in j["sections"] for it in sec["items"]
              if it["statut"] in ("ok", "ko")]
    print("etat.json remis a jour - %d fiches tranchees :" % len(coches))
    for ref, statut in coches:
        print("  %-4s %s" % (ref, statut))


def neuf(nom):
    """Un carnet vierge pour un autre chantier, meme page, autre etat."""
    cible = os.path.join(RACINE, "etat_%s.json" % nom)
    if os.path.exists(cible):
        raise SystemExit("%s existe deja" % cible)
    modele = {
        "maj": "",
        "build": {"enLigne": False, "commit": "", "quoi": "", "note": ""},
        "sections": [{
            "id": "verdict",
            "titre": "En attente de ton verdict",
            "chapo": "",
            "items": [{
                "ref": "1",
                "titre": "",
                "detail": "",
                "statut": "attente",
                "journal": [],
            }],
        }],
    }
    _ecrire(cible, json.dumps(modele, ensure_ascii=False, indent=2) + "\n")
    print("%s ecrit. Le remplir, puis :" % cible)
    print("  copier son contenu dans etat.json, ou lancer build avec ETAT=%s" % cible)


def enligne():
    """Pose le carnet sur gh-pages, a cote du jeu.

    Resultat : `https://tbrunel3.github.io/KINGSGAMBIT/carnet/`. C'est LA
    reponse a « je ne veux plus jamais que le carnet vivant soit supprime » -
    une page servie par git ne depend plus d'un artefact que quelqu'un peut
    effacer. En echange elle ne se republie pas toute seule : les coches vont
    dans le miroir du navigateur, et le bouton d'export les rend.
    """
    import shutil
    import subprocess
    import tempfile

    build()
    print("")

    def git(*a, **kw):
        ou = kw.pop("cwd", DEPOT)
        r = subprocess.run(["git"] + list(a), cwd=ou, capture_output=True,
                           text=True, encoding="utf-8", errors="replace")
        if r.returncode and not kw.get("tolere"):
            raise SystemExit("git %s a echoue :\n%s%s"
                             % (" ".join(a), r.stdout or "", r.stderr or ""))
        return r

    # ⚠️ JAMAIS `git checkout gh-pages`. Cette branche ne contient QUE le build
    # web : la basculer dans l'arbre de travail efface tout le code sous les
    # pieds. Un worktree la monte a cote, dans un dossier a part, et on le
    # retire ensuite - c'est la procedure deja ecrite dans la passation.
    coin = tempfile.mkdtemp(prefix="carnet-ghpages-")
    shutil.rmtree(coin)           # `worktree add` veut un chemin qui n'existe pas
    pose = False
    try:
        git("worktree", "add", coin, BRANCHE)
        _ecrire(os.path.join(coin, "carnet", "index.html"), _lire(DOCS))
        git("add", "carnet/index.html", cwd=coin)
        if not git("status", "--porcelain", "carnet/index.html", cwd=coin).stdout.strip():
            print("%s porte deja exactement ce carnet - rien a commiter." % BRANCHE)
            return
        git("commit", "-m", "Le carnet tourne depuis le depot", cwd=coin)
        pose = True
    finally:
        subprocess.run(["git", "worktree", "remove", "--force", coin], cwd=DEPOT,
                       capture_output=True, text=True, errors="replace")

    if pose:
        print("Commit pose sur %s. Il n'est PAS pousse - a toi de decider :" % BRANCHE)
        print("  git push origin %s" % BRANCHE)
        print("")
        print("Une fois pousse, le carnet est a :")
        print("  https://tbrunel3.github.io/KINGSGAMBIT/carnet/")


def main():
    args = sys.argv[1:]
    if not args or args[0] == "build":
        build()
    elif args[0] == "recupere":
        if len(args) < 2:
            raise SystemExit("usage : carnet.py recupere <page-servie.html>")
        recupere(args[1])
    elif args[0] == "enligne":
        enligne()
    elif args[0] == "neuf":
        if len(args) < 2:
            raise SystemExit("usage : carnet.py neuf <nom-du-chantier>")
        neuf(args[1])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    # ETAT=... permet de batir un autre carnet que celui par defaut.
    ETAT = os.environ.get("ETAT", ETAT)
    main()
