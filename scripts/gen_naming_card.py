#!/usr/bin/env python3
"""Génère la carte « 📛 Nommage des containers » en SVG, en trois étapes.

Pourquoi ce script existe
-------------------------
Les trois diapositives `📛 Nommage des containers` affichaient
`fichiers-output47_with_transparency.png` à `49`, exportés d'un PowerPoint.
La sortie de `docker container ls` qu'elles montraient listait un conteneur
tournant sur l'image `centos` (#550), alors que le cours venait de remplacer
`centos` par `alpine` sur les cartes `🩻 Anatomie` (#547, #549). Deux chapitres
montraient donc deux images de base différentes pour le même propos.

Le défaut lui-même était léger — c'est de la sortie affichée, pas une commande
qu'un étudiant tape. Ce qui l'est moins, c'est qu'aucun garde-fou du dépôt ne
pouvait le voir : `check-dashes` lit la prose, `check-links` suit des URL,
`check-diagrams` compare des SVG à leur source. Une sortie enfermée dans un PNG
est invisible aux quatre, et il a fallu un balayage OCR des 268 PNG de
`content/media/` pour la trouver.

Ce que ce script produit est du texte : `grep` le voit. Le prochain `centos`
oublié ne pourra plus se cacher dans ces trois diapositives.

Ce qui a changé dans le contenu, au-delà de `centos`
----------------------------------------------------
La colonne COMMAND affichait `"/bin/bash"`. Une image `alpine` n'embarque pas
bash : la laisser telle quelle aurait remplacé une incohérence par une
affirmation fausse. Elle devient `"/bin/sh"`. Tout le reste de la ligne — id,
âge, statut, nom généré — est repris au caractère près.

Pourquoi la sortie n'est pas commitée
--------------------------------------
gen_dockerfile_card.py (#539) commite son SVG et le compare avec `--check`,
parce que là-bas la source de vérité est un fichier du dépôt dont l'image peut
dériver. Ici la source de vérité est ce script, et la sortie en est une fonction
pure : une copie commitée serait une seconde copie, qui ne peut que se périmer.
Les fichiers sont donc ignorés par git et régénérés à chaque `make build`, comme
`anatomie-*.svg` et `content/media/qrcode.png` le sont déjà. `check-assets` les
voit puisqu'il tourne après la construction.

Géométrie
---------
Les constantes sont **relevées au pixel** sur les trois PNG d'origine, à leur
taille native de 3233x1080, puis mises à l'échelle linéairement. Elles ne sont
pas estimées à l'œil :

- panneau `#D9D9D9`, ligne de commande `#022144` en gras, sortie `#000000`,
  pastille `#8064A2`, trait de rappel `#7030A0` ;
- chasse de 26,30 px pour la sortie et 37,40 px pour la ligne de commande ;
- les colonnes tombent sur une grille de 20 caractères — c'est le `minwidth`
  du tabwriter de l'ancien `docker ps`, donc ce remplissage est authentique et
  non décoratif.

Un détail relevé en passant : dans les PNG, le texte de la pastille n'est pas
blanc, il est **détouré en transparence**. Le `convert -transparent white` cité
par le bloc `[.notes]` de la diapositive l'a évidé, et il ne se lit comme blanc
que parce que la diapositive derrière lui est blanche. Le SVG écrit du blanc,
qui est ce que le support d'origine voulait dire.

Pour refaire le relevé, les PNG sont dans l'historique :
    git show f998555:content/media/fichiers-output48_with_transparency.png

Usage
-----
    python3 scripts/gen_naming_card.py content/media/nommage --steps
"""

import argparse
from pathlib import Path

# --- Palette, relevée au pixel (voir l'en-tête) ------------------------------
PANEL_FILL = "#D9D9D9"
CMD_INK = "#022144"
INK = "#000000"
PILL_FILL = "#8064A2"
LEADER = "#7030A0"
PILL_INK = "#FFFFFF"

# --- Le contenu --------------------------------------------------------------
PROMPT = "$"
COMMAND = "docker container ls"

# Une colonne par entrée, posée sur la grille de 20 caractères de l'ancien
# `docker ps`. PORTS est vide : le conteneur n'en publie aucun.
COLUMNS = [
    ("CONTAINER ID", "793906a4c2d2"),
    ("IMAGE", "alpine"),
    ("COMMAND", '"/bin/sh"'),
    ("CREATED", "3 hours ago"),
    ("STATUS", "Up 3 hours"),
    ("PORTS", ""),
    ("NAMES", "festive_poitras"),
]
COL_WIDTH = 20

