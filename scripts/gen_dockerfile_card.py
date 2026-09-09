#!/usr/bin/env python3
"""Génère la carte « Dockerfile » annotée, en SVG, à partir d'un vrai Dockerfile.

Pourquoi ce script existe
-------------------------
La diapositive du défi JRE affichait un PNG exporté d'un PowerPoint, et le PNG
recopiait le contenu du Dockerfile. Les deux ont divergé : dependabot a monté
l'étiquette Alpine du Dockerfile onze fois depuis janvier 2025, et le PNG, lui,
n'a pas bougé depuis son export du 2023-09-21. Il montrait encore `alpine:3.18`
et un `RUN apk update` supprimé depuis (#527).

Un PNG ne peut pas suivre. Le seul correctif durable est de supprimer la copie :
la carte est désormais *dérivée* du Dockerfile, donc elle ne peut plus le
contredire. Voir #537.

Usage
-----
    python3 scripts/gen_dockerfile_card.py <Dockerfile> <sortie.svg> [--width N]
    python3 scripts/gen_dockerfile_card.py <Dockerfile> <sortie.svg> --check

`--check` n'écrit rien et sort en 1 si le fichier existant ne correspond plus à
ce que le Dockerfile produirait. C'est ce que `make check-diagrams` exécute.
"""

import argparse
import sys
from pathlib import Path

# Palette reprise du support d'origine, pour que la carte ne détonne pas à côté
# des autres images exportées du même PowerPoint.
BORDER = "#29abe2"
FOLD = "#c9c9c9"
INK = "#1a1a1a"
GROUPS = {
    "base": ("#7b5ea7", "couche de base"),
    "metadata": ("#f1953d", "metadata"),
    "install": ("#4a9cb8", "commandes d'installation"),
}
# Quelle instruction appartient à quel groupe d'annotation.
INSTRUCTION_GROUP = {
    "FROM": "base",
    "LABEL": "metadata",
    "MAINTAINER": "metadata",
    "RUN": "install",
    "COPY": "install",
    "ADD": "install",
}
# Largeur d'un caractère en fonte à chasse fixe, en fraction de la taille de
# police. 0.6 est la valeur des fontes DejaVu Sans Mono / Menlo / Consolas.
MONO_RATIO = 0.6
# Idem pour la fonte proportionnelle des pastilles. Estimation volontairement
# généreuse : une pastille trop large est sans conséquence, une pastille trop
# étroite tronque son texte.
SANS_RATIO = 0.56


def parse_dockerfile(path):
    """Renvoie [(instruction, arguments, groupe|None), ...] et les lignes vides.

    Les commentaires sont ignorés : ils servent le lecteur du dépôt, pas la
    diapositive. Les lignes vides sont conservées, parce qu'elles portent le
    rythme visuel de la carte.
    """
    rows = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        if not line.strip():
            # Pas deux séparateurs de suite, et jamais en tête.
            if rows and rows[-1][0] is not None:
                rows.append((None, "", None))
            continue
        if line.lstrip().startswith("#"):
            continue
        head, _, rest = line.partition(" ")
        instruction = head.upper()
        rows.append((instruction, rest.strip(), INSTRUCTION_GROUP.get(instruction)))
    while rows and rows[-1][0] is None:
        rows.pop()
    return rows


