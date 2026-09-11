#!/usr/bin/env bash
#
# Tests de scripts/prune_gh_pages_previews.sh.
#
# Hors ligne et déterministe -- git et bash suffisent, rien n'est tiré du réseau
# -- donc il a sa place dans `make verify` au même titre que `check-diagrams` :
# il peut bloquer une PR sans dépendre de la disponibilité de personne.
#
# Deux des cas sont des régressions, trouvées par la revue de la PR #551 APRÈS
# la fusion, et reproduites avant d'être corrigées. Les deux auraient supprimé
# l'aperçu d'une branche vivante, seule façon dont l'élagage peut détruire
# quelque chose d'utile :
#
#   - « enfant vivant sous parent mort » : une branche `feature` supprimée puis
#     une branche `feature/docs` créée laissent les deux aperçus publiés, et un
#     `git rm -r feature` emporte le second ;
#   - « étiquette nommée main » : le garde-fou cherchait « main » dans les
#     branches ET les étiquettes aplaties ensemble, donc une étiquette suffisait
#     à le faire passer sur un distant sans aucune branche.
#
#   ./scripts/test_prune_gh_pages_previews.sh            # détail cas par cas
#   ./scripts/test_prune_gh_pages_previews.sh --quiet     # une ligne si tout va
#
# Sortie 0 si tout passe, 1 sinon. `--quiet` est la forme utilisée par
# `make verify` : soixante lignes de « ok » noieraient les quatre autres
# contrôles, et c'est précisément le défaut que le commentaire de `check-links`
# décrit dans le Makefile. Un échec parle dans les deux formes.

set -euo pipefail

# shellcheck disable=SC1007  # `CDPATH=` vide la variable pour cette commande
SCRIPT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)/prune_gh_pages_previews.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "Erreur : $SCRIPT est introuvable ou non exécutable." >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

VERBOSE=1
[ "${1:-}" != '--quiet' ] || VERBOSE=0

cases=0
failures=0

# Identité posée par `-c` et non par `git config` : une copie de travail
# secondaire n'a pas de configuration propre, donc un `git config` y écrirait
# dans le dépôt principal. Et `format.signOff`, la signature et les crochets
# sont neutralisés pour que les cas ne dépendent pas des réglages de la machine
# -- sans `core.hooksPath`, un crochet global git-lfs écrit une dizaine de
# lignes d'avertissement au milieu de la sortie de `make verify`.
git_q() {
  git -c user.name=test -c user.email=test@example.invalid \
    -c commit.gpgsign=false -c format.signOff=false \
    -c init.defaultBranch=main -c advice.detachedHead=false \
    -c core.hooksPath=/dev/null -c lfs.locksverify=false "$@"
}

# fixture <nom> <branches> <étiquettes> <aperçus>
# Les trois listes sont séparées par des espaces. Un distant nu porte les
# branches et les étiquettes demandées ; une copie de travail de `gh-pages`
# porte un aperçu par chemin demandé, chacun avec son `index.html` et un fichier
# témoin qui rend visible toute suppression de trop.
fixture() {
  local name=$1 branches=$2 tags=$3 previews=$4
  local root="$TMP/$name" b t p

  mkdir -p "$root"
  git_q init -q --bare "$root/remote.git"
  git_q init -q "$root/seed"
  (
    cd "$root/seed"
    git_q commit -q --allow-empty -m init
    for b in $branches; do
      git_q push -q "$root/remote.git" "HEAD:refs/heads/$b"
    done
    for t in $tags; do
      git_q push -q "$root/remote.git" "HEAD:refs/tags/$t"
    done
  )

  git_q init -q "$root/ghp"
  # Ici l'identité est ÉCRITE dans la configuration du dépôt, et pas passée par
  # `-c` comme ailleurs : le script testé lance un `git commit` ordinaire, qui
  # doit donc trouver une identité dans l'environnement. Un poste de travail en
  # a une dans sa configuration globale, un runner GitHub n'en a pas -- les deux
  # cas qui commitent échouaient en 128 sur `empty ident name` alors qu'ils
  # passaient en local. C'est le workflow qui la fournit en production, juste
  # avant d'appeler le script. Écrire ici est sans risque : `ghp` est un dépôt
  # autonome et jetable, pas une copie de travail secondaire partageant le
  # `.git/config` d'un autre.
  git -C "$root/ghp" config user.name test
  git -C "$root/ghp" config user.email test@example.invalid
  git -C "$root/ghp" config commit.gpgsign false
  git -C "$root/ghp" config format.signOff false
  git -C "$root/ghp" config core.hooksPath /dev/null
  (
    cd "$root/ghp"
    git_q checkout -q -b gh-pages
    : >.nojekyll
    for p in $previews; do
      mkdir -p "$p"
      echo 'aperçu' >"$p/index.html"
      echo "$p" >"$p/TEMOIN"
    done
    git_q add -A
    git_q commit -q -m 'état publié'
  )
}

