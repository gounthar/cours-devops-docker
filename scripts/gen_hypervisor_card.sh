#!/usr/bin/env bash
#
# Produit content/media/hyperviseurs-type-1.png, l'illustration des hyperviseurs
# de type 1 du chapitre d'introduction. Voir les issues #525 (XCP-ng absent de
# l'image d'origine) et #448 (la slide qui la porte).
#
# La provenance de chacun des six logos est dans scripts/logo-sources/PROVENANCE.md,
# y compris les coordonnées de découpe et pourquoi elles valent ce qu'elles valent.
#
# Ce script n'est pas branché sur `make verify` : contrairement aux cartes Dockerfile
# de #539, cette image ne dérive de rien qui change. Elle est régénérée à la main le
# jour où la liste des produits bouge.

set -euo pipefail

if ! command -v convert >/dev/null || ! command -v montage >/dev/null; then
  echo "Erreur : ImageMagick est requis (convert et montage)." >&2
  echo "Installer avec : sudo apt-get install imagemagick" >&2
  exit 1
fi

# `CDPATH=` et la redirection : avec un CDPATH exporté, `cd` écrit le répertoire
# résolu sur stdout et `$(cd ... && pwd)` renvoie alors le chemin en double.
ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)"
SRC="$ROOT/scripts/logo-sources"
ORIG="$ROOT/content/media/type-1-hypervisor-examples.png"
OUT="${1:-$ROOT/content/media/hyperviseurs-type-1.png}"

if [ ! -f "$ORIG" ]; then
  echo "Erreur : image d'origine introuvable : $ORIG" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Trois logos sans source officielle atteignable, découpés dans l'image d'origine.
convert "$ORIG" -crop 240x198+229+103 +repage "$TMP/vmware.png"
convert "$ORIG" -crop 256x198+592+100 +repage "$TMP/hyperv.png"
convert "$ORIG" -crop 345x172+48+305  +repage "$TMP/xen.png"

# Trois logos officiels. XCP-ng n'existe qu'en 180x30 : agrandi au filtre Lanczos.
convert "$SRC/xcp-ng.png" -filter Lanczos -resize 400% "$TMP/xcpng.png"
cp "$SRC/kvm.png"     "$TMP/kvm.png"
cp "$SRC/proxmox.png" "$TMP/proxmox.png"

# Cadrage commun : rogner le blanc, puis centrer dans une cellule identique.
for f in vmware hyperv xen xcpng kvm proxmox; do
  convert "$TMP/$f.png" -fuzz 8% -trim +repage \
    -background white -alpha remove -alpha off \
    -resize 300x140 -gravity center -extent 320x160 "$TMP/cell-$f.png"
done

# Titre en gras comme sur l'image d'origine. La police est choisie parmi celles
# réellement installées : `convert` ne signale pas une police absente, il retombe
# silencieusement sur la fonte par défaut et le gras disparaît sans erreur.
# La liste est capturée une fois plutôt que retraversée par un `| grep -q` :
# sous `set -o pipefail`, `grep -q` sort dès la première correspondance, `convert`
# reçoit un SIGPIPE, et le pipeline rend 141 — donc la police trouvée est déclarée
# absente. Même piège que le `| tee` de link-check.yml (#533).
FONT_LIST="$(convert -list font 2>/dev/null || true)"
TITLE_FONT=""
for f in DejaVu-Sans-Bold Liberation-Sans-Bold Helvetica-Bold; do
  case $FONT_LIST in *"Font: $f"$'\n'*) TITLE_FONT="$f"; break;; esac
done
if [ -z "$TITLE_FONT" ]; then
  echo "NOTE: aucune police grasse connue, titre en graisse normale." >&2
  convert -size 1024x107 xc:white -gravity center -pointsize 52 -fill '#555555' \
    -annotate +0+0 "Hyperviseurs de type 1" "$TMP/titre.png"
else
  convert -size 1024x107 xc:white -gravity center -font "$TITLE_FONT" \
    -pointsize 52 -fill '#555555' \
    -annotate +0+0 "Hyperviseurs de type 1" "$TMP/titre.png"
fi

montage "$TMP/cell-vmware.png" "$TMP/cell-hyperv.png" "$TMP/cell-xen.png" \
        "$TMP/cell-xcpng.png"  "$TMP/cell-kvm.png"    "$TMP/cell-proxmox.png" \
  -tile 3x2 -geometry +5+5 -background white "$TMP/corps.png"

convert "$TMP/titre.png" "$TMP/corps.png" -append \
  -background white -alpha remove -gravity center -extent 1024x512 -depth 8 "$OUT"

echo "OK: $OUT ($(identify -format '%wx%h' "$OUT"))"
