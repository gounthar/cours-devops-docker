# ✅ Build stage - Image complète pour la compilation
FROM node:20-alpine AS builder

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# ✅ Installer SEULEMENT les dépendances de production
RUN npm install --production && npm cache clean --force

# Copier le code source
COPY . .

# ✅ Build de production optimisé
RUN npm run build

# ✅ Runtime stage - Image finale légère pour servir les fichiers
FROM node:20-alpine

# ✅ Créer un utilisateur non-root
RUN addgroup -g 1001 -S reactuser && \
    adduser -S reactuser -u 1001

# Installer serve pour servir les fichiers statiques
RUN npm install -g serve && npm cache clean --force

WORKDIR /app

# Copier seulement le build depuis le stage précédent
COPY --from=builder --chown=reactuser:reactuser /app/build ./build

# ✅ Passer à l'utilisateur non-root
USER reactuser

EXPOSE 3000

# ✅ Servir les fichiers statiques avec serve
CMD ["serve", "-s", "build", "-l", "3000"]