# run <nom> [options du script...] -> sortie dans $out, code dans $rc
run() {
  local name=$1
  shift
  set +e
  out="$(cd "$TMP/$name" && cd ghp && "$SCRIPT" --remote "../remote.git" "$@" 2>&1)"
  rc=$?
  set -e
}

ok() { [ "$VERBOSE" -eq 0 ] || printf '  ok   %s\n' "$1"; }
titre() { [ "$VERBOSE" -eq 0 ] || printf '%s\n' "$1"; }
ko() {
  printf '  ÉCHEC %s\n' "$1" >&2
  printf '        %s\n' "$2" >&2
  failures=$((failures + 1))
}

check_rc() {
  local label=$1 want=$2
  if [ "$rc" -eq "$want" ]; then ok "$label"; else
    ko "$label" "code attendu $want, obtenu $rc ; sortie : $out"
  fi
}

check_out() {
  local label=$1 pattern=$2
  if grep -qF -- "$pattern" <<<"$out"; then ok "$label"; else
    ko "$label" "« $pattern » absent de la sortie : $out"
  fi
}

check_present() {
  local label=$1 name=$2 path=$3
  if git -C "$TMP/$name/ghp" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    ok "$label"
  else
    ko "$label" "$path a disparu alors qu'il devait rester"
  fi
}

check_gone() {
  local label=$1 name=$2 path=$3
  if git -C "$TMP/$name/ghp" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    ko "$label" "$path est toujours suivi alors qu'il devait partir"
  else ok "$label"; fi
}

head_of() { git -C "$TMP/$1/ghp" rev-parse HEAD; }

titre '1. orphelin simple : la branche morte part, les autres restent'
cases=$((cases + 1))
fixture simple 'main vivante' '' 'main vivante morte'
run simple
check_rc 'sortie 0' 0
check_out 'un seul orphelin' 'Orphelins       : 1'
check_out "c'est bien « morte »" '  morte'
check_gone 'morte/TEMOIN retiré' simple morte/TEMOIN
check_present 'main/TEMOIN intact' simple main/TEMOIN
check_present 'vivante/TEMOIN intact' simple vivante/TEMOIN
check_present '.nojekyll intact' simple .nojekyll

titre '2. rejouer ne fait rien (idempotence)'
cases=$((cases + 1))
before="$(head_of simple)"
run simple
check_rc 'sortie 0' 0
check_out 'aucun orphelin' 'Orphelins       : 0'
check_out 'aucun commit annoncé' 'Rien à élaguer'
if [ "$(head_of simple)" = "$before" ]; then
  ok 'HEAD inchangé'
else
  ko 'HEAD inchangé' 'un second passage a commité'
fi

titre '3. RÉGRESSION : enfant vivant sous parent mort'
cases=$((cases + 1))
fixture transition 'main feature/docs' '' 'main feature feature/docs'
run transition
check_rc 'sortie 0' 0
check_out 'seul le parent est orphelin' 'Orphelins       : 1'
check_out "c'est bien « feature »" '  feature'
check_gone 'feature/TEMOIN retiré' transition feature/TEMOIN
check_gone 'feature/index.html retiré' transition feature/index.html
check_present "l'aperçu vivant feature/docs/TEMOIN est intact" transition feature/docs/TEMOIN
check_present 'feature/docs/index.html intact' transition feature/docs/index.html

