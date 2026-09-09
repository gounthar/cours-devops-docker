# Ce Dockerfile met en place un serveur web simple en utilisant Nginx sur Alpine Linux.

# Utilise Alpine Linux comme image de base. Alpine Linux est une distribution Linux légère et orientée sécurité.
FROM alpine

# Installe Nginx sans conserver l'index des paquets dans la couche.
# Nginx est un serveur web populaire qui peut également être utilisé comme proxy inverse, équilibreur de charge et cache HTTP.
RUN apk add --no-cache nginx

# Expose le port 80 au monde extérieur. C'est le port standard pour le trafic HTTP.
EXPOSE 80

# Ajoute un fichier HTML à la racine du document Nginx.
# Remplacez /chemin/vers/votre/fichier.html par le chemin réel vers votre fichier HTML.
ADD /chemin/vers/votre/fichier.html /usr/share/nginx/html

# Définit le point d'entrée pour le conteneur. Cette commande sera exécutée lorsque le conteneur démarre.
# La commande "nginx" démarre le serveur Nginx.
# Le flag "-g" nous permet de définir des directives globales. Dans ce cas, nous disons à Nginx de fonctionner au premier plan (daemon off;).
ENTRYPOINT ["nginx", "-g", "daemon off;"]