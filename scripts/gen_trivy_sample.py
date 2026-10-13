#!/usr/bin/env python3
"""Génère content/trivy.adoc : le résultat Trivy affiché dans les diapositives.

Pourquoi ce script existe
-------------------------
La diapositive « Exemple de résultat Trivy » (chapitre sécurité) affichait un
total recopié à la main : 3277 le matin du 2026-10-13, déjà 3602 le soir même
avec la même version de Trivy. La base de vulnérabilités change tous les
jours, et l'image scannée change aussi : c'est celle du backend phase1 de
SecureVote, que updatecli fait monter d'une version de Python par an
(updatecli/updatecli.d/securevote-python.yaml). Un chiffre recopié ne peut
que se périmer.

Ce script lance le scan et écrit des attributs AsciiDoc que la diapositive
affiche. Il tourne dans le workflow trivy-sample.yml, qui ouvre une PR quand
le fichier change : le chiffre publié est daté et passe par une relecture.
`make build` ne lance donc pas Docker (même choix que pour la carte Anatomie,
#548 : une construction qui dépend du Hub finit ignorée).

Ce que mesure le total
----------------------
Le même nombre que la ligne `Total:` de la sortie tableau de Trivy pour la
cible système (`python:3.11 (debian 13.7)`), c'est-à-dire les paquets de la
distribution. Les paquets Python de l'image (pip, setuptools) sont une cible
à part, avec leur propre ligne `Total:`, et ne sont pas comptés ici.

Usage : scripts/gen_trivy_sample.py [fichier de sortie]
(par défaut content/trivy.adoc ; nécessite Docker et le réseau)
"""

import datetime
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCKERFILE = ROOT / "content/code-samples/securevote/phase1/backend/Dockerfile"
DEFAULT_OUTPUT = ROOT / "content/trivy.adoc"

# Toujours une version épinglée : voir l'incident de mars 2026 raconté dans
# le chapitre sécurité. Même version que les commandes des diapositives.
TRIVY_IMAGE = os.environ.get("TRIVY_IMAGE", "aquasec/trivy:0.75.0")

SEVERITIES = ["UNKNOWN", "LOW", "MEDIUM", "HIGH", "CRITICAL"]


def phase1_image():
    """Lit l'image de base du backend phase1 (première ligne FROM)."""
    for line in DOCKERFILE.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*FROM\s+(\S+)", line, re.IGNORECASE)
        if m:
            return m.group(1)
    sys.exit(f"Aucune ligne FROM dans {DOCKERFILE}")


def scan(image, cache):
    """Scanne l'image, renvoie (cible système, compteur par sévérité, rapport)."""
    subprocess.run(
        [
            "docker",
            "container",
            "run",
            "--rm",
            # Sous l'utilisateur courant : en root, le cache appartiendrait à
            # root sur l'hôte et le dossier temporaire ne pourrait pas être
            # supprimé.
            "--user",
            f"{os.getuid()}:{os.getgid()}",
            "-v",
            f"{cache}:/cache",
            TRIVY_IMAGE,
            "image",
            "--cache-dir",
            "/cache",
            "--quiet",
            "--format",
            "json",
            "--output",
            "/cache/report.json",
            image,
        ],
        check=True,
    )
    report = json.loads((Path(cache) / "report.json").read_text(encoding="utf-8"))
    os_results = [r for r in report.get("Results", []) if r.get("Class") == "os-pkgs"]
    if len(os_results) != 1:
        sys.exit(f"{image} : {len(os_results)} cible(s) système, une seule attendue")
    result = os_results[0]
    counts = Counter(v["Severity"] for v in result.get("Vulnerabilities") or [])
    return result["Target"], counts, report


def trivy_version():
    out = subprocess.run(
        ["docker", "container", "run", "--rm", TRIVY_IMAGE, "--version"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    m = re.search(r"Version:\s*(\S+)", out)
    return m.group(1) if m else TRIVY_IMAGE.rsplit(":", 1)[-1]


def total_line(counts):
    """Reproduit la ligne `Total:` de la sortie tableau de Trivy."""
    detail = ", ".join(f"{s}: {counts.get(s, 0)}" for s in SEVERITIES)
    return f"Total: {sum(counts.values())} ({detail})"


def main():
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    image = phase1_image()
    repo, _, tag = image.partition(":")
    slim = f"{repo}:{tag.split('-')[0]}-slim"

    # Base de vulnérabilités dans un dossier temporaire, partagée par les
    # deux scans : elle n'a rien à faire dans le dépôt.
    with tempfile.TemporaryDirectory() as cache:
        target, counts, report = scan(image, cache)
        _, slim_counts, _ = scan(slim, cache)
    os_info = report.get("Metadata", {}).get("OS", {})
    distro = (
        f"{os_info.get('Family', '').capitalize()} {os_info.get('Name', '')}".strip()
    )

    lines = [
        "// Généré par scripts/gen_trivy_sample.py : ne pas modifier à la main.",
        "// Mis à jour par le workflow trivy-sample.yml, qui ouvre une PR.",
        f":trivy-image: {image}",
        f":trivy-target: {target}",
        f":trivy-distro: {distro}",
        f":trivy-total: {sum(counts.values())}",
        f":trivy-total-line: {total_line(counts)}",
        f":trivy-slim-image: {slim}",
        f":trivy-slim-total: {sum(slim_counts.values())}",
        f":trivy-version: {trivy_version()}",
        f":trivy-date: {datetime.date.today().isoformat()}",
    ]
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(
        f"{output} : {image} {total_line(counts)} ; {slim} {sum(slim_counts.values())}"
    )


if __name__ == "__main__":
    main()
