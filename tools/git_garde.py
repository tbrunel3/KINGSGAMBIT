#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LE GARDE-FOU GIT — pour qu'une journée de travail ne se perde plus jamais.

CE QUI EST ARRIVÉ LE 25/08/2026, et qu'on ne veut plus revoir.

Ce dépôt local avait **23 commits de retard** sur `origin/main`, et rien ne le
disait. Une soirée entière de travail — l'intro, le bouton COMBATTRE, les
missives, l'habillage des popups, trois dettes — avait été poussée depuis une
autre session le 24/08. La copie locale ne l'a jamais tirée.

Résultat : une journée entière de travail refait à l'identique, en parallèle,
sans le savoir. Et six verdicts du joueur perdus au passage — dont deux
messages qu'il avait écrits et que personne n'a jamais lus.

La cause n'est pas une erreur de manipulation. C'est qu'**être en retard ne se
voit pas**. `git status` dit « nothing to commit, working tree clean » quand on
est vingt-trois commits derrière : il ne parle que du disque, jamais du
distant.

DEUX GARDES, ET ILS SE COMPLÈTENT.

  debut   — au démarrage d'une session. Va chercher l'état du distant et le
            DIT. C'est le garde qui aurait empêché la journée perdue.
  pousse  — après chaque commit. Pousse tout de suite, pour que la fenêtre de
            divergence dure des minutes et non une journée.

⚠️ `pousse` NE FORCE JAMAIS. Si le distant a bougé, la poussée échoue et le
garde le dit fort. Un `--force` automatique transformerait ce filet de sécurité
en broyeuse : il effacerait le travail de l'autre session au lieu de signaler
qu'elle existe.

Les deux rendent du JSON sur la sortie standard, au format que Claude Code
attend d'un hook : `systemMessage` s'affiche au joueur, `additionalContext`
entre dans le contexte de l'agent. Les deux sont nécessaires — le joueur doit
voir le danger, et l'agent doit le savoir avant de commencer à travailler.

Usage :
  python tools/git_garde.py debut
  python tools/git_garde.py pousse
"""

import json
import os
import subprocess
import sys

# ⚠️ LA CONSOLE WINDOWS N'ENCODE PAS L'UTF-8 PAR DÉFAUT, et ce garde parle
# français avec des flèches et des ⚠️. Sans cette ligne, `print` lève
# UnicodeEncodeError sur le premier accent : le hook rend du JSON tronqué, et
# le garde censé prévenir d'un danger devient lui-même le danger.
# Trouvé à l'essai, pas deviné — le premier `↑ poussé` a fait tomber le script.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRINCIPALE = "main"


def git(*args, timeout=60):
    """Rend (code, sortie). Ne lève jamais : un garde qui plante est pire que
    pas de garde — il ferait échouer le démarrage de la session."""
    try:
        r = subprocess.run(
            ["git"] + list(args),
            cwd=RACINE, capture_output=True, timeout=timeout,
        )
        sortie = (r.stdout + r.stderr).decode("utf-8", "replace").strip()
        return r.returncode, sortie
    except Exception as e:
        return 1, str(e)


def dire(message=None, contexte=None, bloquant=False):
    """La sortie que Claude Code lit. `message` va au joueur, `contexte` à
    l'agent."""
    sortie = {}
    if message:
        sortie["systemMessage"] = message
    if contexte:
        sortie["hookSpecificOutput"] = {
            "hookEventName": "SessionStart" if not bloquant else "PostToolUse",
            "additionalContext": contexte,
        }
    print(json.dumps(sortie, ensure_ascii=False))


def branche_courante():
    code, nom = git("rev-parse", "--abbrev-ref", "HEAD")
    return nom if code == 0 else ""


# ---------------------------------------------------------------------------