titre '4. enfant mort sous parent vivant : fuite délibérée, jamais de suppression'
cases=$((cases + 1))
fixture sous_vivant 'main feat' '' 'main feat feat/526-morte'
run sous_vivant
check_rc 'sortie 0' 0
check_out 'aucun orphelin' 'Orphelins       : 0'
check_present 'feat/526-morte/TEMOIN conservé' sous_vivant feat/526-morte/TEMOIN

titre '5. index.html imbriqué sous main : du contenu, pas un aperçu'
cases=$((cases + 1))
fixture imbrique 'main' '' 'main main/plugin/x'
run imbrique
check_rc 'sortie 0' 0
check_out 'aucun orphelin' 'Orphelins       : 0'
check_present 'main/plugin/x/TEMOIN conservé' imbrique main/plugin/x/TEMOIN

titre "6. RÉGRESSION : une étiquette nommée main ne satisfait pas le garde-fou"
cases=$((cases + 1))
fixture etiquette_main 'autre' 'main' 'main autre morte'
run etiquette_main
check_rc 'refus, sortie 1' 1
check_out 'le motif est nommé' 'une étiquette ne compte pas'
check_present 'morte/TEMOIN intact' etiquette_main morte/TEMOIN
check_present 'main/TEMOIN intact' etiquette_main main/TEMOIN

titre "7. une étiquette vivante épargne son aperçu"
cases=$((cases + 1))
fixture etiquette 'main' 'v1.0' 'main v1.0'
run etiquette
check_rc 'sortie 0' 0
check_out 'aucun orphelin' 'Orphelins       : 0'
check_present 'v1.0/TEMOIN conservé' etiquette v1.0/TEMOIN

titre '8. distant injoignable : refus, rien supprimé'
cases=$((cases + 1))
fixture injoignable 'main' '' 'main morte'
set +e
out="$(cd "$TMP/injoignable/ghp" && "$SCRIPT" --remote "$TMP/injoignable/pas-un-depot" 2>&1)"
rc=$?
set -e
check_rc 'refus, sortie 1' 1
check_out "l'absence non établie est nommée" "n'est pas une absence"
check_present 'morte/TEMOIN intact' injoignable morte/TEMOIN

titre '9. distant sans aucune branche : refus, rien supprimé'
cases=$((cases + 1))
fixture vide '' '' 'main morte'
run vide
check_rc 'refus, sortie 1' 1
check_out 'le motif est nommé' 'ne rend aucune branche'
check_present 'morte/TEMOIN intact' vide morte/TEMOIN

titre '10. lancé ailleurs que sur gh-pages : refus'
cases=$((cases + 1))
fixture ailleurs 'main' '' 'main morte'
git -C "$TMP/ailleurs/ghp" checkout -q -b pas-gh-pages
set +e
out="$(cd "$TMP/ailleurs/ghp" && "$SCRIPT" --remote "../remote.git" 2>&1)"
rc=$?
set -e
check_rc 'refus, sortie 2' 2
check_out 'la branche attendue est nommée' 'copie de travail de gh-pages'
check_present 'morte/TEMOIN intact' ailleurs morte/TEMOIN

titre "11. --dry-run ne supprime rien et ne commite pas"
cases=$((cases + 1))
fixture blanc 'main' '' 'main morte'
before="$(head_of blanc)"
run blanc --dry-run
check_rc 'sortie 0' 0
check_out 'un orphelin listé' 'Orphelins       : 1'
check_out "l'essai à blanc est annoncé" 'Essai à blanc'
check_present 'morte/TEMOIN intact' blanc morte/TEMOIN
if [ "$(head_of blanc)" = "$before" ]; then
  ok 'HEAD inchangé'
else
  ko 'HEAD inchangé' "l'essai à blanc a commité"
fi

titre '12. une option inconnue est refusée'
cases=$((cases + 1))
fixture option 'main' '' 'main'
run option --pas-une-option
check_rc 'refus, sortie 2' 2
check_out "l'option fautive est citée" '--pas-une-option'

[ "$VERBOSE" -eq 0 ] || echo
if [ "$failures" -eq 0 ]; then
  echo "OK: $cases cas, tous passent (prune_gh_pages_previews.sh)"
  exit 0
fi
echo "ERROR: $failures contrôle(s) en échec sur $cases cas (voir ci-dessus)" >&2
exit 1
