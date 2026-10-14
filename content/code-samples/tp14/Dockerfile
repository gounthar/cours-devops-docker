# Ce Dockerfile met en place un serveur web simple en utilisant Nginx sur Alpine Linux.

# Utilise Alpine Linux comme image de base. Alpine Linux est une distribution Linux légère et orientée sécurité.
FROM alpine

# Installe Nginx sans conserver l'index des paquets dans la couche.
# Le site par défaut de nginx sous Alpine répond 404 partout : on le remplace.
RUN apk add --no-cache nginx \
 && printf 'server {\n    listen 80;\n    root /usr/share/nginx/html;\n}\n' > /etc/nginx/http.d/default.conf

# Expose le port 80 au monde extérieur. C'est le port standard pour le trafic HTTP.
EXPOSE 80

# Barre finale obligatoire : sans elle, COPY crée un FICHIER nommé html.
COPY html/index.html /usr/share/nginx/html/

# Définit le point d'entrée du conteneur : le serveur Nginx.
# Le flag "-g" passe une directive globale : "daemon off;" garde Nginx au premier plan.
ENTRYPOINT ["nginx", "-g", "daemon off;"]
