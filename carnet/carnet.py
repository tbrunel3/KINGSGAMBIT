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
ADRESSE = "https://claude.ai/code/artifact/47c96d8b-a61a-4222-932d-04430c13692f"

# Le trou de la page, a l'endroit exact ou l'etat s'insere.
MARQUE = "__ETAT__"
## Le second trou : la galerie des ecrans, injectee de la meme facon.
MARQUE_GALERIE = "__GALERIE__"


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


def _git(*args):
    """Une commande git, ou None si git n'a rien a dire ici."""
    import subprocess
    try:
        r = subprocess.run(["git"] + list(args), cwd=DEPOT, capture_output=True,
                           text=True, encoding="utf-8", errors="replace")
    except OSError:
        return None
    return r


def _marque_livraisons(etat):
    """Pose sur chaque fiche livree OU EN EST vraiment son commit.

    ⚠️ CETTE DEDUCTION NE SE FAIT PAS A LA MAIN, ET C'EST TOUT L'INTERET.
    L'onglet « a verifier » affirmait « Livres et en ligne » pour tout le monde.
    Releve le 24/08 : le build en ligne etait `9ebb63b` (14h50) et la fiche E
    avait ete livree en `49d4f3b` (15h50) - le carnet l'annoncait testable alors
    que le jeu servi ne la portait pas. C'est le defaut que le README interdit
    depuis le matin, et il etait revenu par la porte d'a cote.

    Deux faits, tous deux lus dans git :
      - `pousse`  : le commit existe sur un remote, donc ailleurs que chez moi ;
      - `enLigne` : il est un ancetre du commit du build servi, donc le jeu que
                    le joueur peut lancer le porte VRAIMENT.
    """
    build_ref = ""
    for j in _journees(etat):
        build_ref = str((j.get("build") or {}).get("commit", "")) or build_ref
    for j in _journees(etat):
        for sec in j["sections"]:
            for it in sec["items"]:
                liv = it.get("livre")
                if not liv or not liv.get("commit"):
                    continue
                commit = str(liv["commit"])
                if _git("cat-file", "-e", commit + "^{commit}").returncode != 0:
                    continue                      # commit inconnu : on ne dit rien
                distant = _git("branch", "-r", "--contains", commit)
                liv["pousse"] = bool(distant.stdout.strip())
                liv["enLigne"] = bool(build_ref) and _git(
                    "merge-base", "--is-ancestor", commit, build_ref).returncode == 0


# LA GALERIE DES ECRANS.
#
#  Demande du joueur : « fais des petites vignettes des ecrans, bien rangees,
#  chapitrees, pour bien comprendre de quelle fenetre du projet on parle ».
#
#  ⚠️ CE SONT LES VRAIS ECRANS DU JEU, PAS LA MAQUETTE. Une vignette tiree de
#  Figma montrerait ce qui etait prevu ; celles-ci montrent ce qui tourne, donc
#  ce sur quoi il y a quelque chose a dire. Elles sortent de
#  `tools/screenshot.tscn`, qui a besoin d'une FENETRE - sous `xvfb-run`, il
#  tourne tres bien sans ecran (cf. CLAUDE.md).
#
#  Le pipeline entier est automatique : relancer le banc de capture puis
#  `build` suffit a rafraichir la galerie. Rien a decouper a la main.
CAPTURES = os.path.join(DEPOT, "tools", "screenshots")

## Les chapitres, dans l'ordre ou le joueur traverse le jeu. Une capture qui
## n'est nommee nulle part tombe dans "Autres" plutot que de disparaitre : une
## galerie qui perd un ecran en silence ne se voit pas.
CHAPITRES = [
    ("Intro", ["8_splash", "9a_intro_approche", "9_intro_typing", "9_intro_ready"]),
    ("Village", ["1_village", "1_village_avance", "1d_missions", "1e_popup_caserne",
                 "1f_popup_verrouille", "1g_confirmer_amelioration",
                 "1h_popup_amelioration"]),
    ("Château Royal", ["1a_chateau_qui_brille", "1b_chateau_avec_dame",
                       "1b2_chateau_sans_dame"]),
    ("Campagne", ["2_campagne"]),
    ("Préparation", ["3_preparation", "3b_preparation_dame",
                     "3c_preparation_composee"]),
    ("Placement", ["4_placement", "5_placement", "5b_aide_placement",
                   "1c_dame_au_placement"]),
    ("Combat", ["6_coups_possibles", "6a_aide_combat", "6b_combat",
                "4b_serie_combat2", "4c_serie_bandeau", "1j_serie_avertissement"]),
    ("Résultats", ["7_resultat", "7b_defaite", "7c_nul", "7d_nul_serie"]),
    ("Codex & Boutique", ["1i_codex", "1k_boutique"]),
    ("Composants", ["0_ui_kit"]),
]

## Largeur de la vignette. Mesuree : a 96 px, les 35 ecrans pesent 102 Ko de
## base64 - le carnet reste sous le demi-mega, et il se lit sur un telephone.
VIGNETTE = 96


