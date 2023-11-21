# Ce Makefile est utilisé pour gérer le projet Docker Compose.

# Définir les valeurs par défaut pour les variables DIST_DIR et REPOSITORY_URL.
DIST_DIR ?= $(CURDIR)/dist
REPOSITORY_URL ?= file://$(CURDIR)
export REPOSITORY_URL DIST_DIR

# Activer Docker BuildKit pour une construction plus rapide et la mise en cache des images.
DOCKER_BUILDKIT ?= 1
COMPOSE_DOCKER_CLI_BUILD ?= 1
export DOCKER_BUILDKIT COMPOSE_DOCKER_CLI_BUILD

# Définition des commandes shell réutilisables pour Docker Compose.

# compose_cmd est une fonction qui exécute la commande 'docker compose' avec le fichier docker-compose.yml du répertoire courant.
# Elle prend un argument $(1) qui représente les options supplémentaires à passer à la commande 'docker compose'.
# $(CURDIR) est une variable d'environnement dans le Makefile qui représente le répertoire courant dans lequel
# le Makefile est exécuté. C'est une fonctionnalité intégrée de GNU Make. Elle est souvent utilisée pour référencer
# des fichiers ou des répertoires relatifs au répertoire courant.
compose_cmd = docker compose --file=$(CURDIR)/docker-compose.yml $(1)

# compose_up est une fonction qui utilise compose_cmd pour exécuter 'docker compose up'.
# Elle prend un argument $(1) qui représente les options supplémentaires à passer à la commande 'docker compose up'.
# L'option '--build' est toujours incluse, ce qui signifie que Docker construira les images avant de démarrer les conteneurs.
compose_up = $(call compose_cmd, up --build $(1))

# compose_run est une fonction qui utilise compose_cmd pour exécuter 'docker compose run'.
# Elle prend un argument $(1) qui représente les options supplémentaires à passer à la commande 'docker compose run'.
# L'option '--user=0' est toujours incluse, ce qui signifie que les commandes seront exécutées en tant que root à l'intérieur du conteneur.
compose_run = $(call compose_cmd, run --user=0 $(1))

# La cible par défaut. Elle nettoie le projet, le construit et le vérifie.
all: clean build verify

# Construire le projet à l'intérieur d'un conteneur Docker.
# Cette règle Makefile utilise la fonction compose_up définie précédemment pour exécuter 'docker compose up' avec l'option '--exit-code-from=build'.
# L'option '--exit-code-from=build' signifie que la commande 'docker compose up' renverra le code de sortie du service 'build'.
# Si le service 'build' se termine avec un code de sortie non nul (ce qui signifie qu'une erreur s'est produite), alors 'docker compose up' se terminera également avec un code de sortie non nul.
# Cela permet à Make de savoir si la construction du projet a réussi ou non.
build:
 @$(call compose_up,--exit-code-from=build build)

# Vérifier le projet. Actuellement désactivé.
verify:
 @echo "Vérification désactivée"

# Démarrer les services 'serve' et 'qrcode'.
serve:
 @$(call compose_up, --force-recreate serve qrcode)

# Démarrer un shell à l'intérieur du conteneur du service 'serve'.
shell:
 @$(call compose_run,--entrypoint=sh --rm serve)

# Mettre à jour le fichier de verrouillage pour les dépendances npm.
dependencies-lock-update:
 @$(call compose_run,--entrypoint=npm --rm serve install --package-lock)

# Mettre à jour les dépendances npm et le fichier de verrouillage.
dependencies-update:
 @$(call compose_run,--entrypoint=ncu --workdir=/app/npm-packages --rm serve -u)
 @make -C $(CURDIR) dependencies-lock-update

# Construire une version PDF du projet.
pdf:
 @$(call compose_up, --exit-code-from=pdf pdf)

# Nettoyer le projet en arrêtant et en supprimant les conteneurs Docker, les réseaux et les volumes.
clean:
 @$(call compose_cmd, down -v --remove-orphans)
 @rm -rf $(DIST_DIR)

# Démarrer le service 'qrcode'.
qrcode:
 @$(call compose_up, qrcode)

# Déclarer des cibles factices.
.PHONY: all build verify serve qrcode pdf dependencies-update dependencies-lock-update