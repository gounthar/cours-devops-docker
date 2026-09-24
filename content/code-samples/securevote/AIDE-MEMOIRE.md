# SecureVote - Aide-mémoire Étudiant

## 🚀 Démarrage rapide

```bash
# Phase 1 : Démarrer l'application
cd phase1
docker compose up -d
# Accéder : http://localhost:8080

# Phase 2 : Sécuriser
cd ../phase2
cp .env.example .env
# Éditer .env avec vos valeurs
docker compose up -d

# Phase 3 : Production
cd ../phase3
cp ../phase2/.env .
docker compose up -d
```

---

## 🔍 Commandes de diagnostic

### Vérifier l'état des conteneurs
```bash
# Liste des services
docker compose ps

# Voir les logs
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f backend

# Statistiques ressources
docker stats
```

### Inspecter un conteneur
```bash
# Qui exécute le processus ?
docker compose exec backend whoami

# Variables d'environnement
docker compose exec backend env

# Accéder au shell
docker compose exec backend sh

# Voir les processus
docker compose exec backend ps aux
```

---

## 🔒 Sécurité

### Scanner les vulnérabilités
```bash
# Avec Docker Scout
docker scout cves nom-image:tag
docker scout cves nom-image:tag --only-severity critical,high

# Avec Trivy
trivy image nom-image:tag
trivy image nom-image:tag --severity HIGH,CRITICAL
```

### Dockerfile sécurisé
```dockerfile
# ✅ Image légère
FROM python:3.11-slim

# ✅ Créer un utilisateur non-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copier avec les bons propriétaires
COPY --chown=appuser:appuser . .

# ✅ Passer à l'utilisateur non-root
USER appuser

CMD ["python", "app.py"]
```

### Gestion des secrets
```bash
# Créer .env
cp .env.example .env

# Générer un secret fort
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Vérifier .gitignore
cat .gitignore | grep .env

# Variables dans docker-compose.yml
environment:
  PASSWORD: ${DB_PASSWORD}  # Pas en clair !
```

---

## ⚙️ Production

### Limites de ressources
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### Politiques de redémarrage
```yaml
# Services applicatifs
restart: on-failure:5

# Infrastructure (DB, cache)
restart: unless-stopped
```

### Health checks
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Dépendances
```yaml
backend:
  depends_on:
    database:
      condition: service_healthy
    cache:
      condition: service_healthy
```

---

## 🧪 Tests

### Test de charge
```bash
# Donner les droits
chmod +x scripts/load_test.sh

# Lancer (100 votes, 10 en parallèle)
./scripts/load_test.sh http://localhost:8080 100 10

# Observer les ressources
docker stats
```

### Test de résilience
```bash
# Tuer un service
docker compose kill backend

# Observer le redémarrage
watch -n 1 docker compose ps

# Ou utiliser le script
chmod +x scripts/kill_test.sh
./scripts/kill_test.sh
```

### Vérifier les health checks
```bash
# Tous doivent être (healthy)
docker compose ps

# Tester l'endpoint manuellement
curl http://localhost:8080/health
```

---

## 🛠️ Dépannage

### Port déjà utilisé
```bash
# Changer le port dans .env
echo "PROXY_PORT=8081" >> .env
```

### Permission denied après USER
```dockerfile
# Utiliser chown
COPY --chown=user:group . /app
```

### Service unhealthy
```bash
# Voir les logs
docker compose logs backend

# Tester le health manuellement
docker compose exec backend curl http://localhost:5000/health

# Augmenter start_period
healthcheck:
  start_period: 60s
```

### Variables .env non lues
```bash
# Vérifier l'emplacement
ls -la .env  # Doit être à côté de docker-compose.yml

# Vérifier la substitution
docker compose config | grep PASSWORD
```

### Build échoue
```bash
# Nettoyer et reconstruire
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

---

## 📋 Checklist de validation

### Phase 1 ✅
- [ ] Application démarre sur http://localhost:8080
- [ ] Vote fonctionne
- [ ] Au moins 5 vulnérabilités identifiées

### Phase 2 ✅
- [ ] Images scannées : <10 CVE critical
- [ ] `whoami` retourne un user non-root
- [ ] `.env` créé et `.gitignore` configuré
- [ ] Pas de secrets en clair dans docker-compose.yml
- [ ] Application fonctionne

### Phase 3 ✅
- [ ] Tous les services (healthy) dans `docker compose ps`
- [ ] Limites de ressources définies
- [ ] Test de charge réussi
- [ ] Test de kill avec récupération automatique
- [ ] Application stable

---

## 🎯 Commandes essentielles

### Gestion des services
```bash
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Redémarrer un service
docker compose restart backend

# Reconstruire
docker compose build
docker compose up -d --build

# Voir la configuration finale
docker compose config
```

### Nettoyage
```bash
# Arrêter et supprimer les volumes
docker compose down -v

# Supprimer les images
docker compose down --rmi all

# Nettoyer le système
docker system prune -a
```

### Logs
```bash
# Tous les logs
docker compose logs

# Suivre en temps réel
docker compose logs -f

# Dernières 50 lignes
docker compose logs --tail=50

# Logs d'un service
docker compose logs backend
```

---

## 📚 Ressources utiles

### Documentation officielle
- Docker Security : https://docs.docker.com/engine/security/
- Docker Compose : https://docs.docker.com/compose/
- Health checks : https://docs.docker.com/engine/reference/builder/#healthcheck

### Outils de scan
- Docker Scout : https://docs.docker.com/scout/
- Trivy : https://github.com/aquasecurity/trivy

### Bonnes pratiques
- CIS Docker Benchmark : https://www.cisecurity.org/benchmark/docker
- OWASP Docker Security : https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html

---

## 💡 Astuces

### Dockerfile
- Utilisez toujours `slim` ou `alpine`
- Créez un utilisateur dédié
- Nettoyez les caches (`--no-cache-dir`, `npm cache clean`)
- Multi-stage builds pour optimiser

### Secrets
- **JAMAIS** de secrets en clair
- `.env` + `.gitignore`
- `.env.example` pour documenter
- Générateurs de secrets forts

### Production
- Limites de ressources pour TOUS les services
- Health checks qui testent les vraies dépendances
- `start_period` suffisant pour l'initialisation
- Logs avec rotation

### Debugging
- `docker compose logs` est votre ami
- `docker stats` pour les ressources
- `docker compose exec service sh` pour investiguer
- `docker compose config` pour voir la config finale

---

## ✅ Points clés à retenir

1. **Ne jamais exécuter en root** → Créer un user dédié
2. **Ne jamais committer de secrets** → .env + .gitignore
3. **Toujours scanner les images** → slim/alpine + Trivy
4. **N'exposer que le nécessaire** → Réseaux isolés
5. **Auto-healing en production** → restart + healthchecks
6. **Limiter les ressources** → Protéger le système
7. **Tester la résilience** → kill + observer

---

## 🎓 Pour aller plus loin

- Orchestration : Kubernetes, Docker Swarm
- Secrets Management : HashiCorp Vault
- Monitoring : Prometheus + Grafana
- CI/CD : GitHub Actions, GitLab CI
- Image Signing : Cosign (Sigstore), Notation (Docker Content Trust est retiré)
- Runtime Security : Falco

---

**Bonne chance ! 🚀**
