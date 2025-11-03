# Phase 3 : Production - SecureVote (1h)

## Objectif

Optimiser SecureVote pour un environnement de production : ressources, résilience, monitoring.

## Prérequis

- Avoir complété la Phase 2
- Application sécurisée fonctionnelle

## Vue d'ensemble des optimisations

Cette phase ajoute :
- ✅ Limites de ressources CPU/RAM
- ✅ Politiques de redémarrage automatique
- ✅ Health checks applicatifs
- ✅ Dépendances avec conditions de santé
- ✅ Logs optimisés avec rotation
- ✅ Tests de charge et résilience

## Exercice 4 : Limites de ressources (20 min)

### Objectif
Définir des limites appropriées pour éviter qu'un conteneur monopolise le serveur.

### Étape 1 : Observer la consommation actuelle

```bash
cd ../phase2

# Démarrer l'application
docker compose up -d

# Observer en temps réel (laisser tourner quelques minutes)
docker stats

# Résultats typiques :
# CONTAINER         CPU %    MEM USAGE / LIMIT
# backend           5-15%    150-200 MiB
# frontend          1-3%     50-80 MiB
# database          2-8%     40-60 MiB
# cache             0-2%     10-20 MiB
# proxy             1-2%     5-10 MiB
```

### Étape 2 : Effectuer un test de charge

```bash
# Donner les droits d'exécution au script
chmod +x ../phase3/scripts/load_test.sh

# Lancer le test (100 votes, 10 en parallèle)
../phase3/scripts/load_test.sh http://localhost:8080 100 10

# Observer les ressources pendant le test
docker stats --no-stream
```

### Étape 3 : Définir les limites

Basé sur l'observation, définir des limites avec 30-50% de marge.

Dans `docker-compose.yml`, ajoutez pour chaque service :

```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '1.0'      # Maximum 1 CPU
          memory: 512M     # Maximum 512 Mo
        reservations:
          cpus: '0.25'     # Minimum garanti
          memory: 256M
```

**Limites recommandées :**

| Service  | CPU Limit | Memory Limit | CPU Reserve | Memory Reserve |
|----------|-----------|--------------|-------------|----------------|
| database | 0.5       | 512M         | 0.25        | 256M           |
| cache    | 0.25      | 256M         | 0.1         | 128M           |
| backend  | 1.0       | 512M         | 0.25        | 256M           |
| frontend | 0.5       | 256M         | 0.1         | 128M           |
| proxy    | 0.5       | 128M         | 0.1         | 64M            |

### Étape 4 : Tester avec les limites

```bash
cd ../phase3

# Copier le .env de phase2
cp ../phase2/.env .

# Démarrer avec les nouvelles limites
docker compose up -d

# Vérifier que les limites sont appliquées
docker stats

# Relancer le test de charge
./scripts/load_test.sh http://localhost:8080 200 20
```

### Étape 5 : Tester le dépassement

Simuler une fuite mémoire ou charge excessive :

```bash
# Générer une charge CPU sur le backend
docker compose exec backend sh -c "yes > /dev/null" &

# Observer : le CPU ne doit pas dépasser la limite
docker stats --no-stream

# Arrêter la charge
docker compose restart backend
```

### Validation

- ✅ Limites définies pour tous les services
- ✅ Application fonctionne normalement
- ✅ Test de charge réussi
- ✅ Les services ne dépassent pas leurs limites

### Points clés
- Limites = protection du système
- Réservations = garanties pour le service
- Toujours tester sous charge réelle
- Ajuster selon les besoins observés

## Exercice 5 : Restart et Health Checks (25 min)

### Objectif
Configurer l'auto-healing pour que les services redémarrent automatiquement en cas de problème.

### Étape 1 : Politiques de redémarrage

Ajoutez à chaque service :

```yaml
services:
  backend:
    restart: on-failure:5  # Redémarre max 5 fois si erreur

  database:
    restart: unless-stopped  # Toujours sauf si arrêt manuel

  proxy:
    restart: unless-stopped
```

**Quand utiliser quelle politique ?**

- `on-failure:N` : Services applicatifs (backend, frontend)
- `unless-stopped` : Services d'infrastructure (DB, cache, proxy)
- `no` : Services temporaires, jobs
- `always` : Rarement utilisé (redémarre même après `docker compose down`)

### Étape 2 : Health Checks PostgreSQL

