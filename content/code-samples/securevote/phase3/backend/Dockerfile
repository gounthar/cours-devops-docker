# ✅ Image slim (beaucoup moins de vulnérabilités)
FROM python:3.15-slim

# ✅ Installer curl pour le healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

# ✅ Créer un utilisateur non-root
RUN groupadd -r flaskuser && useradd -r -g flaskuser flaskuser

WORKDIR /app

# ✅ Logs Python envoyés tout de suite (sinon ils restent dans un tampon,
# et un print fait avant le fork des workers Gunicorn sort en double)
ENV PYTHONUNBUFFERED=1

# Copier les dépendances d'abord (meilleur cache)
COPY requirements.txt .

# ✅ Installation avec --no-cache-dir pour réduire la taille
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY --chown=flaskuser:flaskuser . .

# ✅ Changer le propriétaire des fichiers
RUN chown -R flaskuser:flaskuser /app

# ✅ Passer à l'utilisateur non-root
USER flaskuser

EXPOSE 5000

# ✅ Serveur WSGI de production, en tant que flaskuser
CMD ["gunicorn", "--config", "gunicorn.conf.py", "app:app"]
