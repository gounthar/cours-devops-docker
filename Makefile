DIST_DIR ?= $(CURDIR)/dist
REPOSITORY_URL ?= file://$(CURDIR)
export REPOSITORY_URL DIST_DIR

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
build:
	@$(call compose_up,--exit-code-from=build build)

verify:
	@echo "Verify disabled"

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
	@$(call compose_up, --exit-code-from=pdf pdf)

exam-pdf:
	@echo "Generating detailed exam PDF with LaTeX-style formatting..."
	@mkdir -p $(DIST_DIR)
	@docker run --rm \
		-v $(CURDIR)/content:/documents \
		-v $(CURDIR)/resources:/resources:ro \
		asciidoctor/docker-asciidoctor:latest \
		asciidoctor-pdf \
		-a pdf-theme=/resources/themes/latex-theme.yml \
		-a pdf-fontsdir=/resources/fonts \
		-a imagesdir=/documents/media \
		-a source-highlighter=rouge \
		-a icons=font \
		/documents/examen-final-detaille.adoc \
		-o /documents/examen-final-detaille.pdf
	@mv $(CURDIR)/content/examen-final-detaille.pdf $(DIST_DIR)/
	@echo "PDF generated: $(DIST_DIR)/examen-final-detaille.pdf"

clean:
	@$(call compose_cmd, down -v --remove-orphans)
	@rm -rf $(DIST_DIR)

qrcode:
	@$(call compose_up, qrcode)

.PHONY: all build verify serve qrcode pdf exam-pdf dependencies-update dependencies-lock-update
