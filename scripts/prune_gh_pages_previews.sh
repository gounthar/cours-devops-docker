#!/usr/bin/env bash
#
# Supprime de `gh-pages` les aperçus des branches qui n'existent plus. Voir
# l'issue #542, et l'incident du 2026-09-10 : le site avait atteint 10,86 Go et
# 49 531 fichiers, dont 1,4 % seulement appartenaient à `main`, et la
# publication Pages a fini par échouer. Le job `deploy` publie dans
# `gh-pages/<branche>/` et rien n'a jamais supprimé ce répertoire quand la
# branche disparaissait. Le taux mesuré est d'un orphelin par PR fusionnée,
# environ 155 Mo pièce.
#
# Le script s'exécute DANS une copie de travail de `gh-pages` : il fait les
# `git rm` et le commit, et laisse la poussée à l'appelant.
#
#   ./scripts/prune_gh_pages_previews.sh --dry-run   # n'écrit rien, dit quoi
#   ./scripts/prune_gh_pages_previews.sh             # élague et commite
#
# Essai local sans toucher à la copie de travail du cours :
#
#   PRUNE="$PWD/scripts/prune_gh_pages_previews.sh"
#   git fetch origin gh-pages
#   git worktree add /tmp/ghp gh-pages
#   (cd /tmp/ghp && "$PRUNE" --dry-run)
#   git worktree remove /tmp/ghp

set -euo pipefail

DRY_RUN=0
REMOTE=origin
# `main` est épargnée sans condition, y compris si l'énumération des branches
# la rate : c'est le seul aperçu dont l'URL est citée dans le dépôt
# (README.adoc:3, content/examen-final-detaille.adoc).
ALWAYS_KEEP=(main)

while [ $# -gt 0 ]; do
  case "$1" in
  --dry-run) DRY_RUN=1 ;;
  --remote)
    REMOTE="${2:?--remote demande un nom de dépôt distant}"
    shift
    ;;
  # Le bloc de commentaires de l'en-tête, jusqu'à la première ligne qui n'en
  # est pas une. Une plage codée en dur se décale dès qu'on ajoute un
  # paragraphe et tronque l'aide sans le dire -- c'est arrivé en l'écrivant.
  -h | --help)
    awk 'NR>2 && /^#/ {sub(/^# ?/, ""); print; next} NR>2 {exit}' "$0"
    exit 0
    ;;
  *)
    echo "Erreur : option inconnue « $1 »." >&2
    exit 2
    ;;
  esac
  shift
done

# Garde-fou le plus important du script : `git rm -r` sur une copie de travail
# de `main` supprimerait le cours. La branche courante doit être `gh-pages`.
current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ "$current" != 'gh-pages' ]; then
  echo "Erreur : à lancer dans une copie de travail de gh-pages, pas de « $current »." >&2
  echo "         Voir l'en-tête du script pour la recette git worktree." >&2
  exit 2
fi

# `git ls-remote` plutôt que `git branch -r` : la liste vient du serveur, donc
# elle ne dépend pas d'un `fetch --prune` préalable. Une liste périmée ferait
# supprimer l'aperçu d'une branche vivante, ce qui est la seule façon dont ce
# script peut détruire quelque chose d'utile.
#
# Les étiquettes comptent aussi : `build-workflow.yml` se déclenche sur
# `tags: '*'`, donc une poussée d'étiquette publie `gh-pages/<étiquette>/`.
live_refs="$(git ls-remote --heads --tags --refs "$REMOTE" |
  sed -e 's#^[0-9a-f]*[[:space:]]*refs/\(heads\|tags\)/##' |
  sort -u)" || {
  echo "Erreur : impossible de lire les références de « $REMOTE »." >&2
  echo "         Rien n'a été supprimé : une absence non établie n'est pas une absence." >&2
  exit 1
}

# Deux contrôles sur la liste, parce qu'une liste vide ou tronquée ferait
# passer tous les aperçus pour des orphelins. `ls-remote` sort en 0 et rend
# une page vide dans plus d'un cas de figure (jeton expiré, quota atteint).
if [ -z "$live_refs" ]; then
  echo "Erreur : « $REMOTE » ne rend aucune branche. Rien n'a été supprimé." >&2
  exit 1
fi
if ! grep -qx 'main' <<<"$live_refs"; then
  echo "Erreur : « main » manque à la liste des branches de « $REMOTE »." >&2
  echo "         La liste est donc fausse. Rien n'a été supprimé." >&2
  exit 1
fi

# Un aperçu est un répertoire portant un `index.html`. Ceux qui sont imbriqués
# dans un autre aperçu sont écartés : un `index.html` qui apparaîtrait un jour
# dans `main/<quelque chose>/` serait pris pour l'aperçu d'une branche
# inexistante, et une partie de `main/` partirait avec.
mapfile -t previews < <(git ls-files -- '*/index.html' |
  sed 's#/index\.html$##' | sort)

kept_previews=()
for preview in "${previews[@]:-}"; do
  [ -n "$preview" ] || continue
  nested=0
  for other in "${previews[@]}"; do
    [ "$other" != "$preview" ] || continue
    case "$preview" in "$other"/*)
      nested=1
      break
      ;;
    esac
  done
  [ "$nested" -eq 0 ] && kept_previews+=("$preview")
done

orphans=()
for preview in "${kept_previews[@]:-}"; do
  [ -n "$preview" ] || continue
  keep=0
  for spared in "${ALWAYS_KEEP[@]}"; do
    [ "$preview" != "$spared" ] || {
      keep=1
      break
    }
  done
  [ "$keep" -eq 1 ] && continue
  grep -qxF -- "$preview" <<<"$live_refs" || orphans+=("$preview")
done

echo "Aperçus publiés : ${#kept_previews[@]}"
echo "Orphelins       : ${#orphans[@]}"

if [ "${#orphans[@]}" -eq 0 ]; then
  echo "Rien à élaguer. Aucun commit."
  exit 0
fi

printf '  %s\n' "${orphans[@]}"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Essai à blanc : rien n'a été supprimé."
  exit 0
fi

git rm -r --quiet -- "${orphans[@]}"

# Le corps porte la liste : c'est ce que lira quelqu'un qui cherche pourquoi
# une URL d'aperçu a cessé de répondre.
{
  printf 'chore(gh-pages): élaguer %d aperçu(s) de branche supprimée\n\n' "${#orphans[@]}"
  printf 'Branches disparues de %s, aperçus retirés :\n\n' "$REMOTE"
  printf -- '- %s\n' "${orphans[@]}"
  # shellcheck disable=SC2016  # les apostrophes inverses sont du Markdown, pas une substitution
  printf '\nVoir issue #542. `main` est épargnée sans condition.\n'
} | git commit --quiet --file=-

git --no-pager log --oneline -1