# La dernière colonne ne tient pas dans le panneau et se replie sur une seconde
# ligne, exactement comme la zone de texte PowerPoint le faisait. Ce n'est pas
# un effet de bord : c'est cette ligne repliée que le trait de rappel souligne.
WRAP_AFTER = len(COLUMNS) - 1

CALLOUT = ["Une première", "alternative !"]
PROSE = [
    "Par défaut, Docker",
    "génère un nom en",
    "combinant une humeur et",
    "un inventeur.",
]

# --- Géométrie, relevée au pixel sur les PNG 3233x1080 -----------------------
REF_W = 3233
REF_H = 1080

PANEL = (6, 11, 3213, 556)          # x, y, largeur, hauteur
TEXT_X = 32
CMD_ADVANCE = 37.40                 # chasse de la ligne de commande
OUT_ADVANCE = 26.30                 # chasse de la sortie
MONO_RATIO = 0.60205                # chasse / corps, DejaVu Sans Mono
SAFE_RATIO = 0.63                   # chasse la plus large tolérée, voir fitting_size
CMD_BASELINE = 98
OUT_BASELINE = 189.8                # ligne d'en-tête
OUT_PITCH = 57.0

UNDERLINE = (27, 489, 384, 10)      # x1, x2, y, épaisseur
LEADER_PATH = (284, 386, 1911, 522, 9)   # x1, y1, x2, y2, épaisseur
PILL = (1511, 520, 802, 235, 85)    # x, y, largeur, hauteur, rayon
PILL_FS = 61
PILL_PITCH = 75
PILL_BASELINE = 622                 # première des deux lignes

PROSE_X = 442
PROSE_FS = 110
PROSE_PITCH = 131
PROSE_BASELINE = 677                # première des quatre lignes


def esc(text):
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def grid_line(index):
    """Une ligne de sortie posée sur la grille, repliée comme l'original.

    `index` vaut 0 pour l'en-tête et 1 pour la ligne de données. Rend le couple
    (ligne principale, ligne repliée) ; la seconde repart de la colonne 0.
    """
    cells = [col[index] for col in COLUMNS]
    main = "".join(c.ljust(COL_WIDTH) for c in cells[:WRAP_AFTER]).rstrip()
    return main, cells[WRAP_AFTER]


def name_span(scale):
    """(x de début, largeur) du nom généré sur la ligne repliée, en px."""
    return TEXT_X * scale, len(COLUMNS[WRAP_AFTER][1]) * OUT_ADVANCE * scale


def fitting_size():
    """Corps maximal de la sortie qui tient dans le panneau, en px de référence.

    Un SVG chargé dans une balise `img` n'a pas accès aux polices de la page et
    retombe sur celles du système, donc la chasse réelle n'est pas celle du
    relevé. Sur le contenu actuel la marge est large — 105 caractères, 2 762 px
    à la chasse de DejaVu Sans Mono (0,602 em) pour 3 187 px disponibles, il
    faudrait une chasse de 0,694 em pour déborder — et le plafond ne mord donc
    pas. Il n'est pas là pour réparer un débordement, il est là pour qu'une
    colonne ajoutée un jour fasse rétrécir le texte au lieu de le tronquer sans
    que rien ne le signale.
    """
    available = PANEL[0] + PANEL[2] - TEXT_X
    longest = max(len(line) for index in (0, 1) for line in grid_line(index))
    return available / (longest * SAFE_RATIO)


