DIST_DIR ?= $(CURDIR)/dist
REPOSITORY_URL ?= file://$(CURDIR)
export REPOSITORY_URL DIST_DIR

## The build containers write dist/ through a bind mount, so they must run as
## the user invoking make. Left at root, they leave root-owned files that
## `clean` cannot remove from the host, and `make all` dies on its first
## target. Computed here rather than hardcoded in .env: the id is not the
## same on a workstation, in a Codespace or on a CI runner. See issue #514.
CURRENT_UID ?= $(shell id -u):$(shell id -g)
export CURRENT_UID

## Docker Buildkit is enabled for faster build and caching of images
DOCKER_BUILDKIT ?= 1
COMPOSE_DOCKER_CLI_BUILD ?= 1
export DOCKER_BUILDKIT COMPOSE_DOCKER_CLI_BUILD

## Define the reusable shell commands once for all
compose_cmd = docker compose --file=$(CURDIR)/docker-compose.yml $(1)
compose_up = $(call compose_cmd, up --build $(1))
compose_run = $(call compose_cmd, run --user=0 $(1))

all: clean build verify

## La carte 🩻 Anatomie porte une horodate : la diapositive existe pour montrer
## qu'un conteneur rend le resultat DU MOMENT, et elle affichait une date de
## 2023. Elle ne peut donc pas suivre le modele commit/--check de
## check-diagrams -- une horodate n'est pas deterministe, --check echouerait a
## tous les coups et la copie commitee serait perimee des le commit.
##
## Elle est donc regeneree avant chaque construction et ignoree par git, comme
## content/media/qrcode.png l'est deja. Sur l'hote et non dans un conteneur,
## comme check-diagrams : python3 suffit, et le conteneur de construction est
## un conteneur node. check-assets la voit puisqu'il tourne apres la
## construction. Voir issue #548.
ANATOMY_CARD = $(CURDIR)/content/media/anatomie

anatomy:
	@python3 $(CURDIR)/scripts/gen_anatomy_card.py $(ANATOMY_CARD) --steps

## La carte 📛 Nommage listait un conteneur `centos` dans une sortie de
## `docker container ls` enfermee dans un PNG, invisible a tout garde-fou du
## depot -- il a fallu un balayage OCR pour la trouver (#550). Elle est
## desormais du texte, donc `grep` la voit.
##
## Contrairement a check-diagrams, pas de copie commitee ni de `--check` : la
## source de verite est le script, la sortie en est une fonction pure, et une
## copie commitee serait une seconde copie qui ne peut que se perimer. Meme
## traitement que la carte Anatomie ci-dessus, pour une raison differente.
NAMING_CARD = $(CURDIR)/content/media/nommage

naming:
	@python3 $(CURDIR)/scripts/gen_naming_card.py $(NAMING_CARD) --steps

# Generate documents inside a container, all *.adoc in parallel
## mkdir before compose: the daemon creates a missing bind mount source as
## root, which the non-root container then cannot write into.
build: anatomy naming
	@mkdir -p $(DIST_DIR)
	@$(call compose_up,--exit-code-from=build build)

## U+2013/U+2014 look identical to "-" on a slide but break every command.
## Scoped to command lines on purpose: French headings ("Etape 1 - ...")
## use en dashes correctly, and a check that fires on correct writing
## gets ignored, then disabled. See issue #426.
DASH_CMDS = docker|podman|kubectl|apt|apt-get|curl|wget|git|sudo|make|npm|tail|ps|chmod|chown

check-dashes:
	@if grep -rnIP '[\x{2013}\x{2014}]' $(CURDIR)/content/ \
	     | grep -P '[\s:`]($(DASH_CMDS))\b'; then \
	  echo ""; \
	  echo "ERROR: en/em dash (U+2013 / U+2014) used in the command(s) above."; \
	  echo "       Replace it with an ASCII hyphen '-' (see issue #426)."; \
	  exit 1; \
	fi
	@echo "OK: no en/em dash found in commands"