def esc(text):
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def build_svg(rows, width=1981, height=None):
    """Hauteur adaptative : une carte de trois lignes dans un canevas de 1080
    laisse les deux tiers en blanc, et la diapositive réduit alors le texte pour
    rien. Le SVG se met à l'échelle, donc autant coller au contenu."""
    code_rows = [r for r in rows if r[0] is not None]
    if not code_rows:
        raise SystemExit("ERREUR : aucune instruction trouvée dans le Dockerfile.")

    fold = int(width * 0.062)
    margin = int(width * 0.004)
    pad_x = int(width * 0.042)

    # Deux colonnes : le code à gauche, les pastilles à droite. Le code ne doit
    # jamais déborder sous les pastilles, sinon les lignes de rappel traversent
    # le texte -- c'est ce que faisait la première version.
    code_left = margin + pad_x
    pill_col_left = width * 0.63
    longest = max(len(f"{i} {a}".strip()) for i, a, _ in code_rows)
    font_size = min(
        64, int((pill_col_left - code_left - width * 0.03) / (longest * MONO_RATIO))
    )

    # Hauteur : les lignes vides comptent pour une demi-interligne.
    line_h = font_size * 1.72
    units = sum(1.0 if r[0] is not None else 0.55 for r in rows)
    block_h = units * line_h
    if height is None:
        # Assez de marge pour le libellé « Dockerfile » en haut et le coin corné.
        height = int(max(block_h + font_size * 5.2, width * 0.30))
    y = (height - block_h) / 2 + font_size * 1.1

    parts = []
    pill_targets = {}  # groupe -> [(x_fin_de_ligne, y_milieu_de_ligne), ...]

    for instruction, args, group in rows:
        if instruction is None:
            y += line_h * 0.55
            continue
        colour = GROUPS[group][0] if group else INK
        # xml:space="preserve" : sans lui, SVG mange l'espace de tête du second
        # tspan et la carte affiche « FROMalpine:3.24.1 ».
        parts.append(
            f'<text x="{code_left:.0f}" y="{y:.0f}" class="code" xml:space="preserve">'
            f'<tspan class="kw" fill="{colour}">{esc(instruction)}</tspan>'
            f'<tspan fill="{INK}"> {esc(args)}</tspan></text>'
        )
        if group:
            full = f"{instruction} {args}".strip()
            end_x = code_left + len(full) * font_size * MONO_RATIO
            pill_targets.setdefault(group, []).append((end_x, y - font_size * 0.34))
        y += line_h

    # Cadre : coin supérieur gauche coupé en diagonale, comme une feuille cornée.
    x0, y0 = margin, margin
    x1, y1 = width - margin, height - margin
    r = int(width * 0.012)
    card = (
        f"M {x0 + fold} {y0} H {x1 - r} A {r} {r} 0 0 1 {x1} {y0 + r} "
        f"V {y1 - r} A {r} {r} 0 0 1 {x1 - r} {y1} "
        f"H {x0 + r} A {r} {r} 0 0 1 {x0} {y1 - r} "
        f"V {y0 + fold} Z"
    )

    pills = []
    # Ordre stable : l'ordre d'apparition dans le Dockerfile, pas celui du dict.
    ordered = [g for g in ("base", "metadata", "install") if g in pill_targets]
    pill_h = int(font_size * 1.24)
    pill_fs = int(font_size * 0.62)
    # Chaque pastille est posée à la hauteur de la ou des lignes qu'elle annote,
    # puis décalée si elle chevauche la précédente. La ligne de rappel part du
    # bord gauche de la pastille et s'arrête à la fin du texte annoté, donc elle
    # ne traverse jamais le code.
    placed = []
    for group in ordered:
        colour, label = GROUPS[group]
        text_w = len(label) * pill_fs * SANS_RATIO
        pill_w = text_w + pill_fs * 1.8
        px = width - margin - pad_x - pill_w
        targets = pill_targets[group]
        cy = sum(t[1] for t in targets) / len(targets)
        py = cy - pill_h / 2
        gap = pill_h * 0.45
        for prev in placed:
            if py < prev + pill_h + gap and py + pill_h + gap > prev:
                py = prev + pill_h + gap
        py = max(margin + pad_x * 0.4, min(py, height - margin - pad_x * 0.4 - pill_h))
        placed.append(py)
        pills.append(
            f'<rect x="{px:.0f}" y="{py:.0f}" width="{pill_w:.0f}" height="{pill_h}" '
            f'rx="{pill_h // 2}" fill="{colour}"/>'
            f'<text x="{px + pill_w / 2:.0f}" y="{py + pill_h * 0.7:.0f}" '
            f'class="pill" fill="#ffffff">{esc(label)}</text>'
        )
        for tx, ty in targets:
            pills.append(
                f'<path d="M {px - 12:.0f} {py + pill_h / 2:.0f} L {tx + 36:.0f} {ty:.0f}" '
                f'stroke="{colour}" stroke-width="{max(4, font_size // 16)}" fill="none" '
                f'stroke-linecap="round"/>'
            )

    label_fs = int(font_size * 0.66)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" role="img" aria-label="Structure d'un Dockerfile : couche de base, metadata, commandes d'installation">
  <style>
    .code {{ font-family: "DejaVu Sans Mono", Menlo, Consolas, monospace; font-size: {font_size}px; }}
    .kw {{ font-weight: 700; }}
    .pill {{ font-family: "Trebuchet MS", "Century Gothic", Verdana, sans-serif; font-size: {pill_fs}px; text-anchor: middle; }}
    .filename {{ font-family: "Trebuchet MS", "Century Gothic", Verdana, sans-serif; font-size: {label_fs}px; text-anchor: end; fill: {BORDER}; }}
  </style>
  <path d="{card}" fill="#ffffff" stroke="{BORDER}" stroke-width="{max(6, width // 190)}" stroke-linejoin="round"/>
  <path d="M {x0} {y0 + fold} L {x0 + fold} {y0} L {x0 + fold} {y0 + fold} Z" fill="{FOLD}"/>
  <text x="{x1 - pad_x * 0.5:.0f}" y="{y0 + label_fs * 1.6:.0f}" class="filename">Dockerfile</text>
{chr(10).join("  " + p for p in parts)}
{chr(10).join("  " + p for p in pills)}
</svg>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("dockerfile", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--width", type=int, default=1981)
    ap.add_argument(
        "--check",
        action="store_true",
        help="ne rien écrire ; sortir en 1 si la sortie existante est périmée",
    )
    args = ap.parse_args()

    if not args.dockerfile.is_file():
        sys.exit(f"ERREUR : {args.dockerfile} est introuvable.")

    svg = build_svg(parse_dockerfile(args.dockerfile), width=args.width)

    if args.check:
        if not args.output.is_file():
            sys.exit(
                f"ERREUR : {args.output} est absent.\n"
                f"       Lancer 'make diagrams' pour le produire."
            )
        if args.output.read_text(encoding="utf-8") != svg:
            sys.exit(
                f"ERREUR : {args.output} ne correspond plus à {args.dockerfile}.\n"
                f"       C'est exactement la désynchronisation de #537.\n"
                f"       Lancer 'make diagrams' et committer le résultat."
            )
        print(f"OK: {args.output} est à jour par rapport à {args.dockerfile}")
        return

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(svg, encoding="utf-8")
    print(f"OK: {args.output} produit depuis {args.dockerfile}")


if __name__ == "__main__":
    main()
