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

# Generate documents inside a container, all *.adoc in parallel
## mkdir before compose: the daemon creates a missing bind mount source as
## root, which the non-root container then cannot write into.
build:
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

lychee_run = docker run --rm --user $(CURRENT_UID) \
	--volume $(DIST_DIR):/input:ro \
	--volume $(CURDIR)/lychee.toml:/lychee.toml:ro \
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

check-assets:
	@test -d $(DIST_DIR) || { \
	  echo "ERROR: $(DIST_DIR) does not exist. Run 'make build' first (see issue #486)."; \
	  exit 1; \
	}
	@decks=""; \
	for deck in index index-examen; do \
	  test -f $(DIST_DIR)/$$deck.html && decks="$$decks $$deck.html"; \
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
check-links:
	@test -f $(DIST_DIR)/index.html || { \
	  echo "ERROR: no built deck in $(DIST_DIR). Run 'make build' first (see issue #486)."; \
	  exit 1; \
	}
	@decks=""; \
	for deck in index index-examen; do \
	  test -f $(DIST_DIR)/$$deck.html && decks="$$decks $$deck.html"; \
	done; \
	$(call lychee_run,--exclude '^file://' $$decks)

verify: check-dashes check-opacity check-assets
	@echo "NOTE: external links are checked by 'make check-links', not here (see issue #486)"

serve:
	@$(call compose_up, --force-recreate serve qrcode)

shell:
	@$(call compose_run,--entrypoint=sh --rm serve)

dependencies-lock-update:
	@$(call compose_run,--entrypoint=npm --rm serve install --package-lock)

dependencies-update:
	@$(call compose_run,--entrypoint=ncu --workdir=/app/npm-packages --rm serve -u)
	@make -C $(CURDIR) dependencies-lock-update

pdf:
	@mkdir -p $(DIST_DIR)
	@$(call compose_up, --exit-code-from=pdf pdf)

# Asciidoctor Docker image version - kept updated via updatecli
ASCIIDOCTOR_IMAGE ?= asciidoctor/docker-asciidoctor:1.107.0

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

.PHONY: all build clean verify check-dashes check-opacity check-assets check-links serve qrcode pdf exam-pdf dependencies-update dependencies-lock-update
