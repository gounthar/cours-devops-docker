# VULNÉRABILITÉ : Image full (non slim), beaucoup de vulnérabilités
FROM python:3.11

# VULNÉRABILITÉ : Pas d'utilisateur non-root, tout tourne en root !

WORKDIR /app

# Copier les dépendances
COPY requirements.txt .

# VULNÉRABILITÉ : pip install sans --no-cache-dir, image plus lourde
RUN pip install -r requirements.txt

# Copier le code
COPY . .

# VULNÉRABILITÉ : Port privilégié si < 1024, mais ici 5000 OK
EXPOSE 5000

# VULNÉRABILITÉ : Tourne en tant que root !
CMD ["python", "app.py"]
