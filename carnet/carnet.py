#!/usr/bin/env python3
"""
LE CARNET DE TRAVAUX - outil de suivi des retours de test.

    python carnet/carnet.py build     assemble page.html + etat.json -> build/carnet.html
    python carnet/carnet.py recupere  relit l'etat d'un carnet publie et le reverse ici
    python carnet/carnet.py neuf NOM  demarre un carnet vierge pour un autre chantier

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

RACINE = os.path.dirname(os.path.abspath(__file__))
PAGE = os.path.join(RACINE, "page.html")
ETAT = os.path.join(RACINE, "etat.json")
SORTIE = os.path.join(RACINE, "build", "carnet.html")

# Le trou de la page, a l'endroit exact ou l'etat s'insere.
MARQUE = "__ETAT__"


def _lire(chemin):
    return io.open(chemin, encoding="utf-8").read()


def _ecrire(chemin, contenu):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    io.open(chemin, "w", encoding="utf-8", newline="\n").write(contenu)


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
    # `<` echappe : l'etat porte du HTML (<strong>, <code>) dans ses details, et
    # un `</script>` litteral y fermerait la balise qui le contient.
    texte = json.dumps(etat, ensure_ascii=False, indent=1).replace("<", "\\u003c")
    _ecrire(SORTIE, page.replace(MARQUE, texte))
    for j in _journees(etat):
        ouvertes = sum(1 for sec in j["sections"]
                       for it in sec["items"] if it["statut"] != "ok")
        print("  %-32s %2d fiches, %2d ouvertes" % (
            j.get("nom", "?"), sum(len(sec["items"]) for sec in j["sections"]), ouvertes))
    print("build/carnet.html ecrit")
    print("A publier avec l'outil Artifact, en passant l'URL du carnet existant")
    print("(sinon un SECOND carnet est cree et le joueur coche le mauvais).")


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


def main():
    args = sys.argv[1:]
    if not args or args[0] == "build":
        build()
    elif args[0] == "recupere":
        if len(args) < 2:
            raise SystemExit("usage : carnet.py recupere <page-servie.html>")
        recupere(args[1])
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
