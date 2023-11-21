# Ce Dockerfile met en place un environnement Node.js avec des outils et dépendances supplémentaires.
# Il est basé sur l'image Docker officielle de Node.js (version 18, variante Alpine).

FROM node:18-alpine

# Installer la dernière version des dépendances requises
# hadolint ignore=DL3018
RUN apk add --no-cache \
  curl \ # Outil pour transférer des données avec des URLs
  git \ # Système de contrôle de version distribué
  tini \ # Un init minuscule mais valide pour les conteneurs
  unzip # Outil pour décompresser les fichiers zip

# Installer les dépendances NPM globalement (dernières versions)
# hadolint ignore=DL3016,DL3059
RUN npm install --global npm npm-check-updates # Mettre à jour npm à la dernière version et installer npm-check-updates

# Copier les dépendances NPM de l'application dans l'image Docker
COPY ./npm-packages /app/npm-packages
# Créer des liens symboliques pour package.json et package-lock.json à la racine de /app
# Cela permet d'exécuter les opérations npm sans erreur ENOENT
RUN ln -s /app/npm-packages/package.json /app/package.json \
  && ln -s /app/npm-packages/package-lock.json /app/package-lock.json

# Définir le répertoire de travail dans l'image Docker à /app
WORKDIR /app

# Télécharger et installer une version spécifique de FontAwesome
ARG FONTAWESOME_VERSION=6.4.0
RUN curl --silent --show-error --location --output /tmp/fontawesome.zip \
    "https://use.fontawesome.com/releases/v${FONTAWESOME_VERSION}/fontawesome-free-${FONTAWESOME_VERSION}-web.zip" \
  && unzip -q /tmp/fontawesome.zip -d /tmp \
  && mv /tmp/"fontawesome-free-${FONTAWESOME_VERSION}-web" /app/fontawesome \
  && rm -rf /tmp/font*

# Installer les dépendances NPM en utilisant le package-lock.json
# Si l'installation échoue, revenir à une installation npm régulière
RUN { npm install-clean && npx update-browserslist-db@latest; } || npm install

# Lier la commande gulp pour qu'elle soit disponible dans le PATH
# hadolint ignore=DL3059
RUN npm link gulp

# Copier les tâches gulp et la configuration dans l'image Docker
COPY ./gulp/tasks /app/tasks
COPY ./gulp/gulpfile.js /app/gulpfile.js

# Définir un volume pour le répertoire /app
VOLUME ["/app"]

# Exposer le port 8000 pour HTTP
EXPOSE 8000

# Utiliser tini comme point d'entrée, et exécuter gulp par défaut
ENTRYPOINT ["/sbin/tini","-g","gulp"]
CMD ["default"]