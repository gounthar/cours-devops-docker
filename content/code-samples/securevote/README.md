# SecureVote - Projet Fil Rouge Sécurité et Production Docker

## 🎯 Vue d'ensemble

SecureVote est une application de vote en ligne complète utilisée pour enseigner les bonnes pratiques de sécurité et de configuration production Docker à travers un projet fil rouge progressif de 3 heures.

**Concept :** Les étudiants transforment une application vulnérable en déploiement production-ready et sécurisé.

## 📦 Contenu du package

### 📚 Documentation

- **README.md** (ce fichier) - Vue d'ensemble rapide
- **SOMMAIRE.md** - Documentation complète du package
- **GUIDE_ENSEIGNANT.md** - Guide détaillé pour l'enseignant (timing, astuces, dépannage)
- **AIDE-MEMOIRE.md** - Référence rapide pour les étudiants

### 📁 Structure des phases

```
securevote/
│
├── phase1/                      # 🔴 Version initiale (vulnérable volontairement)
│   ├── INSTRUCTIONS.md          # Guide de découverte pour étudiants
│   ├── docker-compose.yml       # Configuration avec vulnérabilités
│   ├── backend/                 # API Flask (root, image complète, secrets en clair)
│   │   ├── Dockerfile
│   │   ├── app.py
│   │   └── requirements.txt
│   ├── frontend/                # React (root, image complète, dev server)
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── src/
│   │   └── public/
│   └── proxy/                   # Nginx (root, pas de sécurité)
│       └── nginx.conf
│
├── phase2/                      # 🟡 Version sécurisée
│   ├── INSTRUCTIONS.md          # Guide de sécurisation étape par étape
│   ├── docker-compose.yml       # Sécurisé (réseaux, pas de ports exposés)
│   ├── .env.example             # Template des secrets
│   ├── .gitignore               # Protection des secrets
│   ├── backend/                 # API Flask (non-root, slim, secrets protégés)
│   │   ├── Dockerfile
│   │   ├── app.py               # Health check fonctionnel
│   │   └── requirements.txt
│   ├── frontend/                # React (multi-stage, alpine, non-root)
│   │   ├── Dockerfile
│   │   └── [sources]
│   └── proxy/                   # Nginx unprivileged + headers sécurité
│       └── nginx.conf
│
└── phase3/                      # 🟢 Version production-ready
    ├── INSTRUCTIONS.md          # Guide d'optimisation production
    ├── docker-compose.yml       # Complet (limites, restart, healthchecks)
    ├── .env.example
    ├── .gitignore
    ├── backend/                 # Optimisé avec health checks
    │   ├── Dockerfile
    │   ├── app.py
    │   └── requirements.txt
    ├── frontend/                # Build optimisé
    │   ├── Dockerfile
    │   └── [sources]
    ├── proxy/                   # Configuration production
    │   └── nginx.conf
    └── scripts/                 # Tests de validation
        ├── load_test.sh         # Test de charge
        └── kill_test.sh         # Test de résilience
```

## 🏗️ Architecture de l'application

```
                    ┌─────────┐
                    │  Nginx  │ :8080 (seul port exposé)
                    │  Proxy  │
                    └────┬────┘
                         │
            ┌────────────┴────────────┐
            │                         │
      ┌─────▼──────┐           ┌─────▼──────┐
      │  Frontend  │           │  Backend   │
      │   React    │           │   Flask    │
      └────────────┘           └─────┬──────┘
                                     │
                        ┌────────────┴────────────┐
                        │                         │
                  ┌─────▼──────┐           ┌─────▼──────┐
                  │ PostgreSQL │           │   Redis    │
                  │  Database  │           │   Cache    │
                  └────────────┘           └────────────┘
```

**Services :**
- **Frontend** : React 18 - Interface de vote moderne
- **Backend** : Python Flask - API REST pour gérer les votes
- **Database** : PostgreSQL 15 - Stockage persistant des votes
- **Cache** : Redis 7 - Cache des résultats pour performance
- **Proxy** : Nginx - Reverse proxy et point d'entrée unique

## ⏱️ Progression pédagogique (3 heures)

### Phase 1 : Découverte (30 min) - 🔴 Vulnérable
**Objectif :** Identifier les problèmes de sécurité

Les étudiants :
- Démarrent l'application vulnérable
- Testent les fonctionnalités
- Identifient les vulnérabilités (root, secrets, ports, images)
- Scannent avec Docker Scout ou Trivy

**Vulnérabilités présentes :**
- ❌ Tous les services en root
- ❌ Secrets en clair dans docker-compose.yml
- ❌ Ports DB/Cache exposés inutilement
- ❌ Images complètes avec ~150-200 CVE
- ❌ Pas de réseau isolé
- ❌ Flask en mode debug

### Phase 2 : Sécurisation (1h15) - 🟡 Sécurisé
**Objectif :** Corriger toutes les vulnérabilités

Les étudiants :
- **Exercice 1 (20 min)** : Images slim/alpine
- **Exercice 2 (25 min)** : Utilisateurs non-root
- **Exercice 3 (30 min)** : Secrets avec .env + .gitignore
- **Bonus** : Réseaux isolés

**Améliorations :**
- ✅ Images scannées (<10 CVE)
- ✅ Utilisateurs dédiés non-root
- ✅ Secrets dans .env (non versionné)
- ✅ Ports internes uniquement
- ✅ Réseaux frontend/backend séparés

