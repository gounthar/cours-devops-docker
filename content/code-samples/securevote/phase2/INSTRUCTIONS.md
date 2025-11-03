# Phase 2 : Sécurisation - SecureVote (1h15)

## Objectif

Corriger toutes les vulnérabilités identifiées en Phase 1 et transformer SecureVote en application sécurisée.

## Prérequis

- Avoir complété la Phase 1
- Docker et Docker Compose installés
- Docker Scout ou Trivy pour scanner les images

## Vue d'ensemble des corrections

Cette phase corrige :
- ✅ Images légères et sécurisées (alpine/slim)
- ✅ Utilisateurs non-root pour tous les services
- ✅ Secrets protégés avec .env
- ✅ Ports internes non exposés
- ✅ Réseaux isolés
- ✅ Health check fonctionnel
- ✅ Configuration production

## Exercice 1 : Images sécurisées (20 min)

### Objectif
Remplacer les images lourdes par des versions optimisées et scanner les vulnérabilités.

### Étapes

1. **Comparer les images actuelles** (Phase 1)

```bash
cd ../phase1

# Scanner l'image backend actuelle
docker scout cves phase1-backend:latest --only-severity high,critical

# Ou avec Trivy
trivy image phase1-backend:latest --severity HIGH,CRITICAL
```

Notez le nombre de vulnérabilités HIGH et CRITICAL.

2. **Modifier les Dockerfiles**

**Backend (`backend/Dockerfile`)** :
- Remplacer `FROM python:3.11` par `FROM python:3.11-slim`
- Ajouter `--no-cache-dir` à pip install

**Frontend (`frontend/Dockerfile`)** :
- Remplacer `FROM node:20` par `FROM node:20-alpine`
- Utiliser un build multi-stage (voir phase2/frontend/Dockerfile)

3. **Reconstruire et scanner**

```bash
cd ../phase2
docker compose build backend frontend

# Scanner les nouvelles images
docker scout cves phase2-backend:latest --only-severity high,critical
docker scout cves phase2-frontend:latest --only-severity high,critical
```

4. **Comparer les résultats**

| Image | Vulnérabilités avant | Vulnérabilités après | Gain |
|-------|---------------------|---------------------|------|
| Backend | ~150 CVE | ~10 CVE | 93% |
| Frontend | ~200 CVE | ~5 CVE | 97% |

### Points clés
- Les images `slim` et `alpine` contiennent beaucoup moins de packages
- Réduction drastique de la surface d'attaque
- Images plus légères = déploiements plus rapides

## Exercice 2 : Utilisateurs non-root (25 min)

### Objectif
Créer des utilisateurs dédiés pour chaque service et vérifier qu'aucun processus ne tourne en root.

### Étapes

1. **Modifier le Dockerfile backend**

Ajoutez après la ligne `FROM` :

```dockerfile
FROM python:3.11-slim

# Créer un utilisateur non-root
RUN groupadd -r flaskuser && useradd -r -g flaskuser flaskuser

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier avec les bons propriétaires
COPY --chown=flaskuser:flaskuser . .

# Passer à l'utilisateur non-root
USER flaskuser

CMD ["python", "app.py"]
```

2. **Modifier le Dockerfile frontend**

Utilisez un build multi-stage avec utilisateur non-root (voir fichier phase2) :

```dockerfile
FROM node:20-alpine AS builder
# ... build ...

FROM node:20-alpine
RUN addgroup -g 1001 -S reactuser && \
    adduser -S reactuser -u 1001

COPY --from=builder --chown=reactuser:reactuser /app/build ./build
USER reactuser
CMD ["serve", "-s", "build", "-l", "3000"]
```

3. **Modifier docker-compose.yml pour Nginx**

Remplacer l'image nginx standard par la version unprivileged :

```yaml
proxy:
  image: nginxinc/nginx-unprivileged:alpine
  ports:
    - "8080:8080"  # Port 8080 au lieu de 80 (non privilégié)
```

Adapter `proxy/nginx.conf` pour écouter sur le port 8080.

4. **Reconstruire et tester**

```bash
docker compose build
docker compose up -d
```

5. **Vérifier les utilisateurs**

