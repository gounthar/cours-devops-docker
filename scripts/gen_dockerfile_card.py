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
import re
import sys
from pathlib import Path

# Palette relevée au pixel sur `content/media/images-output56_with_transparency.png`,
# l'image exportée du support d'origine, plutôt qu'estimée à l'œil :
#   convert <png> -alpha remove txt:- puis comptage par bande de ligne.
# Les valeurs ci-dessous sont donc celles du support, pas une approximation.
BORDER = "#2496ED"
FOLD = "#D1D2D4"
INK = "#000000"
# Couleur du mot-clé d'instruction. Attention : elle ne suit PAS toujours celle
# de la pastille du groupe. `RUN` est en bleu Docker alors que sa pastille
# « commandes d'installation » est turquoise ; relevé sur l'original.
KEYWORD = {
    "FROM": "#8064A2",
    "LABEL": "#F79646",
    "MAINTAINER": "#F79646",
    "RUN": "#2496ED",
    "COPY": "#2496ED",
    "ADD": "#2496ED",
}
# Mise en valeur d'une commande *dans* l'argument. Sur l'original, `apk add` est
# en #558ED5 tandis que le `apk update` de la ligne au-dessus reste en noir : la
# couleur marque la commande d'installation, pas n'importe quelle commande. La
# liste reproduit cette sélectivité.
COMMAND = "#558ED5"
COMMAND_PREFIXES = (
    ("apk", "add"),
    ("apt-get", "install"),
    ("apt", "install"),
    ("dnf", "install"),
    ("yum", "install"),
    ("microdnf", "install"),
    ("npm", "install"),
    ("pip", "install"),
    ("pip3", "install"),
    ("gem", "install"),
)
GROUPS = {
    "base": ("#8064A2", "couche de base"),
    "metadata": ("#F79646", "metadata"),
    "install": ("#4BACC6", "commandes d'installation"),
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


def split_command(args):
    r"""Découpe l'argument en (commande_mise_en_valeur, reste).

    Renvoie ("", args) si rien ne correspond -- c'est le cas de `apk update`,
    volontairement, puisque l'original ne le met pas en valeur.

    Le découpage se fait sur la chaîne d'origine, pas sur une version
    renormalisée. Découper à `len(" ".join(mots))` casse dès que la source
    contient deux espaces : sur `apk  add --no-cache git`, le préfixe reconstruit
    fait 7 caractères alors que le vrai en fait 8, et le reste commençait par un
    `d` en trop. `(?!\S)` empêche par ailleurs `apk add` de mordre sur un
    hypothétique `apk addition`.
    """
    for prefix in COMMAND_PREFIXES:
        pattern = r"\s*" + r"\s+".join(re.escape(w) for w in prefix) + r"(?!\S)"
        m = re.match(pattern, args)
        if m:
            return m.group(0).strip(), args[m.end() :]
    return "", args


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


def build_svg(rows, width=1981, height=None, reveal=None):
    """Hauteur adaptative : une carte de trois lignes dans un canevas de 1080
    laisse les deux tiers en blanc, et la diapositive réduit alors le texte pour
    rien. Le SVG se met à l'échelle, donc autant coller au contenu.

    `reveal` limite l'affichage aux N premières pastilles, pour reproduire
    l'apparition progressive du support d'origine (quatre diapositives
    `[%auto-animate]` : le code seul, puis une pastille de plus à chaque fois).
    La géométrie ne dépend que du code, jamais des pastilles, donc toutes les
    étapes partagent exactement les mêmes positions et reveal.js peut les
    interpoler proprement. `None` affiche tout."""
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
        colour = KEYWORD.get(instruction, INK)
        command, rest = split_command(args)
        # xml:space="preserve" : sans lui, SVG mange l'espace de tête des tspans
        # suivants et la carte affiche « FROMalpine:3.24.1 ».
        spans = [f'<tspan class="kw" fill="{colour}">{esc(instruction)}</tspan>']
        if command:
            spans.append(f'<tspan class="kw" fill="{COMMAND}"> {esc(command)}</tspan>')
            spans.append(f'<tspan fill="{INK}">{esc(rest)}</tspan>')
        else:
            spans.append(f'<tspan fill="{INK}"> {esc(rest)}</tspan>')
        parts.append(
            f'<text x="{code_left:.0f}" y="{y:.0f}" class="code" xml:space="preserve">'
            + "".join(spans)
            + "</text>"
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
    if reveal is not None:
        ordered = ordered[:reveal]
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
        "--steps",
        action="store_true",
        help="produire la sequence d'apparition : <sortie>-1.svg (code seul) "
        "jusqu'a <sortie>-N.svg (toutes les pastilles)",
    )
    ap.add_argument(
        "--check",
        action="store_true",
        help="ne rien écrire ; sortir en 1 si la sortie existante est périmée",
    )
    args = ap.parse_args()

    if not args.dockerfile.is_file():
        sys.exit(f"ERREUR : {args.dockerfile} est introuvable.")

    rows = parse_dockerfile(args.dockerfile)

    if args.steps:
        groups = {g for _, _, g in rows if g}
        n = len(groups)
        # Etape 1 = le code seul, puis une pastille de plus a chaque etape.
        wanted = [
            (
                args.output.with_name(f"{args.output.stem}-{k + 1}{args.output.suffix}"),
                build_svg(rows, width=args.width, reveal=k),
            )
            for k in range(n + 1)
        ]
    else:
        wanted = [(args.output, build_svg(rows, width=args.width))]

    # Fichiers d'etapes perimes. Si le Dockerfile perd un groupe -- un `LABEL`
    # retire, par exemple -- la sequence raccourcit, mais l'ancienne derniere
    # etape reste sur le disque. `images.adoc` continue de la referencer,
    # `check-assets` la trouve puisqu'elle existe, et `--check` ne la voyait pas
    # puisqu'il ne verifiait que les fichiers qu'il aurait ecrits. Resultat : une
    # barriere verte au-dessus d'une diapositive perimee, c'est-a-dire tout ce
    # que ce script existe pour empecher.
    stale = []
    if args.steps:
        expected = {path for path, _ in wanted}
        pattern = re.compile(re.escape(args.output.stem) + r"-\d+$")
        for sibling in args.output.parent.glob(f"{args.output.stem}-*{args.output.suffix}"):
            if pattern.fullmatch(sibling.stem) and sibling not in expected:
                stale.append(sibling)

    if args.check:
        if stale:
            noms = ", ".join(sorted(f.name for f in stale))
            sys.exit(
                f"ERREUR : etape(s) perimee(s) a cote de la sequence attendue : {noms}.\n"
                f"       {args.dockerfile} ne produit plus que {len(wanted)} etapes.\n"
                f"       Lancer 'make diagrams', qui les supprimera, puis verifier\n"
                f"       que le deck ne les reference plus."
            )
        for path, svg in wanted:
            if not path.is_file():
                sys.exit(
                    f"ERREUR : {path} est absent.\n"
                    f"       Lancer 'make diagrams' pour le produire."
                )
            if path.read_text(encoding="utf-8") != svg:
                sys.exit(
                    f"ERREUR : {path} ne correspond plus à {args.dockerfile}.\n"
                    f"       C'est exactement la désynchronisation de #537.\n"
                    f"       Lancer 'make diagrams' et committer le résultat."
                )
        noun = "sont à jour" if len(wanted) > 1 else "est à jour"
        print(f"OK: {len(wanted)} fichier(s) {noun} par rapport à {args.dockerfile}")
        return

    args.output.parent.mkdir(parents=True, exist_ok=True)
    for path, svg in wanted:
        path.write_text(svg, encoding="utf-8")
    # Ces fichiers ne sont produits que par ce script : les effacer est sans
    # risque et evite qu'une etape orpheline survive a un raccourcissement.
    for path in stale:
        path.unlink()
        print(f"SUPPRIME: {path} (etape perimee)")
    print(f"OK: {len(wanted)} fichier(s) produit(s) depuis {args.dockerfile}")


if __name__ == "__main__":
    main()
