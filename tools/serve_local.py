"""Serveur local pour tester le build web de KING'S GAMBIT sur un telephone.

HTTPS, ET C'EST OBLIGATOIRE.

Godot refuse de demarrer hors d'un "contexte securise" : sur du HTTP simple le
jeu ne charge pas et affiche "Secure Context - Check web server configuration
(use HTTPS)". `localhost` est le seul contexte securise en clair - une adresse
de reseau local comme http://192.168.1.60 ne l'est pas. Un telephone n'aurait
donc vu que le message d'erreur.

D'ou le certificat AUTO-SIGNE : le telephone affichera un avertissement une
fois, qu'il faut accepter ("Parametres avances" > "Continuer"). Le certificat
doit porter l'adresse IP dans son SAN, sinon le navigateur refuse meme apres
acceptation.

Deux raisons de ne pas se contenter de `python -m http.server` :

  - le type MIME de .wasm n'est pas connu de toutes les installations Python,
    et sans `application/wasm` Godot renonce a `instantiateStreaming` pour un
    chargement plus lent (voire echoue selon le navigateur) ;
  - il repond en HTTP/1.0, une connexion par fichier : sur 56 Mo en Wi-Fi, ca
    se sent.

PAS D'EN-TETES D'ISOLATION CROSS-ORIGIN. Le build est exporte sans support des
threads (`thread_support=false` dans export_presets.cfg), donc SharedArrayBuffer
n'est pas requis et COOP/COEP ne servent a rien ici. Si l'export passe un jour a
`thread_support=true`, il faudra les ajouter - et le HTTPS deja en place suffira,
SharedArrayBuffer exigeant de toute facon un contexte securise.

UNE ERREUR QU'ON PEUT IGNORER : la console affiche "Failed to register a
ServiceWorker". Trois causes ont ete testees et ECARTEES - les en-tetes
d'isolation, `Cache-Control: no-store`, et HTTP/1.0 ; le fichier est bien servi
(200, application/javascript, 5826 octets). Le reste pointe vers le navigateur
d'inspection, qui interdit les service workers. Le jeu se charge et se joue
normalement : ce worker ne sert qu'au cache hors ligne et a poser les en-tetes
d'isolation dont ce build n'a pas besoin.

Usage :
  python tools/serve_local.py docs            # HTTPS sur 8443 (telephone)
  python tools/serve_local.py docs 8080 -     # HTTP simple (ce PC seulement)

Le certificat est genere tout seul au premier lancement, et REGENERE si
l'adresse IP de la machine a change.
"""

import http.server
import mimetypes
import os
import socket
import socketserver
import ssl
import subprocess
import sys

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/manifest+json", ".webmanifest")
mimetypes.add_type("application/json", ".json")


class Handler(http.server.SimpleHTTPRequestHandler):
    # SimpleHTTPRequestHandler repond en HTTP/1.0 par defaut : une connexion
    # neuve par fichier, fermee apres chaque reponse. Sur 56 Mo transferes en
    # Wi-Fi vers un telephone, la difference se sent.
    protocol_version = "HTTP/1.1"

    def end_headers(self):
        # no-store : on reexporte souvent pendant un test, et un telephone qui
        # garde en cache un index.wasm de la veille donne l'impression que la
        # correction n'a pas marche.
        #
        # Le service worker en est exempte par principe (un script d'install
        # qu'on empeche de se mettre en cache est un mauvais pari), meme si
        # l'exemption n'a PAS suffi a corriger son enregistrement - voir la
        # note en tete de fichier.
        if not self.path.endswith("service.worker.js"):
            self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        # Une ligne par requete, sans l'horodatage verbeux par defaut.
        sys.stderr.write("  %s\n" % (fmt % args))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def local_ip() -> str:
    """L'adresse de cette machine sur le reseau local.

    Passe par une socket UDP ouverte vers l'exterieur : elle ne transmet rien,
    mais oblige le systeme a choisir l'interface reellement routee - plus fiable
    que gethostbyname, qui rend souvent 127.0.0.1.
    """
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("8.8.8.8", 80))
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


def ensure_certificate(cert: str, key: str, ip: str) -> bool:
    """Genere le certificat auto-signe s'il manque. Vrai s'il est utilisable.

    L'adresse IP doit figurer dans le SAN : un navigateur refuse un certificat
    qui ne nomme pas l'hote demande, meme apres que l'utilisateur a accepte
    l'avertissement. C'est pour ca qu'on le REGENERE quand l'IP a change -
    changer de reseau (ou de box) suffit a la faire bouger.
    """
    if os.path.exists(cert) and os.path.exists(key):
        try:
            existing = subprocess.run(
                ["openssl", "x509", "-in", cert, "-noout", "-ext", "subjectAltName"],
                capture_output=True, text=True, check=True).stdout
            if ip in existing:
                return True
            print("Le certificat ne couvre plus %s : on le regenere." % ip)
        except (OSError, subprocess.CalledProcessError):
            return True  # openssl absent : on garde ce qui est la.

    try:
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", key, "-out", cert, "-days", "365",
            "-subj", "/CN=KINGSGAMBIT local",
            "-addext", "subjectAltName=IP:%s,DNS:localhost,IP:127.0.0.1" % ip,
        ], capture_output=True, check=True)
        print("Certificat auto-signe genere pour %s." % ip)
        return True
    except (OSError, subprocess.CalledProcessError) as error:
        print("Impossible de generer le certificat (%s)." % error)
        return False


def main() -> None:
    directory = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8443

    # Les chemins par defaut suivent le SCRIPT, pas le repertoire courant : on
    # le lance presque toujours depuis la racine du depot.
    here = os.path.dirname(os.path.abspath(__file__))
    cert = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, "kg-cert.pem")
    key = sys.argv[4] if len(sys.argv) > 4 else os.path.join(here, "kg-key.pem")
    if cert != "-":
        ensure_certificate(cert, key, local_ip())

    handler = lambda *a, **kw: Handler(*a, directory=directory, **kw)
    server = Server(("0.0.0.0", port), handler)

    scheme = "http"
    if os.path.exists(cert) and os.path.exists(key):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = "https"
    else:
        print("ATTENTION : pas de certificat (%s) - le jeu ne chargera QUE sur "
              "localhost, Godot exigeant un contexte securise." % cert)

    with server:
        print("KING'S GAMBIT sert %s" % directory)
        print("  sur ce PC        : %s://localhost:%d/index.html" % (scheme, port))
        print("  sur le telephone : %s://%s:%d/index.html" % (scheme, local_ip(), port))
        print("Ctrl+C pour arreter.")
        server.serve_forever()


if __name__ == "__main__":
    main()
