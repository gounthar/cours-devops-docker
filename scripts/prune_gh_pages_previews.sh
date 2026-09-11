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
remote_refs="$(git ls-remote --heads --tags --refs "$REMOTE")" || {
  echo "Erreur : impossible de lire les références de « $REMOTE »." >&2
  echo "         Rien n'a été supprimé : une absence non établie n'est pas une absence." >&2
  exit 1
}

# Les deux espaces de noms sont gardés SÉPARÉS, et pas aplatis ensemble. Le
# garde-fou ci-dessous doit vérifier que `refs/heads/main` existe : sur un
# distant portant une étiquette nommée `main` mais plus aucune branche, une
# liste aplatie contient « main » et le garde-fou passe alors que la liste des
# branches est vide -- donc tous les aperçus de branches deviennent orphelins.
# Reproduit avant d'être corrigé.
live_heads="$(awk '{print $2}' <<<"$remote_refs" | sed -n 's#^refs/heads/##p' | sort -u)"

# Les étiquettes comptent pour épargner un aperçu : `build-workflow.yml` se
# déclenche sur `tags: '*'`, donc une poussée d'étiquette publie
# `gh-pages/<étiquette>/`. Elles ne comptent pas pour le garde-fou.
live_tags="$(awk '{print $2}' <<<"$remote_refs" | sed -n 's#^refs/tags/##p' | sort -u)"
live_refs="$(printf '%s\n%s\n' "$live_heads" "$live_tags" | sed '/^$/d' | sort -u)"

# Deux contrôles sur la liste des BRANCHES, parce qu'une liste vide ou tronquée
# ferait passer tous les aperçus pour des orphelins. `ls-remote` sort en 0 et
# rend une page vide dans plus d'un cas de figure (jeton expiré, quota atteint).
if [ -z "$live_heads" ]; then
  echo "Erreur : « $REMOTE » ne rend aucune branche. Rien n'a été supprimé." >&2
  exit 1
fi
if ! grep -qx 'main' <<<"$live_heads"; then
  echo "Erreur : « main » manque aux BRANCHES de « $REMOTE » (une étiquette ne compte pas)." >&2
  echo "         La liste est donc fausse. Rien n'a été supprimé." >&2
  exit 1
fi

# Un aperçu est un répertoire portant un `index.html`. Les chemins complets
# sont comparés aux noms de références, jamais les répertoires de tête : `feat/`
# et `fix/` sont des préfixes, et comparer les têtes ferait passer `fix` pour un
# orphelin, emportant les aperçus de toutes les branches `fix/*` vivantes.
#
# Le tri lexicographique suffit à faire passer un ancêtre avant ses descendants,
# puisqu'un ancêtre est un préfixe strict du descendant.
mapfile -t previews < <(git ls-files -- '*/index.html' |
  sed 's#/index\.html$##' | sort)

# Classement en deux tas, ancêtres d'abord. Un aperçu situé SOUS un aperçu
# conservé est du contenu de ce dernier, pas l'aperçu d'une branche : c'est le
# cas d'un `index.html` qui apparaîtrait un jour dans `main/<quelque chose>/`.
#
# Les deux tas doivent être calculés avant toute suppression, parce que les
# préfixes de branches basculent dans les deux sens au fil du temps. Git
# interdit `refs/heads/feature` et `refs/heads/feature/docs` EN MÊME TEMPS, mais
# pas l'une après l'autre : une branche `feature` supprimée puis une branche
# `feature/docs` créée laissent `feature/index.html` ET
# `feature/docs/index.html` publiés, dont un seul est mort. Un `git rm -r
# feature` emporterait alors l'aperçu d'une branche VIVANTE. Reproduit avant
# d'être corrigé.
kept_previews=()
orphans=()
for preview in "${previews[@]:-}"; do
  [ -n "$preview" ] || continue

  under_kept=0
  for kept in "${kept_previews[@]:-}"; do
    [ -n "$kept" ] || continue
    case "$preview" in "$kept"/*)
      under_kept=1
      break
      ;;
    esac
  done
  if [ "$under_kept" -eq 1 ]; then
    kept_previews+=("$preview")
    continue
  fi

  spared_here=0
  for spared in "${ALWAYS_KEEP[@]}"; do
    [ "$preview" != "$spared" ] || {
      spared_here=1
      break
    }
  done
  if [ "$spared_here" -eq 1 ] || grep -qxF -- "$preview" <<<"$live_refs"; then
    kept_previews+=("$preview")
  else
    orphans+=("$preview")
  fi
done

echo "Aperçus publiés : ${#previews[@]}"
echo "Orphelins       : ${#orphans[@]}"

if [ "${#orphans[@]}" -eq 0 ]; then
  echo "Rien à élaguer. Aucun commit."
  exit 0
fi

printf '  %s\n' "${orphans[@]}"

# Les fichiers d'un orphelin, moins ceux qui appartiennent à un aperçu conservé
# situé dessous. D'où une suppression fichier par fichier et non un `git rm -r`
# sur le répertoire : c'est ce `-r` qui emportait l'aperçu vivant du cas
# ci-dessus. Git supprime les répertoires devenus vides tout seul.
#
# Le cas inverse -- un orphelin sous un aperçu conservé -- n'est pas supprimé,
# et c'est délibéré : rien ne distingue l'aperçu d'une branche morte du contenu
# légitime d'un aperçu vivant. Une fuite se rattrape au prochain déploiement de
# la branche vivante, qui réécrit son répertoire ; une suppression de trop ne se
# rattrape pas.
doomed=()
while IFS= read -r -d '' file; do
  protected=0
  for kept in "${kept_previews[@]:-}"; do
    [ -n "$kept" ] || continue
    case "$file" in "$kept"/*)
      protected=1
      break
      ;;
    esac
  done
  [ "$protected" -eq 0 ] && doomed+=("$file")
done < <(git ls-files -z -- "${orphans[@]}")

echo "Fichiers à retirer : ${#doomed[@]}"

if [ "${#doomed[@]}" -eq 0 ]; then
  echo "Tous les fichiers de ces orphelins appartiennent à un aperçu conservé. Aucun commit."
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Essai à blanc : rien n'a été supprimé."
  exit 0
fi

printf '%s\0' "${doomed[@]}" |
  git rm --quiet --pathspec-from-file=- --pathspec-file-nul

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