```yaml
database:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-dbuser} -d ${DB_NAME:-securevote}"]
    interval: 10s    # Vérifier toutes les 10s
    timeout: 5s      # Timeout après 5s
    retries: 5       # 5 échecs avant unhealthy
    start_period: 10s # Attendre 10s au démarrage
```

### Étape 3 : Health Checks Redis

```yaml
cache:
  healthcheck:
    test: ["CMD", "redis-cli", "--raw", "-a", "${REDIS_PASSWORD}", "incr", "ping"]
    interval: 10s
    timeout: 3s
    retries: 5
    start_period: 5s
```

### Étape 4 : Health Check Backend

Le backend doit vérifier ses dépendances. Dans `app.py` :

```python
@app.route('/health')
def health():
    """Endpoint de santé complet"""
    status = {"status": "healthy", "checks": {}}
    http_code = 200

    # Vérifier PostgreSQL
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        status["checks"]["database"] = "ok"
    except Exception as e:
        status["checks"]["database"] = f"error: {str(e)}"
        status["status"] = "unhealthy"
        http_code = 503

    # Vérifier Redis
    try:
        redis_client.ping()
        status["checks"]["cache"] = "ok"
    except Exception as e:
        status["checks"]["cache"] = f"error: {str(e)}"
        status["status"] = "unhealthy"
        http_code = 503

    return jsonify(status), http_code
```

Dans `docker-compose.yml` :

```yaml
backend:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 40s  # Temps pour init DB
```

### Étape 5 : Health Check Frontend

```yaml
frontend:
  healthcheck:
    test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 30s
```

### Étape 6 : Health Check Proxy

```yaml
proxy:
  healthcheck:
    test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 10s
```

### Étape 7 : Tester les Health Checks

```bash
# Redémarrer avec les healthchecks
docker compose up -d

# Attendre que tous soient healthy
docker compose ps

# Devrait afficher (healthy) pour tous les services
# NAME                 STATUS
# securevote-backend   Up (healthy)
# securevote-db        Up (healthy)
# ...

# Tester manuellement le endpoint
curl http://localhost:8080/health
# {"status":"healthy","checks":{"database":"ok","cache":"ok"}}
```

### Étape 8 : Tester le redémarrage automatique

```bash
# Donner les droits au script de test
chmod +x scripts/kill_test.sh

# Lancer le test de résilience
./scripts/kill_test.sh

# Observe :
# - Les conteneurs sont tués brutalement
# - Ils redémarrent automatiquement
# - Redeviennent healthy après quelques secondes
```

Test manuel :

```bash
# Tuer le backend
docker compose kill backend

# Observer le redémarrage automatique
watch -n 1 docker compose ps

# Dans quelques secondes, le backend doit être "Up (healthy)"
```

### Validation

- ✅ Tous les services ont une politique de restart
- ✅ Tous les services ont un healthcheck
- ✅ Les services redémarrent automatiquement après un crash
- ✅ Les healthchecks retournent "healthy"

### Points clés
- Health checks = détection automatique des problèmes
- L'endpoint /health doit être simple et rapide
- Tester réellement les dépendances critiques
- start_period = temps pour l'initialisation

## Exercice 6 : Dépendances et ordre de démarrage (15 min)

### Objectif
Garantir que les services démarrent dans le bon ordre et seulement si leurs dépendances sont prêtes.

### Étape 1 : Définir les dépendances avec conditions

```yaml
backend:
  depends_on:
    database:
      condition: service_healthy  # Attendre que la DB soit healthy
    cache:
      condition: service_healthy  # Attendre que Redis soit healthy

frontend:
  depends_on:
    backend:
      condition: service_healthy  # Attendre que le backend soit healthy

proxy:
  depends_on:
    frontend:
      condition: service_healthy
    backend:
      condition: service_healthy
```

### Étape 2 : Tester l'ordre de démarrage

```bash
# Arrêter tout
docker compose down

# Démarrer tout
docker compose up -d

# Observer l'ordre de démarrage dans les logs
docker compose logs -f

# Ordre attendu :
# 1. database et cache démarrent
# 2. Attendent d'être healthy
# 3. backend démarre
# 4. Attend d'être healthy
# 5. frontend démarre
# 6. Attend d'être healthy
# 7. proxy démarre
```

### Étape 3 : Tester avec une dépendance cassée

```bash
# Arrêter la DB
docker compose stop database

# Essayer de démarrer le backend
docker compose up backend

# Résultat : Le backend attend que la DB soit healthy
# Il ne démarre pas tant que la DB n'est pas disponible
```

### Validation

