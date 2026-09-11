#!/usr/bin/env python3
"""Génère la carte « 🩻 Anatomie » en SVG, avec la date du moment de la construction.

Pourquoi ce script existe
-------------------------
Les huit diapositives `🩻 Anatomie` affichaient `output3_with_transparency.png`
à `output10_with_transparency.png`, exportés d'un PowerPoint. Trois défauts, de
gravité croissante (#548) :

1. la carte montrait `Mon Sep  25 19:33:19 UTC 2023` — or elle existe
   précisément pour démontrer qu'un conteneur exécute une commande **et rend son
   résultat du moment**. Une démonstration de fraîcheur datée de trois ans ;
2. du PNG là où c'est du texte sur fond uni ;
3. le contenu était invisible à l'outillage, et ça a déjà mordu : #547, une
   commande de la carte qui ne s'exécutait plus, invisible à `grep` parce
   qu'elle était dans une image. Il a fallu un balayage OCR pour la trouver.

Ce que ce script produit est du texte : `grep` le voit, donc le défaut de #547
ne peut plus se cacher.

Ce qui le distingue de gen_dockerfile_card.py (#539)
----------------------------------------------------
Là-bas la source de vérité est un fichier du dépôt, la sortie est déterministe,
elle est commitée et `--check` la compare. Ici la carte porte **une horodate**,
donc elle n'est pas déterministe et ce modèle ne s'applique pas : `--check`
échouerait à tous les coups et la copie commitée serait périmée dès le commit.

Les fichiers produits sont donc **ignorés par git** et régénérés à chaque
`make build`, comme `content/media/qrcode.png` l'est déjà. `check-assets` les
voit puisqu'il tourne après la construction.

Ce que ce script ne fait pas
----------------------------
Il n'exécute pas Docker. Estampiller `date -u` au moment de la génération donne
le moment de la construction — ce que la commande afficherait à cet instant —
sans mettre un tirage de registre sur le chemin de `make build`. Exécuter les
commandes pour de vrai garde toute sa valeur, mais pour l'autre objectif :
prouver que l'image se résout encore. Les deux se séparent :

    date = moment de la construction  -> ici, sans Docker
    la commande fonctionne encore     -> job planifié, hors `build`

Usage
-----
    python3 scripts/gen_anatomy_card.py content/media/anatomie --steps
    python3 scripts/gen_anatomy_card.py content/media/anatomie --steps \\
        --at 2023-09-25T19:33:19            # horodate figée, pour les tests
"""

import argparse
import sys
import time
from pathlib import Path

# Palette relevée au pixel sur `content/media/output10_with_transparency.png`
# plutôt qu'estimée à l'œil, comme pour gen_dockerfile_card.py. Les trois
# couleurs d'annotation sont d'ailleurs EXACTEMENT celles de ce script : les
# deux illustrations viennent du même thème PowerPoint.
PANEL_FILL = "#D9D9D9"
PANEL_BORDER = "#1C334E"
INK = "#000000"
PAPER = "#FFFFFF"
PILL_INK = "#FFFFFF"

PURPLE = "#8064A2"
TEAL = "#4BACC6"
ORANGE = "#F79646"

# Les deux terminaux de la carte. Chaque commande est découpée en trois
# fragments, un par annotation : c'est ce découpage qui place les surlignages,
# et il est donc la structure de l'illustration, pas une commodité.
#
# `output=None` veut dire « la sortie est l'horodate », calculée à la
# génération. Voir l'en-tête pour pourquoi ce n'est pas `docker run`.
PANELS = [
    {
        "fragments": ["docker container run", "busybox", "echo hello world"],
        "output": "hello world",
    },
    {
        "fragments": ["docker container run", "alpine", "date"],
        "output": None,
    },
]

# (libellé, couleur, index du fragment annoté). Le libellé peut tenir sur deux
# lignes, comme sur le support d'origine.
ANNOTATIONS = [
    ("Lancement\nd'un container", PURPLE, 0),
    ("Image", TEAL, 1),
    ("Commande lancée", ORANGE, 2),
]

PROMPT = "$"

# Largeur d'un caractère à chasse fixe, en fraction de la taille de police.
# 0.6 est la valeur des fontes DejaVu Sans Mono / Menlo / Consolas.
MONO_RATIO = 0.6
# Idem pour la fonte proportionnelle des pastilles. Estimation généreuse : une
# pastille trop large est sans conséquence, une pastille trop étroite tronque
# son texte.
SANS_RATIO = 0.56