## `opacity=` written inside an image macro is dropped by the converter without
## a word: only a [background-opacity=...] line above the slide title reaches
## the HTML. Two guards, because either alone can be green while wrong.
##   1. no opacity= left in an image macro -- catches the original form coming
##      back, and catches a half-finished conversion, which guard 2 cannot see;
##   2. what the source declares must equal what the HTML carries -- catches a
##      converter or theme upgrade dropping the attribute again.
## Counted per output, since the two decks are built from disjoint file sets.
## See issue #513.
check-opacity:
	@fail=0; checked=0; \
	for deck in index index-examen; do \
	  out=$(DIST_DIR)/$$deck.html; \
	  if [ ! -f "$$out" ]; then \
	    echo "NOTE: $$deck.html not built, opacity count not checked for that deck"; \
	    continue; \
	  fi; \
	  src=$(CURDIR)/content/$$deck.adoc; \
	  files="$$src `sed -n 's|^include::\./\(.*\)\[.*$$|$(CURDIR)/content/\1|p' $$src`"; \
	  want=`cat $$files 2>/dev/null | grep -c '^\[background-opacity='`; \
	  got=`grep -o 'data-background-opacity' $$out | wc -l`; \
	  checked=`expr $$checked + 1`; \
	  if [ "$$want" -ne "$$got" ]; then \
	    echo "ERROR: $$deck.adoc declares $$want slide background opacity attribute(s), $$deck.html carries $$got."; \
	    fail=1; \
	  else \
	    echo "OK: $$deck -> $$want declared, $$want emitted"; \
	  fi; \
	done; \
	if [ "$$checked" -eq 0 ]; then \
	  echo "ERROR: no built deck to check against. Run 'make build' first (see issue #513)."; \
	  exit 1; \
	fi; \
	if grep -rn 'image::.*opacity=' $(CURDIR)/content/ --include=*.adoc; then \
	  echo ""; \
	  echo "ERROR: opacity= inside the image macro(s) above is ignored by the converter."; \
	  echo "       Put a [background-opacity=0.1] line above the slide title instead,"; \
	  echo "       or drop it when the image is meant to stay fully visible (issue #513)."; \
	  fail=1; \
	fi; \
	exit $$fail

## Link checking, in two halves, because the two have different failure modes.
##
##   check-assets  offline, deterministic, part of `verify`: does every local
##                 file the HTML points at actually exist? This is the half
##                 that can gate a pull request, because it cannot fail for a
##                 reason outside the repository.
##   check-links   network, run on demand and weekly in CI: are the external
##                 URLs still alive? Deliberately NOT part of `verify` -- a
##                 gate that depends on somebody else's uptime gets ignored,
##                 then switched off, which is how this repository ended up
##                 with `verify: @echo "Verify disabled"` for two years.
##
## Exclusions and the browser user agent live in lychee.toml, each one with
## the measurement that justifies it. See issue #486.
LYCHEE_IMAGE ?= lycheeverse/lychee:0.24.2

## GITHUB_TOKEN is forwarded only when the caller has set it. lychee sends it
## to api.github.com to lift the 60-requests-per-hour anonymous limit, which a
## developer re-running the check a few times in an hour will hit -- the run
## then reports GitHub URLs as broken when they are not.
##
## The scheduled job deliberately does NOT set it. Twenty-two github.com URLs
## once a week is far inside the anonymous limit, and its token also carries
## `issues: write`; handing that to a tool whose job is to make requests to
## arbitrary third-party hosts buys robustness we do not need.
LYCHEE_TOKEN_ENV = $(if $(GITHUB_TOKEN),--env GITHUB_TOKEN,)

lychee_run = docker run --rm --user $(CURRENT_UID) \
	--volume $(DIST_DIR):/input:ro \
	--volume $(CURDIR)/lychee.toml:/lychee.toml:ro \
	$(LYCHEE_TOKEN_ENV) \
	--workdir /input $(LYCHEE_IMAGE) --config /lychee.toml $(1)

## `link:slides.pdf[]` on the first slide is produced by `make pdf`, a separate
## target that CI runs before `verify`. Absent after a bare `make build`, so
## say it is unchecked rather than reporting a broken link that is not broken.
PDF_EXCLUDE = $(if $(wildcard $(DIST_DIR)/slides.pdf),,--exclude 'slides\.pdf$$')

