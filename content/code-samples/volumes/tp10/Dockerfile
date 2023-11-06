FROM alpine:3.18

# Ajoutez des fichiers dans un dossier
RUN mkdir /mon-dossier
RUN echo "Contenu du fichier 1" > /mon-dossier/fichier1.txt
RUN echo "Contenu du fichier 2" > /mon-dossier/fichier2.txt

# Déclarez ce dossier comme un volume anonyme
VOLUME ["/mon-dossier"]

# Ajoutez d'autres fichiers dans ce dossier
RUN echo "Nouveau contenu du fichier 3" > /mon-dossier/fichier3.txt