```bash
# Vérifier backend
docker compose exec backend whoami
# Doit afficher : flaskuser

# Vérifier frontend
docker compose exec frontend whoami
# Doit afficher : reactuser

# Vérifier proxy
docker compose exec proxy whoami
# Doit afficher : nginx (UID 101, pas root)

# Vérifier les processus
docker compose exec backend ps aux
# Aucun processus ne doit avoir UID 0
```

### Validation

Si toutes les commandes `whoami` retournent un utilisateur différent de `root`, c'est validé ✅

### Points clés
- Toujours créer un utilisateur dédié
- Ne jamais revenir à root après USER
- nginx-unprivileged est prévu pour tourner sans privilèges

## Exercice 3 : Sécuriser les secrets (30 min)

### Objectif
Supprimer tous les secrets en clair et utiliser un fichier .env protégé.

### Étapes

1. **Créer le fichier .env**

```bash
cp .env.example .env
```

Éditez `.env` et remplissez avec des valeurs sécurisées :

```bash
# Génerer des secrets forts
python3 -c "import secrets; print('DB_PASSWORD=' + secrets.token_urlsafe(32))"
python3 -c "import secrets; print('REDIS_PASSWORD=' + secrets.token_urlsafe(32))"
python3 -c "import secrets; print('SECRET_KEY=' + secrets.token_urlsafe(64))"
```

Exemple de `.env` final :

```env
DB_NAME=securevote
DB_USER=dbuser
DB_PASSWORD=xK8vPq2mRn4tYs9wZu1aHj7bVc6dLe0fNg3hMi5kOp8qWr2sXu4vZy6
REDIS_PASSWORD=aB7cD9eF1gH3iJ5kL7mN9oP1qR3sT5uV7wX9yZ1
SECRET_KEY=zY8xW6vU4tS2rQ0pO9nM7lK5jI3hG1fE9dC7bA5
FLASK_ENV=production
PROXY_PORT=8080
```

2. **Créer .gitignore**

```bash
cat > .gitignore << EOF
.env
secrets/
__pycache__/
node_modules/
build/
*.log
EOF
```

**IMPORTANT** : Vérifiez que `.env` est bien ignoré :

```bash
git status
# .env ne doit PAS apparaître dans les fichiers à commiter
```

3. **Modifier docker-compose.yml**

Remplacez tous les secrets en clair :

```yaml
# AVANT (MAUVAIS)
environment:
  POSTGRES_PASSWORD: admin123

# APRÈS (BON)
environment:
  POSTGRES_PASSWORD: ${DB_PASSWORD}
```

4. **Modifier app.py pour valider les secrets**

```python
SECRET_KEY = os.getenv('SECRET_KEY')
if not SECRET_KEY:
    raise ValueError("SECRET_KEY doit être définie !")
```

5. **Tester**

```bash
# Sans .env, ça doit échouer
mv .env .env.backup
docker compose up -d
# Erreur attendue : variable non définie

# Avec .env, ça doit fonctionner
mv .env.backup .env
docker compose up -d
docker compose ps
```

6. **Vérifier que les secrets ne sont plus visibles**

```bash
# Vérifier qu'on ne peut pas voir les secrets en clair
docker compose config
# Les valeurs doivent être remplacées par les vraies valeurs du .env

# Mais ne sont pas dans les fichiers versionnés
cat docker-compose.yml | grep -i password
# Doit afficher : ${DB_PASSWORD}, pas la vraie valeur
```

### Validation

- ✅ Fichier `.env` créé et fonctionnel
- ✅ `.env` dans `.gitignore`
- ✅ Plus aucun secret en clair dans `docker-compose.yml`
- ✅ Application démarre et fonctionne

### Points clés
- **JAMAIS** commiter de secrets dans Git
- Utiliser `.env.example` comme template sans valeurs sensibles
- Documenter les secrets requis
- Utiliser des générateurs de secrets forts

## Checkpoint intermédiaire

À ce stade, votre application doit :
- ✅ Utiliser des images slim/alpine
- ✅ S'exécuter avec des utilisateurs non-root
- ✅ Avoir tous les secrets dans .env
- ✅ Fonctionner correctement sur http://localhost:8080

Testez l'application avant de continuer.

## Exercice 4 : Isolation réseau (20 min - Bonus)

### Objectif
Isoler les services en créant des réseaux dédiés.