- ✅ Services démarrent dans le bon ordre
- ✅ Chaque service attend que ses dépendances soient healthy
- ✅ Pas d'erreurs de connexion au démarrage

### Points clés
- `condition: service_healthy` est crucial en production
- Évite les erreurs "connection refused" au démarrage
- Garantit une initialisation propre

## Exercice 7 : Logs optimisés (Bonus si temps)

### Objectif
Éviter que les logs ne remplissent le disque.

### Configuration des logs

```yaml
backend:
  logging:
    driver: "json-file"
    options:
      max-size: "10m"      # Max 10 Mo par fichier
      max-file: "3"        # Garder 3 fichiers
      labels: "service=backend,env=production"
```

### Tester la rotation

```bash
# Générer beaucoup de logs
for i in {1..1000}; do
  curl http://localhost:8080/api/options > /dev/null 2>&1
done

# Vérifier la taille des logs
docker inspect --format='{{.LogPath}}' securevote-backend
ls -lh /var/lib/docker/containers/*/securevote-backend*-json.log
```

## Récapitulatif Phase 3

### Avant (Phase 2) ⚠️
- Pas de limites de ressources
- Redémarrage manuel
- Pas de health checks
- Ordre de démarrage non garanti
- Logs non limités

### Après (Phase 3) ✅
- Limites CPU/RAM pour chaque service
- Auto-healing avec politiques de restart
- Health checks complets
- Démarrage ordonné avec conditions
- Logs avec rotation automatique

## Tests de validation finale

```bash
# 1. Vérifier les limites
docker stats --no-stream

# 2. Vérifier les health checks
docker compose ps
# Tous doivent être (healthy)

# 3. Test de charge
./scripts/load_test.sh http://localhost:8080 300 30

# 4. Test de résilience
./scripts/kill_test.sh

# 5. Vérifier les logs
docker compose logs --tail=20

# 6. Tester l'application
curl http://localhost:8080/api/options
curl http://localhost:8080/api/results
```

## Métriques de succès

| Critère | Objectif | Validation |
|---------|----------|------------|
| Disponibilité | >99% | ✅ Auto-healing fonctionne |
| Temps de récupération | <30s | ✅ Restart rapide |
| Utilisation CPU | <80% sous charge | ✅ Limites respectées |
| Utilisation RAM | <512M par service | ✅ Pas de fuite mémoire |
| Healthchecks | 100% healthy | ✅ Tous les services OK |

## Configuration finale production-ready

Votre application SecureVote est maintenant :

✅ **Sécurisée**
- Images scannées et optimisées
- Utilisateurs non-root
- Secrets protégés
- Réseaux isolés

✅ **Robuste**
- Auto-healing
- Health checks complets
- Dépendances gérées
- Gestion d'erreur

✅ **Optimisée**
- Limites de ressources
- Logs sous contrôle
- Performance validée
- Monitoring prêt

## Commandes de monitoring

```bash
# Voir l'état global
docker compose ps

# Statistiques en temps réel
docker stats

# Logs en temps réel
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f backend

# Inspecter la santé
curl http://localhost:8080/health | python3 -m json.tool

# Redémarrer un service
docker compose restart backend

# Reconstruire et redéployer
docker compose up -d --build
```

## Aller plus loin

Pour un environnement de production réel, envisagez :

1. **Orchestration** : Kubernetes pour multi-nœuds
2. **Monitoring** : Prometheus + Grafana
3. **Logs centralisés** : ELK Stack ou Loki
4. **Alertes** : Alertmanager
5. **Backup** : Stratégie de sauvegarde DB
6. **SSL/TLS** : Certificats avec Let's Encrypt
7. **CI/CD** : Déploiement automatisé
8. **Load balancing** : NGINX ou HAProxy multi-instances

## Conclusion

🎉 **Félicitations !** Vous avez transformé une application vulnérable en déploiement production-ready !

**Ce que vous avez appris :**
- Scanner et corriger les vulnérabilités
- Appliquer le principe du moindre privilège
- Protéger les secrets
- Limiter les ressources
- Implémenter l'auto-healing
- Garantir l'ordre de démarrage
- Optimiser les logs

**Checklist finale :**
- ✅ Images légères et scannées
- ✅ Utilisateurs non-root
- ✅ Secrets dans .env
- ✅ Réseau isolé
- ✅ Limites de ressources
- ✅ Politiques de restart
- ✅ Health checks
- ✅ Dépendances ordonnées
- ✅ Logs optimisés
- ✅ Tests de résilience validés

Votre application est prête pour la production ! 🚀