def stamp(when):
    """L'horodate au format exact que rend `date` dans un conteneur.

    Mesuré côte à côte plutôt que supposé : `docker container run alpine date`
    rend `Fri Sep 11 08:33:48 UTC 2026`, et ce format lui correspond au
    caractère près. Le jour est complété à l'espace à la main plutôt que par
    `%e`, qui est une extension glibc et n'existe pas partout.
    """
    day = f"{when.tm_mday:2d}"
    return time.strftime(f"%a %b {day} %H:%M:%S UTC %Y", when)


def esc(text):
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def panel_lines(panel, when):
    """(ligne de commande, ligne de sortie) du panneau."""
    command = " ".join(panel["fragments"])
    output = panel["output"]
    if output is None:
        output = stamp(when)
    return f"{PROMPT} {command}", output


def fragment_span(panel, index):
    """(colonne de début, longueur) du fragment, en caractères, prompt compris.

    Compté sur la ligne telle qu'elle est écrite, donc un fragment qui change de
    longueur déplace tout seul son surlignage.
    """
    start = len(PROMPT) + 1
    for i, fragment in enumerate(panel["fragments"]):
        if i == index:
            return start, len(fragment)
        start += len(fragment) + 1
    raise IndexError(index)


def build_svg(when, reveal, width=1981):
    """Une étape de la séquence.

    `reveal` va de 1 à 8 :
      1  les deux invites, vides
      2  la commande du premier terminal
      3  sa sortie
      4  la commande du second terminal
      5  sa sortie
      6  la première annotation, 7 la deuxième, 8 la troisième

    La géométrie ne dépend JAMAIS de `reveal` : toutes les étapes partagent les
    mêmes positions, donc reveal.js peut les interpoler proprement d'une
    diapositive `[%auto-animate]` à la suivante. C'est la même règle que dans
    gen_dockerfile_card.py, et c'est ce qui fait de la séquence une animation
    plutôt qu'une succession de sauts.
    """
    margin = int(width * 0.004)
    pad_x = int(width * 0.012)

    # La police est choisie sur la ligne la plus longue des deux terminaux, pour
    # qu'aucune ne déborde : les deux panneaux partagent la même, sinon les
    # surlignages ne s'alignent pas d'un panneau à l'autre.
    longest = max(len(line) for panel in PANELS for line in panel_lines(panel, when))
    font_size = int((width - 2 * (margin + pad_x)) / (longest * MONO_RATIO))

    line_h = font_size * 1.46
    panel_h = line_h * 2 + font_size * 1.5
    gap_h = panel_h * 0.62
    height = int(margin * 2 + panel_h * 2 + gap_h)

    panel_x = margin
    panel_w = width - 2 * margin
    panel_y = [margin, margin + panel_h + gap_h]

    text_x = panel_x + pad_x
    # Ligne de base de la commande, puis de la sortie, dans chaque panneau.
    baselines = [
        [top + font_size * 1.5, top + font_size * 1.5 + line_h] for top in panel_y
    ]

    parts = []
    for top in panel_y:
        parts.append(
            f'<rect x="{panel_x}" y="{top:.0f}" width="{panel_w}" height="{panel_h:.0f}" '
            f'fill="{PANEL_FILL}" stroke="{PANEL_BORDER}" '
            f'stroke-width="{max(3, width // 330)}"/>'
        )

    # Les surlignages d'abord, pour qu'ils passent DERRIÈRE le texte.
    shown_annotations = ANNOTATIONS[: max(0, reveal - 5)]
    for _, colour, index in shown_annotations:
        for p, panel in enumerate(PANELS):
            if reveal < 2 + 2 * p:  # la commande de ce panneau n'est pas encore là
                continue
            col, length = fragment_span(panel, index)
            hx = text_x + col * font_size * MONO_RATIO
            hw = length * font_size * MONO_RATIO
            hy = baselines[p][0] - font_size * 0.92
            parts.append(
                f'<rect x="{hx:.0f}" y="{hy:.0f}" width="{hw:.0f}" '
                f'height="{font_size * 1.2:.0f}" fill="{colour}"/>'
            )

    for p, panel in enumerate(PANELS):
        command, output = panel_lines(panel, when)
        shown = PROMPT if reveal < 2 + 2 * p else command
        parts.append(
            f'<text x="{text_x}" y="{baselines[p][0]:.0f}" class="code" '
            f'xml:space="preserve">{esc(shown)}</text>'
        )
        if reveal >= 3 + 2 * p:
            parts.append(
                f'<text x="{text_x}" y="{baselines[p][1]:.0f}" class="code" '
                f'xml:space="preserve">{esc(output)}</text>'
            )

    # Les pastilles, dans la bande blanche entre les deux panneaux. Chacune est
    # centrée sur le fragment qu'elle annote, puis ramenée dans le cadre.
    pill_fs = int(font_size * 0.92)
    pill_line_h = pill_fs * 1.18
    gap_top = panel_y[0] + panel_h
    for label, colour, index in shown_annotations:
        rows = label.split("\n")
        pill_h = pill_line_h * len(rows) + pill_fs * 0.8
        pill_w = max(len(r) for r in rows) * pill_fs * SANS_RATIO + pill_fs * 1.6
        col, length = fragment_span(PANELS[0], index)
        centre = text_x + (col + length / 2) * font_size * MONO_RATIO
        px = centre - pill_w / 2
        px = max(margin + pad_x, min(px, width - margin - pad_x - pill_w))
        py = gap_top + (gap_h - pill_h) / 2

        # Les traits de rappel avant la pastille, pour qu'ils passent dessous.
        for p, panel in enumerate(PANELS):
            if reveal < 2 + 2 * p:
                continue
            col_p, length_p = fragment_span(panel, index)
            tx = text_x + (col_p + length_p / 2) * font_size * MONO_RATIO
            ty = baselines[p][0] + (font_size * 0.28 if p == 0 else -font_size * 0.92)
            parts.append(
                f'<path d="M {px + pill_w / 2:.0f} {py + pill_h / 2:.0f} '
                f'L {tx:.0f} {ty:.0f}" stroke="{colour}" '
                f'stroke-width="{max(3, font_size // 10)}" fill="none" '
                f'stroke-linecap="round"/>'
            )

        parts.append(
            f'<rect x="{px:.0f}" y="{py:.0f}" width="{pill_w:.0f}" '
            f'height="{pill_h:.0f}" rx="{pill_h / 2:.0f}" fill="{colour}"/>'
        )
        first = (
            py + pill_fs * 1.2 + (pill_h - pill_line_h * len(rows) - pill_fs * 0.8) / 2
        )
        for r, row in enumerate(rows):
            parts.append(
                f'<text x="{px + pill_w / 2:.0f}" y="{first + r * pill_line_h:.0f}" '
                f'class="pill" fill="{PILL_INK}">{esc(row)}</text>'
            )

    aria = (
        "Deux terminaux : docker container run busybox echo hello world, "
        "et docker container run alpine date. Annotations : lancement d'un "
        "container, image, commande lancée."
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" role="img" aria-label="{esc(aria)}">
  <style>
    .code {{ font-family: "DejaVu Sans Mono", Menlo, Consolas, monospace; font-size: {font_size}px; fill: {INK}; }}
    .pill {{ font-family: "Trebuchet MS", "Century Gothic", Verdana, sans-serif; font-size: {pill_fs}px; text-anchor: middle; }}
  </style>
  <rect width="{width}" height="{height}" fill="{PAPER}"/>
{chr(10).join("  " + p for p in parts)}
</svg>
"""


STEPS = 5 + len(ANNOTATIONS)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("output", type=Path, help="préfixe, par ex. content/media/anatomie")
    ap.add_argument("--width", type=int, default=1981)
    ap.add_argument(
        "--steps",
        action="store_true",
        help=f"produire la séquence <préfixe>-1.svg .. <préfixe>-{STEPS}.svg",
    )
    ap.add_argument(
        "--at",
        help="horodate figée au format ISO (2023-09-25T19:33:19), pour les tests ; "
        "par défaut, le moment de la génération en UTC",
    )
    ap.add_argument(
        "--print-commands",
        action="store_true",
        help="écrire les commandes dessinées, une par ligne, au format "
        "commande<TAB>sortie attendue (vide = non comparée), puis sortir",
    )
    args = ap.parse_args()

    # La carte et le job qui vérifie que ces commandes fonctionnent encore
    # lisent ainsi la MÊME liste. Une seconde copie quelque part, ce serait
    # exactement la divergence que ce script existe pour supprimer.
    if args.print_commands:
        for panel in PANELS:
            command = " ".join(panel["fragments"])
            print(f"{command}\t{panel['output'] or ''}")
        return

    if args.at:
        try:
            when = time.strptime(args.at, "%Y-%m-%dT%H:%M:%S")
        except ValueError as exc:
            sys.exit(f"ERREUR : --at attend 2023-09-25T19:33:19 ({exc}).")
    else:
        when = time.gmtime()

    suffix = args.output.suffix or ".svg"
    stem = args.output.stem if args.output.suffix else args.output.name
    parent = args.output.parent
    parent.mkdir(parents=True, exist_ok=True)

    wanted = range(1, STEPS + 1) if args.steps else [STEPS]
    for k in wanted:
        path = parent / f"{stem}-{k}{suffix}" if args.steps else args.output
        path.write_text(build_svg(when, k, width=args.width), encoding="utf-8")

    print(f"OK: {len(list(wanted))} fichier(s) produit(s), horodate {stamp(when)}")


if __name__ == "__main__":
    main()