def _vignettes():
    """Les captures du jeu, reduites et embarquees, rangees par chapitre."""
    import base64
    import glob
    try:
        from PIL import Image
    except ImportError:
        print("⚠️  Pillow absent : galerie non regeneree (pip install Pillow)")
        return None
    if not os.path.isdir(CAPTURES):
        return None

    connues = {}
    for titre, cles in CHAPITRES:
        for cle in cles:
            connues[cle] = titre

    galerie = []
    for chemin in sorted(glob.glob(os.path.join(CAPTURES, "*.png"))):
        cle = os.path.basename(chemin)[:-4]
        image = Image.open(chemin).convert("RGB")
        image.thumbnail((VIGNETTE, 400))
        tampon = io.BytesIO()
        image.save(tampon, "WEBP", quality=58, method=6)
        galerie.append({
            "cle": cle,
            "chapitre": connues.get(cle, "Autres"),
            "large": image.size[0],
            "haut": image.size[1],
            "image": "data:image/webp;base64,"
                     + base64.b64encode(tampon.getvalue()).decode("ascii"),
        })
    ordre = [titre for titre, _ in CHAPITRES] + ["Autres"]
    galerie.sort(key=lambda v: (ordre.index(v["chapitre"]) if v["chapitre"] in ordre
                                else len(ordre), v["cle"]))
    return galerie


def build():
    page = _lire(PAGE)
    if MARQUE not in page:
        raise SystemExit("page.html n'a plus son trou %s" % MARQUE)
    etat = json.loads(_lire(ETAT))
    _marque_livraisons(etat)
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
    galerie = _vignettes()
    if galerie is not None:
        doc = doc.replace(MARQUE_GALERIE,
                          json.dumps(galerie, ensure_ascii=False).replace("<", "\\u003c"))
        print("galerie : %d ecrans embarques" % len(galerie))
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


def _fiches(etat):
    """Toutes les fiches d'un etat, indexees par ref, journees confondues."""
    return {it["ref"]: it for j in _journees(etat)
            for sec in j["sections"] for it in sec["items"]}


def _ecarts(source, page):
    """Ce que `recupere` CHANGERAIT, fiche par fiche. Sans ca, refuser la
    fusion serait aussi aveugle que l'accepter."""
    ici, la_bas = _fiches(source), _fiches(page)
    lignes = []
    # L'ordre de marche n'est pas une fiche, et c'est pourtant lui qu'on a
    # perdu le 24/08 : il commande la boucle de travail.
    for j_ici, j_la in zip(_journees(source), _journees(page)):
        m_ici, m_la = j_ici.get("marche"), j_la.get("marche")
        if bool(m_ici) != bool(m_la) or (m_ici and m_la and m_ici != m_la):
            lignes.append("  ordre de marche : %s -> %s"
                          % ((m_ici or {}).get("nom", "aucun") if m_ici else "aucun",
                             (m_la or {}).get("nom", "aucun") if m_la else "aucun"))
    for ref in sorted(set(ici) | set(la_bas)):
        a = ici.get(ref, {}).get("statut", "(absente)")
        b = la_bas.get(ref, {}).get("statut", "(absente)")
        if a != b:
            lignes.append("  %-4s source %-9s -> page %s" % (ref, a, b))
    return lignes


def recupere(chemin, force=False):
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

    # ⚠️ LE SENS DE LA FUSION, ET C'EST LE TROU DE LA PROCEDURE DU README.
    #
    # `recupere` n'ajoute rien : il ECRASE etat.json avec ce que porte la page.
    # Or le README fait de « recupere » l'etape obligatoire AVANT de republier.
    # Si la page est plus VIEILLE que la source - je viens de livrer et je n'ai
    # pas encore republie - suivre la procedure detruit la livraison au lieu de
    # proteger les coches du joueur. Le filet devient l'accident, exactement
    # comme le miroir du navigateur avant sa correction.
    #
    # Paye le 24/08 : page a serie 61, source a 62. La fusion a efface l'ordre
    # de marche lance a 16h05 et remis n1 en `todo`. Rien n'etait a recuperer :
    # les dix verdicts du joueur etaient deja dans la source.
    #
    # `serie` tranche, et lui seul : il monte a chaque build ICI (carnet.py) et
    # a chaque geste LA-BAS (page.html, miroirEcrit). Le plus haut est le plus
    # recent, sans exception.
    if os.path.exists(ETAT):
        source = json.loads(_lire(ETAT))
        ici, la_bas = int(source.get("serie", 0)), int(etat.get("serie", 0))
        if la_bas < ici and not force:
            print("REFUS : la page publiee est plus VIEILLE que la source.")
            print("  source %s : serie %d" % (os.path.relpath(ETAT, RACINE), ici))
            print("  page   %s : serie %d" % (os.path.basename(chemin), la_bas))
            print("")
            print("Le joueur n'a donc rien coche depuis le dernier build : il n'y")
            print("a rien a recuperer, et fusionner effacerait la livraison.")
            ecarts = _ecarts(source, etat)
            if ecarts:
                print("Ce que la fusion changerait :")
                print("\n".join(ecarts))
            print("")
            print("Fais `build` puis republie - la page rattrapera la source.")
            print("Si tu sais ce que tu fais : recupere <page> --force")
            raise SystemExit(1)
        if la_bas == ici:
            print("Page et source au meme point (serie %d) : rien de neuf." % ici)

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
        recupere(args[1], force="--force" in args[2:])
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