def debut():
    """Au démarrage : est-ce qu'on part d'un dépôt à jour ?"""
    code, _ = git("rev-parse", "--git-dir")
    if code != 0:
        return  # pas un dépôt git : rien à garder

    # Le fetch peut être lent ou hors ligne. On ne bloque pas la session pour
    # ça — mais on le DIT, parce qu'un garde muet qui a échoué se confond avec
    # un garde qui n'a rien trouvé.
    code, sortie = git("fetch", "origin", "--quiet", timeout=45)
    if code != 0:
        raison = sortie.splitlines()[-1][:120] if sortie else "hors ligne"
        dire(contexte="⚠️ GARDE GIT : impossible de joindre origin (%s). "
             "Le dépôt local est peut-être en retard SANS QUE RIEN NE LE DISE. "
             "Relancer `git fetch origin` avant de commencer à travailler."
             % raison)
        return

    branche = branche_courante()
    if not branche or branche == "HEAD":
        return

    cible = "origin/%s" % branche
    code, _ = git("rev-parse", "--verify", "--quiet", cible)
    if code != 0:
        # Branche locale sans distant : on regarde quand même main.
        cible = "origin/%s" % PRINCIPALE
        code, _ = git("rev-parse", "--verify", "--quiet", cible)
        if code != 0:
            return

    code, compte = git("rev-list", "--left-right", "--count", "%s...HEAD" % cible)
    if code != 0 or "\t" not in compte:
        return
    derriere, devant = [int(x) for x in compte.split("\t")[:2]]

    if derriere == 0 and devant == 0:
        return  # à jour : on ne dit rien, un garde bavard finit ignoré

    lignes = []
    if derriere:
        code, quoi = git("log", "--oneline", "-6", "HEAD..%s" % cible)
        lignes.append(
            "⚠️ CE DÉPÔT EST EN RETARD DE %d COMMIT%s sur %s.\n"
            "C'est EXACTEMENT ce qui a coûté une journée de travail le 25/08 : "
            "du travail déjà fait ailleurs, refait ici sans le savoir.\n"
            "NE RIEN COMMENCER avant d'avoir tiré :\n"
            "    git pull --ff-only origin %s\n"
            "Ce qui manque :\n%s"
            % (derriere, "S" if derriere > 1 else "", cible,
               cible.split("/", 1)[1], quoi)
        )
    if devant:
        lignes.append(
            "%s sur %s. Les pousser tout de suite : `git push origin %s`."
            % ("%d commits locaux ne sont pas encore poussés" % devant
               if devant > 1 else "1 commit local n'est pas encore poussé",
               cible, branche)
        )

    texte = "\n\n".join(lignes)
    court = ("⚠️ %d commit(s) de retard sur %s" % (derriere, cible)) if derriere \
        else ("%d commit(s) à pousser" % devant)
    dire(message=court, contexte=texte)


# ---------------------------------------------------------------------------


def pousse():
    """Après un commit : on pousse tout de suite.

    ⚠️ JAMAIS EN FORCE. Une poussée refusée veut dire que quelqu'un d'autre a
    travaillé : c'est une information, pas un obstacle à écraser."""
    branche = branche_courante()
    if not branche or branche == "HEAD":
        return

    code, _ = git("rev-parse", "--verify", "--quiet", "origin/%s" % branche)
    amont = [] if code == 0 else ["--set-upstream"]

    code, sortie = git("push", *(amont + ["origin", branche]), timeout=180)
    if code == 0:
        if "Everything up-to-date" in sortie:
            return  # rien à dire
        dire(message="↑ poussé sur %s" % branche)
        return

    # L'échec est le cas INTÉRESSANT : il veut presque toujours dire que le
    # distant a bougé pendant qu'on travaillait.
    dire(
        message="⚠️ LA POUSSÉE A ÉCHOUÉ — le travail n'est que sur ce disque",
        contexte="⚠️ `git push origin %s` a échoué :\n%s\n\n"
                 "Si c'est un refus de type « non-fast-forward », le distant a "
                 "AVANCÉ pendant qu'on travaillait, et les deux versions "
                 "divergent. NE PAS FORCER. Mettre d'abord le travail à l'abri "
                 "sur une branche nommée, puis montrer la divergence au joueur "
                 "et le laisser trancher — c'est la procédure du 25/08, et "
                 "elle a sauvé les deux versions."
                 % (branche, sortie[-800:]),
        bloquant=True,
    )


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "debut"
    try:
        if mode == "pousse":
            pousse()
        else:
            debut()
    except Exception as e:
        # Un garde ne fait jamais échouer la session qu'il protège.
        print(json.dumps({"systemMessage": "garde git : %s" % e}, ensure_ascii=False))
