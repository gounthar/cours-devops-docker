#!/usr/bin/env python3
"""Liste les fichiers de `content/media/` que rien dans le dépôt ne référence.

Pourquoi ce script existe
-------------------------
`check-assets` vérifie que tout fichier *référencé* existe. L'inverse — tout
fichier *existant* est-il référencé ? — n'était vérifié nulle part. C'est ce
trou qui a laissé s'accumuler les orphelins de #518, #538 et #540, chaque fois
découverts à la main. Voir #573.

Signalement seul, jamais un échec
---------------------------------
Le script sort 0 quel que soit le nombre d'orphelins. Le dépôt en porte une
centaine : en échec, la cible serait rouge dès le premier jour, et un garde-fou
rouge en permanence finit ignoré, puis retiré. Elle reste donc hors de `verify`,
comme `check-links` et `check-html`. Il ne supprime rien non plus : un bitmoji
retiré d'une diapositive peut revenir la session suivante, une capture périmée
non, et ce tri-là se fait à la main.

Sortie 2 seulement quand la mesure n'a pas pu se faire (pas de dépôt git, pas
de `content/media/`). Un comptage qui n'a pas tourné ne doit pas ressembler à un
comptage vide.

Deux pièges de mesure, payés en comptant à la main (#573)
---------------------------------------------------------
1. **La sous-chaîne.** `output5_with_transparency.png` est contenu dans
   `images-output5_with_transparency.png` : un `grep -F` fait passer le premier
   pour référencé. Le nom est donc cherché entre deux limites de nom de fichier.
2. **Les noms non-ASCII.** Sans `-z`, `git ls-files` rend
   `"content/media/bac_\\303\\240_sable.png"`, échappé en octal ; comparés tels
   quels, sept fichiers utilisés passaient pour orphelins (124 au lieu de 117).
   Les noms sont en plus normalisés en NFC des deux côtés : le même `à` peut
   s'écrire en un ou deux points de code selon l'outil qui a créé le fichier.

Ce qui compte comme une référence
---------------------------------
Toute apparition du nom de base dans un fichier texte suivi par git, hors le
fichier lui-même. C'est large exprès : un nom cité dans un commentaire de script
(les relevés de palette de `gen_dockerfile_card.py` citent des PNG) compte comme
une référence. Mieux vaut un orphelin manqué qu'un fichier utilisé proposé à la
suppression. `content/media/` est à plat et ses noms de base sont uniques, donc
le nom de base suffit ; le script le vérifie plutôt que de le supposer.

Les fichiers générés et ignorés par git (`anatomie-*.svg`, `nommage-*.svg`,
`qrcode.png`) ne sont pas suivis, donc ni candidats ni sources.
"""

import re
import subprocess
import sys
import unicodedata
from pathlib import Path

MEDIA_DIR = "content/media/"

# Ce qui peut prolonger un nom de fichier de part et d'autre. Un point final
# seul reste permis derrière le nom, pour qu'une phrase qui se termine sur
# `logo.png.` compte ; un point suivi d'une extension (`logo.png.bak`), non.
# `\w` et non `[A-Za-z0-9_]` : sur une chaîne, il couvre les lettres accentuées,
# sans quoi `été.png` passerait pour cité dans `préété.png`. Les diacritiques
# combinants sont ajoutés à part, `\w` ne les couvre pas ; le texte est en NFC,
# mais un nom saisi en NFD dans un outil qui ne normalise pas y échapperait.
NAME_CHAR = r"\w\u0300-\u036f~\-"
BEFORE = rf"(?<![{NAME_CHAR}.])"
AFTER = rf"(?![{NAME_CHAR}])(?!\.[\w\u0300-\u036f])"


def nfc(text: str) -> str:
    return unicodedata.normalize("NFC", text)


def tracked_files(root: Path) -> list[str]:
    out = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        check=True,
        capture_output=True,
    ).stdout
    # Chemins rendus tels que git les stocke : ils servent à ouvrir les
    # fichiers, et une version normalisée peut ne pas exister sur le disque.
    # La normalisation se fait sur une copie, pour la seule comparaison.
    return [p for p in out.decode("utf-8").split("\0") if p]


def read_text(path: Path) -> str | None:
    data = path.read_bytes()
    if b"\0" in data[:8192]:
        return None
    return nfc(data.decode("utf-8", errors="replace"))


def human(size: int) -> str:
    return (
        f"{size / (1024 * 1024):.1f} Mio"
        if size >= 1024 * 1024
        else f"{size / 1024:.0f} Kio"
    )


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    try:
        files = tracked_files(root)
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"ERROR: git ls-files failed, nothing was measured: {exc}")
        return 2

    media = [p for p in files if nfc(p).startswith(MEDIA_DIR)]
    if not media:
        print(f"ERROR: no tracked file under {MEDIA_DIR}, nothing was measured.")
        return 2

    names = [nfc(p)[len(MEDIA_DIR) :] for p in media]
    nested = [n for n in names if "/" in n]
    dupes = {n for n in names if names.count(n) > 1}
    if nested or dupes:
        print(
            f"ERROR: {MEDIA_DIR} is no longer flat or has duplicate names;"
            " matching on the base name would be wrong. Update this script."
        )
        return 2

    # Un fichier suivi mais absent de l'arbre de travail (supprimé sans
    # commit) : le compte serait faux, donc pas de compte du tout.
    sources = {}
    sizes = {}
    try:
        for p in files:
            text = read_text(root / p)
            if text is not None:
                sources[nfc(p)] = text
        for p in media:
            sizes[p] = (root / p).stat().st_size
    except OSError as exc:
        print(f"ERROR: cannot read a tracked file, nothing was measured: {exc}")
        return 2

    # Une seule expression pour tous les noms : 336 expressions passées sur
    # chaque source prenaient dix secondes, celle-ci une fraction.
    any_name = re.compile(
        BEFORE + "(" + "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True)) + ")" + AFTER
    )
    referenced = set()
    for src, text in sources.items():
        for name in set(any_name.findall(text)):
            if src != MEDIA_DIR + name:
                referenced.add(name)

    orphans = [
        (path, sizes[path])
        for path, name in zip(media, names)
        if name not in referenced
    ]

    total = sum(size for _, size in orphans)
    for path, size in sorted(orphans):
        print(f"{human(size):>9}  {path}")
    print("")
    print(
        f"NOTE: {len(orphans)} of {len(media)} tracked files in {MEDIA_DIR}"
        f" are referenced nowhere, {human(total)}."
    )
    print("      Report only, nothing deleted, not part of `verify` (see issue #573).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