### Étapes

1. **Analyser l'architecture réseau**

```
                [Proxy]
                /     \
          [Frontend] [Backend]
                      /     \
              [Database]  [Cache]
```

Principes :
- Frontend et Backend doivent communiquer avec Proxy
- Backend doit communiquer avec Database et Cache
- Frontend n'a PAS besoin d'accéder à Database/Cache directement

2. **Définir les réseaux**

```yaml
networks:
  frontend-network:
    driver: bridge
  backend-network:
    driver: bridge
```

3. **Assigner les services aux réseaux**

```yaml
services:
  database:
    networks:
      - backend-network  # Seulement backend

  cache:
    networks:
      - backend-network  # Seulement backend

  backend:
    networks:
      - frontend-network  # Pour communiquer avec proxy
      - backend-network   # Pour accéder à DB et cache

  frontend:
    networks:
      - frontend-network  # Pour communiquer avec proxy

  proxy:
    networks:
      - frontend-network  # Pour accéder à frontend et backend
```

4. **Supprimer les ports exposés inutiles**

Dans `docker-compose.yml`, supprimez :

```yaml
# À SUPPRIMER
ports:
  - "5432:5432"  # Database - pas besoin d'exposer
  - "6379:6379"  # Cache - pas besoin d'exposer
  - "5000:5000"  # Backend - accès via proxy uniquement
  - "3000:3000"  # Frontend - accès via proxy uniquement
```

Gardez seulement :
```yaml
proxy:
  ports:
    - "8080:8080"  # Point d'entrée unique
```

5. **Tester l'isolation**

```bash
docker compose up -d

# Le frontend ne peut PAS accéder à la database
docker compose exec frontend ping database
# Doit échouer : Name or service not known

# Le backend PEUT accéder à la database
docker compose exec backend ping database
# Doit réussir
```

### Validation

- ✅ Seulement le port 8080 exposé sur l'hôte
- ✅ Services isolés selon leur besoin de communication
- ✅ Application fonctionne correctement

## Récapitulatif des corrections

### Avant (Phase 1) ❌
- Images complètes avec ~150-200 CVE
- Tous les services en root
- Secrets en clair dans docker-compose.yml
- 5 ports exposés inutilement
- Réseau unique par défaut
- Pas de healthcheck réel

### Après (Phase 2) ✅
- Images slim/alpine avec ~5-10 CVE (réduction de 95%)
- Utilisateurs dédiés non-root
- Secrets dans .env (non versionné)
- 1 seul port exposé (8080)
- Réseaux isolés par fonction
- Healthcheck fonctionnel qui teste les dépendances

## Tests de validation finale

```bash
# 1. Scanner les images
docker scout cves securevote-backend:latest --only-severity critical
docker scout cves securevote-frontend:latest --only-severity critical

# 2. Vérifier les utilisateurs
docker compose exec backend whoami  # flaskuser
docker compose exec frontend whoami  # reactuser

# 3. Vérifier les secrets
cat docker-compose.yml | grep -i password  # Aucune valeur en clair
cat .env | head -n 3  # Valeurs présentes dans .env

# 4. Vérifier les ports
docker compose ps
# Seulement 8080 exposé

# 5. Vérifier le healthcheck
curl http://localhost:8080/health
# {"status":"healthy","checks":{"database":"ok","cache":"ok"}}

# 6. Tester l'application
curl http://localhost:8080/api/options
# Liste des options de vote
```

## Commandes utiles pour le debugging

```bash
# Voir les logs
docker compose logs -f backend

# Accéder à un conteneur
docker compose exec backend sh

# Reconstruire après modifications
docker compose build --no-cache backend

# Redémarrer un service
docker compose restart backend

# Voir la configuration finale
docker compose config
```

## Points clés à retenir

1. **Images** : Toujours préférer slim/alpine, scanner régulièrement
2. **Utilisateurs** : JAMAIS de root, toujours créer un user dédié
3. **Secrets** : .env + .gitignore, JAMAIS de secrets dans le code versionné
4. **Réseaux** : Isoler selon le principe du moindre privilège
5. **Exposition** : Seulement les ports strictement nécessaires

## Prochaine étape

➡️ Passez à la **Phase 3 : Production** pour optimiser les performances et la résilience !