def build_svg(reveal, width=REF_W):
    """Une étape de la séquence.

    `reveal` va de 1 à 3 :
      1  le panneau et la sortie de `docker container ls`
      2  le soulignement, le trait de rappel et la pastille
      3  la phrase d'explication

    La géométrie ne dépend JAMAIS de `reveal` : les trois étapes partagent le
    même viewBox et les mêmes positions, donc reveal.js peut les interpoler
    d'une diapositive `[%auto-animate]` à la suivante. Même règle que dans
    gen_anatomy_card.py et gen_dockerfile_card.py, et c'est ce qui fait de la
    séquence une animation plutôt qu'une succession de sauts.
    """
    s = width / REF_W
    height = round(REF_H * s)

    cmd_fs = CMD_ADVANCE / MONO_RATIO * s
    out_fs = min(OUT_ADVANCE / MONO_RATIO, fitting_size()) * s
    text_x = TEXT_X * s

    parts = []

    px, py, pw, ph = (v * s for v in PANEL)
    parts.append(
        f'<rect x="{px:.1f}" y="{py:.1f}" width="{pw:.1f}" height="{ph:.1f}" '
        f'fill="{PANEL_FILL}"/>'
    )

    parts.append(
        f'<text x="{text_x:.1f}" y="{CMD_BASELINE * s:.1f}" class="cmd" '
        f'xml:space="preserve">{esc(PROMPT + " " + COMMAND)}</text>'
    )

    row = 0
    for index in (0, 1):
        main, wrapped = grid_line(index)
        for line in (main, wrapped):
            y = (OUT_BASELINE + OUT_PITCH * row) * s
            parts.append(
                f'<text x="{text_x:.1f}" y="{y:.1f}" class="out" '
                f'xml:space="preserve">{esc(line)}</text>'
            )
            row += 1

    if reveal >= 2:
        ux1, ux2, uy, uw = (v * s for v in UNDERLINE)
        parts.append(
            f'<path d="M {ux1:.1f} {uy:.1f} L {ux2:.1f} {uy:.1f}" '
            f'stroke="{LEADER}" stroke-width="{uw:.1f}" stroke-linecap="round" '
            f'fill="none"/>'
        )
        lx1, ly1, lx2, ly2, lw = (v * s for v in LEADER_PATH)
        parts.append(
            f'<path d="M {lx1:.1f} {ly1:.1f} L {lx2:.1f} {ly2:.1f}" '
            f'stroke="{LEADER}" stroke-width="{lw:.1f}" stroke-linecap="round" '
            f'fill="none"/>'
        )

        bx, by, bw, bh, brx = (v * s for v in PILL)
        parts.append(
            f'<rect x="{bx:.1f}" y="{by:.1f}" width="{bw:.1f}" height="{bh:.1f}" '
            f'rx="{brx:.1f}" fill="{PILL_FILL}"/>'
        )
        centre = bx + bw / 2
        for i, line in enumerate(CALLOUT):
            y = (PILL_BASELINE + PILL_PITCH * i) * s
            parts.append(
                f'<text x="{centre:.1f}" y="{y:.1f}" class="pill">{esc(line)}</text>'
            )

    if reveal >= 3:
        for i, line in enumerate(PROSE):
            y = (PROSE_BASELINE + PROSE_PITCH * i) * s
            parts.append(
                f'<text x="{PROSE_X * s:.1f}" y="{y:.1f}" class="prose">'
                f'{esc(line)}</text>'
            )

    main, wrapped = grid_line(1)
    aria = (
        f"Sortie de docker container ls : un conteneur {COLUMNS[1][1]}, "
        f"nommé {COLUMNS[WRAP_AFTER][1]}."
    )
    if reveal >= 2:
        aria += " Annotation : " + " ".join(CALLOUT)
    if reveal >= 3:
        aria += " " + " ".join(PROSE)

    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" role="img" aria-label="{esc(aria)}">
  <style>
    .cmd {{ font-family: "DejaVu Sans Mono", Menlo, Consolas, monospace; font-size: {cmd_fs:.1f}px; font-weight: bold; fill: {CMD_INK}; }}
    .out {{ font-family: "DejaVu Sans Mono", Menlo, Consolas, monospace; font-size: {out_fs:.1f}px; fill: {INK}; }}
    .pill {{ font-family: "Trebuchet MS", "Century Gothic", Verdana, sans-serif; font-size: {PILL_FS * s:.1f}px; text-anchor: middle; fill: {PILL_INK}; }}
    .prose {{ font-family: "Trebuchet MS", "Century Gothic", Verdana, sans-serif; font-size: {PROSE_FS * s:.1f}px; fill: {INK}; }}
  </style>
{chr(10).join("  " + p for p in parts)}
</svg>
"""


STEPS = 3


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("output", type=Path, help="préfixe, par ex. content/media/nommage")
    ap.add_argument("--width", type=int, default=REF_W)
    ap.add_argument(
        "--steps",
        action="store_true",
        help=f"produire la séquence <préfixe>-1.svg .. <préfixe>-{STEPS}.svg",
    )
    args = ap.parse_args()

    suffix = args.output.suffix or ".svg"
    stem = args.output.stem if args.output.suffix else args.output.name
    parent = args.output.parent
    parent.mkdir(parents=True, exist_ok=True)

    wanted = range(1, STEPS + 1) if args.steps else [STEPS]
    for k in wanted:
        path = parent / f"{stem}-{k}{suffix}" if args.steps else args.output
        path.write_text(build_svg(k, width=args.width), encoding="utf-8")

    print(f"OK: {len(list(wanted))} fichier(s) produit(s).")


if __name__ == "__main__":
    main()