## REPOSITORY_URL defaults to file://$(CURDIR) so the local preview can link
## back to the working copy. lychee then resolves those anchors as missing
## files. That is build configuration showing through, not a broken link: CI
## sets REPOSITORY_URL to the repository https URL, and --offline skips it
## there, while check-links covers it for real.
##
## The value is baked into the HTML at build time, so this exclusion is only
## correct when REPOSITORY_URL holds the same value it held during `make
## build`. CI gets that for free -- build and verify share one job. Locally,
## overriding it for the check alone un-hides the anchors the previous build
## wrote, and the run fails loudly rather than quietly passing.
REPO_EXCLUDE = $(if $(filter file://%,$(REPOSITORY_URL)),--exclude '^$(REPOSITORY_URL)',)

## Les diagrammes qui montrent un Dockerfile sont *derives* du Dockerfile, pas
## dessines a cote. Un PNG exporte d'un PowerPoint ne peut pas suivre : celui du
## defi JRE montrait encore alpine:3.18 et un `RUN apk update` supprime depuis,
## alors que dependabot avait monte l'etiquette du Dockerfile onze fois. Voir
## issues #527 et #537.
##
## `diagrams` regenere, `check-diagrams` echoue si le SVG commite ne correspond
## plus a son Dockerfile. Le second est dans `verify` : il est hors ligne et
## deterministe, donc il peut bloquer une PR sans dependre de personne.
## La diapositive d'origine est une apparition progressive en quatre temps
## (quatre `[%auto-animate]`) : le code seul, puis une pastille de plus a
## chaque etape. `--steps` produit <base>-1.svg .. <base>-N.svg. La geometrie
## ne depend que du code, donc les quatre partagent les memes positions et
## reveal.js peut les interpoler.
DIAGRAM_CARDS = content/media/dockerfile-defi.svg:content/code-samples/images/defi/Dockerfile

diagrams:
	@for pair in $(DIAGRAM_CARDS); do \
	  svg=$${pair%%:*}; src=$${pair#*:}; \
	  python3 $(CURDIR)/scripts/gen_dockerfile_card.py "$(CURDIR)/$$src" "$(CURDIR)/$$svg" --steps || exit 1; \
	done

check-diagrams:
	@for pair in $(DIAGRAM_CARDS); do \
	  svg=$${pair%%:*}; src=$${pair#*:}; \
	  python3 $(CURDIR)/scripts/gen_dockerfile_card.py "$(CURDIR)/$$src" "$(CURDIR)/$$svg" --steps --check || exit 1; \
	done

## L'elagage de gh-pages supprime des fichiers sur une branche publiee, sans
## personne pour regarder, une fois par semaine. Ses deux defauts connus ont ete
## trouves en revue APRES la fusion, et les deux supprimaient l'apercu d'une
## branche VIVANTE : un prefixe de branche qui bascule (`feature` morte puis
## `feature/docs` vivante) et une etiquette nommee `main` qui satisfaisait le
## garde-fou a la place de la branche. Les douze cas sont hors ligne et
## deterministes -- git et bash, rien du reseau -- donc ils ont leur place ici
## au meme titre que check-diagrams. Voir issue #542 et la revue de la PR #551.
check-prune:
	@bash $(CURDIR)/scripts/test_prune_gh_pages_previews.sh --quiet

check-assets:
	@test -d $(DIST_DIR) || { \
	  echo "ERROR: $(DIST_DIR) does not exist. Run 'make build' first (see issue #486)."; \
	  exit 1; \
	}
	@decks=""; \
	for deck in index index-examen; do \
	  if [ -f $(DIST_DIR)/$$deck.html ]; then \
	    decks="$$decks $$deck.html"; \
	  else \
	    echo "NOTE: $$deck.html not built, its links are not checked"; \
	  fi; \
	done; \
	if [ -z "$$decks" ]; then \
	  echo "ERROR: no built deck in $(DIST_DIR). Run 'make build' first (see issue #486)."; \
	  exit 1; \
	fi; \
	test -f $(DIST_DIR)/slides.pdf || \
	  echo "NOTE: dist/slides.pdf absent, its link is not checked (run 'make pdf')"; \
	$(call lychee_run,--offline $(PDF_EXCLUDE) $(REPO_EXCLUDE) $$decks) || { \
	  echo ""; \
	  echo "ERROR: the built HTML points at local file(s) that do not exist."; \
	  echo "       Add the missing file, or drop the reference (see issue #486)."; \
	  exit 1; \
	}
	@echo "OK: every local file referenced by the built HTML exists"

## Not in `verify` on purpose -- see the comment above check-assets.
##
## The image is pulled quietly first, on its own line. Left to `docker run`,
## fifteen lines of layer-pull progress land on stderr, and the scheduled job
## copies the whole stream into the issue body, burying the findings under
## checksum noise. A pull failure still surfaces: `docker run` fails next.
check-links:
	@docker pull --quiet $(LYCHEE_IMAGE) >/dev/null 2>&1 || true
	@decks=""; \
	for deck in index index-examen examen-final-detaille; do \
	  if [ -f $(DIST_DIR)/$$deck.html ]; then \
	    decks="$$decks $$deck.html"; \
	  else \
	    echo "NOTE: $$deck.html not built, its links are not checked"; \
	  fi; \
	done; \
	if [ -z "$$decks" ]; then \
	  echo "ERROR: no built deck in $(DIST_DIR). Run 'make build' first (see issue #486)."; \
	  exit 1; \
	fi; \
	$(call lychee_run,--exclude '^file://' $(LYCHEE_EXTRA) $$decks)

## Validation HTML (W3C), deliberately outside `verify` -- see issue #530.
##
## Measured 2026-09-20 with vnu 26.9.16, on the published pages: 24 errors and
## 37 warnings on index.html, 0 and 5 on index-examen.html. Not the hundreds
## the ticket feared, which is why the check is worth having at all.
##
## `--errors-only`: 33 of the 37 warnings are "Section lacks heading", which is
## inherent to Reveal.js -- every slide is a `<section>`, and a full-bleed image
## slide has no heading by design. A check that prints 33 lines nobody can act
## on gets ignored, then switched off. That is how this repository ended up with
## `verify: @echo "Verify disabled"` for two years.
##
## NOT in `verify`. Four errors are left, and they are now all of one kind:
##
##   4  `width="100%"` / `height="100%"` emitted on `<video>`. Not fixable in
##      content: the converter substitutes the literal string for whichever
##      dimension the source leaves unset. Read in
##      node_modules/@asciidoctor/reveal.js/dist/main.js, convert_video:
##        width  = attr?("width")  ? attr("width")  : "100%"
##        height = attr?("height") ? attr("height") : "100%"
##      Setting both on every video would silence it, at the cost of pinning an
##      aspect ratio by hand on each one. Not done, deliberately.
##
## The six errors that issue #532 accounted for are gone. They came from the
## `http://...` autolink at compose.adoc:730 and :734: two anchors, each worth
## one bad `href` plus two unterminated character references. Both cells are
## literal monospace now, `+...+`, so no substitution runs inside them.
##
## So this check is offline and deterministic -- it meets the criterion written
## above check-assets -- but it cannot reach zero while the converter behaves
## this way, and a gate that is red by design is a gate nobody reads. Moving it
## into `verify` now needs only a decision on those four videos.
##
## Pinned by digest, not by tag: the validator project tags releases
## irregularly. Its newest version tag is 24.10.17 (October 2024) while `latest`
## carries vnu 26.9.16, and the 24.10.17 image does not even keep the jar at the
## same path -- `java -jar /vnu.jar` fails there with "Unable to access
## jarfile". A digest is the only form that is both reproducible and current.
## Bump it by hand, as LYCHEE_IMAGE is bumped.
VNU_IMAGE ?= ghcr.io/validator/validator@sha256:6c9c0782c07357df8fa83f90acbe2b2a09bf51293e8e228bf0fdab81d723d5ff

vnu_run = docker run --rm --user $(CURRENT_UID) \
	--volume $(DIST_DIR):/input:ro \
	--workdir /input $(VNU_IMAGE) \
	java -jar /vnu.jar --errors-only --format gnu $(1)

## The image sets JAVA_TOOL_OPTIONS, so the JVM announces "Picked up
## JAVA_TOOL_OPTIONS:" on every launch -- on stderr, which is also where vnu
## writes its findings, so the line lands in the middle of them. It is filtered
## out below.
##
## The filtering is done on a captured string rather than through a pipe on
## purpose. A pipe would hand back grep's exit code instead of the validator's,
## and the check would pass while reporting errors. That is exactly the
## regression of issue #533, and it comes back through this door if forgotten.
check-html:
	@docker pull --quiet $(VNU_IMAGE) >/dev/null 2>&1 || true
	@decks=""; \
	for deck in index index-examen; do \
	  if [ -f $(DIST_DIR)/$$deck.html ]; then \
	    decks="$$decks $$deck.html"; \
	  else \
	    echo "NOTE: $$deck.html not built, its markup is not checked"; \
	  fi; \
	done; \
	if [ -z "$$decks" ]; then \
	  echo "ERROR: no built deck in $(DIST_DIR). Run 'make build' first (see issue #530)."; \
	  exit 1; \
	fi; \
	out=$$($(call vnu_run,$$decks) 2>&1); status=$$?; \
	printf '%s\n' "$$out" | grep -v '^Picked up JAVA_TOOL_OPTIONS:' | grep -v '^$$' || true; \
	if [ $$status -ne 0 ]; then \
	  echo ""; \
	  echo "ERROR: the built HTML does not validate (see issue #530)."; \
	  echo "       Four errors are expected today: the 100% dimensions that the"; \
	  echo "       converter writes on <video> (see the comment above)."; \
	  exit 1; \
	fi; \
	echo "OK: the built HTML validates (errors only, warnings not reported -- see issue #530)"

## L'inverse de check-assets : check-assets verifie que tout fichier reference
## existe, check-orphans liste les fichiers de content/media que rien ne
## reference. Hors de `verify` et toujours vert : le depot porte une centaine
## d'orphelins, un garde-fou rouge des le premier jour finirait ignore. Il ne
## supprime rien, ce tri se fait a la main. Pas besoin de `make build` : il lit
## les sources suivies par git, ce qui voit aussi le deck d'examen sans le
## construire. Voir issue #573 et l'en-tete du script pour les deux pieges de
## mesure qu'il evite.
check-orphans:
	@python3 $(CURDIR)/scripts/check_orphans.py

verify: check-dashes check-diagrams check-prune check-opacity check-assets
	@echo "NOTE: external links are checked by 'make check-links', not here (see issue #486)"

serve: anatomy naming
	@$(call compose_up, --force-recreate serve qrcode)

shell:
	@$(call compose_run,--entrypoint=sh --rm serve)

dependencies-lock-update:
	@$(call compose_run,--entrypoint=npm --rm serve install --package-lock)

dependencies-update:
	@$(call compose_run,--entrypoint=ncu --workdir=/app/npm-packages --rm serve -u)
	@make -C $(CURDIR) dependencies-lock-update

pdf: anatomy naming
	@mkdir -p $(DIST_DIR)
	@$(call compose_up, --exit-code-from=pdf pdf)

# Asciidoctor Docker image version - kept updated via updatecli
ASCIIDOCTOR_IMAGE ?= asciidoctor/docker-asciidoctor:1.108.0

exam-pdf:
	@echo "Generating detailed exam PDF with LaTeX-style formatting..."
	@mkdir -p $(DIST_DIR)
	@docker run --rm \
		--user $(CURRENT_UID) \
		-v $(CURDIR)/content:/documents:ro \
		-v $(CURDIR)/resources:/resources:ro \
		-v $(DIST_DIR):/output \
		$(ASCIIDOCTOR_IMAGE) \
		asciidoctor-pdf \
		-a pdf-theme=/resources/themes/latex-theme.yml \
		-a imagesdir=/documents/media \
		-a source-highlighter=rouge \
		-a icons=font \
		/documents/examen-final-detaille.adoc \
		-o /output/examen-final-detaille.pdf \
		|| { echo "ERROR: PDF generation failed"; exit 1; }
	@test -f $(DIST_DIR)/examen-final-detaille.pdf || { echo "ERROR: PDF was not generated"; exit 1; }
	@echo "PDF generated: $(DIST_DIR)/examen-final-detaille.pdf"

## The exam document is standalone: neither deck includes it, so check-links
## never saw its URLs, and a link that had never worked sat in its Resources
## section while every gate stayed green. The PDF is what students get, but
## lychee cannot read a PDF, so render the same source to HTML with the same
## attributes and hand that to check-links. Not published, not in `verify`:
## it exists only to be checked. See issue #554.
exam-html:
	@mkdir -p $(DIST_DIR)
	@docker run --rm \
		--user $(CURRENT_UID) \
		-v $(CURDIR)/content:/documents:ro \
		-v $(DIST_DIR):/output \
		$(ASCIIDOCTOR_IMAGE) \
		asciidoctor \
		-a imagesdir=/documents/media \
		-a source-highlighter=rouge \
		-a icons=font \
		/documents/examen-final-detaille.adoc \
		-o /output/examen-final-detaille.html \
		|| { echo "ERROR: exam HTML generation failed"; exit 1; }
	@test -f $(DIST_DIR)/examen-final-detaille.html || { echo "ERROR: exam HTML was not generated"; exit 1; }
	@echo "HTML generated: $(DIST_DIR)/examen-final-detaille.html"

## The fallback recovers a dist/ left root-owned by an older build, or by a
## `docker compose up` run outside make with CURRENT_UID unset. Deleting the
## content from a root container is the only way to do it without sudo.
clean:
	@$(call compose_cmd, down -v --remove-orphans)
	@rm -rf $(DIST_DIR) 2>/dev/null || { \
	  echo "NOTE: dist/ holds root-owned files (see issue #514), removing them from a container"; \
	  docker run --rm --volume $(DIST_DIR):/dist alpine:3 \
	    sh -c 'rm -rf /dist/* /dist/.[!.]*' >/dev/null 2>&1; \
	  rm -rf $(DIST_DIR); \
	}

qrcode:
	@$(call compose_up, qrcode)

.PHONY: all build anatomy naming clean verify check-dashes check-diagrams check-opacity check-prune check-assets check-links check-html check-orphans diagrams serve qrcode pdf exam-pdf exam-html dependencies-update dependencies-lock-update
