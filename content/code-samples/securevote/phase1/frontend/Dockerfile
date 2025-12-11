# VULNÉRABILITÉ : Image node complète (non slim/alpine)
FROM node:20

# VULNÉRABILITÉ : Pas d'utilisateur non-root, tout tourne en root !

WORKDIR /app

# Copier package files
COPY package*.json ./

# VULNÉRABILITÉ : npm install sans --production ni cache cleanup
RUN npm install

# Copier le code source
COPY . .

# VULNÉRABILITÉ : Expose le port 3000 en dev mode avec hot-reload
EXPOSE 3000

# VULNÉRABILITÉ : Utilise le serveur de développement React en production !
CMD ["npm", "start"]