### Phase 3 : Production (1h) - 🟢 Production-ready
**Objectif :** Optimiser pour la production

Les étudiants :
- **Exercice 4 (20 min)** : Limites CPU/RAM
- **Exercice 5 (25 min)** : Restart + Health checks
- **Exercice 6 (15 min)** : Dépendances ordonnées

**Optimisations :**
- ✅ Limites de ressources définies
- ✅ Auto-healing (restart policies)
- ✅ Health checks applicatifs
- ✅ Ordre de démarrage garanti
- ✅ Logs avec rotation

## 🚀 Démarrage rapide

### Pour les enseignants

1. **Lire la documentation**
   ```bash
   # Documentation complète
   cat SOMMAIRE.md

   # Guide pédagogique détaillé
   cat GUIDE_ENSEIGNANT.md
   ```

2. **Préparer l'environnement**
   ```bash
   # Télécharger les images (avant le cours)
   docker pull python:3.11-slim
   docker pull node:20-alpine
   docker pull postgres:15-alpine
   docker pull redis:7-alpine
   docker pull nginxinc/nginx-unprivileged:alpine
   ```

3. **Tester les phases**
   ```bash
   # Phase 1
   cd phase1 && docker compose up -d
   # Vérifier http://localhost:8080
   docker compose down -v

   # Phase 2
   cd ../phase2
   cp .env.example .env
   # Éditer .env avec des valeurs
   docker compose up -d
   docker compose down -v

   # Phase 3
   cd ../phase3
   cp ../phase2/.env .
   docker compose up -d
   ./scripts/load_test.sh
   docker compose down -v
   ```

### Pour les étudiants

1. **Phase 1 : Découverte**
   ```bash
   cd phase1
   docker compose up -d
   # Accéder à http://localhost:8080
   # Suivre phase1/INSTRUCTIONS.md
   ```

2. **Phase 2 : Sécurisation**
   ```bash
   cd phase2
   cp .env.example .env
   # Éditer .env avec vos valeurs
   # Suivre phase2/INSTRUCTIONS.md
   docker compose up -d
   ```

3. **Phase 3 : Production**
   ```bash
   cd phase3
   cp ../phase2/.env .
   # Suivre phase3/INSTRUCTIONS.md
   docker compose up -d
   ```

## 🎓 Prérequis

### Connaissances
- Bases Docker (images, conteneurs, volumes)
- Docker Compose (services, réseaux)
- Ligne de commande Linux/Bash
- Git (clone, commit, .gitignore)

### Matériel
- Docker Desktop (Windows/Mac) ou Docker Engine (Linux)
- Minimum 4 Go de RAM disponible
- Éditeur de code (VS Code recommandé)
- Terminal bash/zsh/PowerShell

### Ports nécessaires
- **Phase 1** : 8080, 5000, 5432, 6379, 3000
- **Phase 2-3** : 8080 uniquement (configurable via .env)

## 📚 Documentation détaillée

| Document | Pour qui ? | Contenu |
|----------|-----------|---------|
| **README.md** | Tous | Vue d'ensemble et démarrage rapide |
| **SOMMAIRE.md** | Enseignant | Documentation complète du package |
| **GUIDE_ENSEIGNANT.md** | Enseignant | Plan minute par minute, astuces pédagogiques |
| **AIDE-MEMOIRE.md** | Étudiant | Référence rapide des commandes |
| **phase*/INSTRUCTIONS.md** | Étudiant | Instructions détaillées par phase |

## ✅ Validation du projet

Vérifier que tous les fichiers sont présents :
```bash
./validate_project.sh
```

## 🎯 Objectifs pédagogiques

À l'issue de cette session, les étudiants sauront :

**Sécurité :**
- Scanner des images (Docker Scout, Trivy)
- Créer des utilisateurs non-root
- Gérer les secrets sécurisément
- Isoler avec des réseaux Docker

**Production :**
- Définir des limites de ressources
- Configurer l'auto-healing
- Implémenter des health checks
- Gérer les dépendances

## 🛠️ Support

### Dépannage commun

**Port déjà utilisé :**
```bash
echo "PROXY_PORT=8081" >> .env
```

**Permission denied :**
```dockerfile
COPY --chown=user:group . /app
```

**Service unhealthy :**
```bash
docker compose logs backend
docker compose exec backend curl http://localhost:5000/health
```

### Contact

Pour questions ou améliorations :
- Consulter GUIDE_ENSEIGNANT.md
- Ouvrir une issue sur le repository
- Contacter l'auteur du cours

## 📊 Métriques de succès

| Métrique | Phase 1 | Phase 3 | Gain |
|----------|---------|---------|------|
| CVE Critical | ~50 | <5 | 90% |
| Services en root | 5/5 | 0/5 | 100% |
| Ports exposés | 5 | 1 | 80% |
| Disponibilité | N/A | >99% | Auto-healing |

## 🎉 Conclusion

Ce projet complet fournit tout le matériel pour une session de 3 heures réussie sur la sécurité et la production Docker.

**Points forts :**
- Progression pédagogique claire
- Approche pratique hands-on
- Problèmes réels de production
- Documentation exhaustive

**Prochaines étapes possibles :**
- CI/CD avec GitHub Actions
- Kubernetes / Orchestration
- Monitoring avec Prometheus
- Secrets avec Vault

---

**Bon cours ! 🚀**
