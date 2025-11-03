# ✅ Image slim (beaucoup moins de vulnérabilités)
FROM python:3.11-slim

# ✅ Créer un utilisateur non-root
RUN groupadd -r flaskuser && useradd -r -g flaskuser flaskuser

WORKDIR /app

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

# ✅ Processus s'exécute en tant que flaskuser
CMD ["python", "app.py"]
