# Projet SecureVote - Cours Sécurité et Production Docker (3h)

## 📋 Résumé exécutif

Ce package complet fournit tout le matériel nécessaire pour animer une session de 3 heures sur la sécurité et la production Docker, basée sur un projet fil rouge appelé **SecureVote**.

**Concept :** Les étudiants transforment progressivement une application de vote vulnérable en déploiement production-ready et sécurisé.

---

## 📦 Contenu du package

```
securevote/
├── README.md                    # Vue d'ensemble du projet
├── SOMMAIRE.md                  # Ce fichier
├── GUIDE_ENSEIGNANT.md          # Guide détaillé pour l'enseignant (IMPORTANT)
│
├── phase1/                      # Version initiale (vulnérable)
│   ├── INSTRUCTIONS.md          # Instructions pour les étudiants
│   ├── docker-compose.yml       # Avec vulnérabilités volontaires
│   ├── backend/
│   │   ├── Dockerfile           # Image complète, root
│   │   ├── app.py               # API Flask
│   │   └── requirements.txt
│   ├── frontend/
│   │   ├── Dockerfile           # Image complète, root
│   │   ├── src/App.js           # Interface React
│   │   └── package.json
│   └── proxy/
│       └── nginx.conf
│
├── phase2/                      # Version sécurisée
│   ├── INSTRUCTIONS.md          # Instructions de sécurisation
│   ├── docker-compose.yml       # Sécurisé
│   ├── .env.example             # Template de variables
│   ├── .gitignore               # Protection des secrets
│   ├── backend/
│   │   ├── Dockerfile           # Image slim, utilisateur non-root
│   │   └── app.py               # Health check fonctionnel
│   ├── frontend/
│   │   └── Dockerfile           # Multi-stage, alpine, non-root
│   └── proxy/
│       └── nginx.conf           # nginx-unprivileged, headers sécurité
│
├── phase3/                      # Version production
│   ├── INSTRUCTIONS.md          # Instructions d'optimisation
│   ├── docker-compose.yml       # Limites, restart, healthchecks
│   └── scripts/
│       ├── load_test.sh         # Test de charge
│       └── kill_test.sh         # Test de résilience
│
└── solutions/                   # (À créer si besoin)
    └── [Copies des phases complètes]
```

---

## 🎯 Objectifs pédagogiques

### Compétences techniques

Les étudiants apprendront à :

**Sécurité :**
- ✅ Scanner des images Docker avec Docker Scout ou Trivy
- ✅ Créer des utilisateurs non-root dans les conteneurs
- ✅ Gérer les secrets avec .env et .gitignore
- ✅ Isoler les services avec des réseaux Docker
- ✅ Réduire la surface d'attaque (images slim/alpine)

**Production :**
- ✅ Définir des limites de ressources (CPU/RAM)
- ✅ Configurer des politiques de redémarrage
- ✅ Implémenter des health checks applicatifs
- ✅ Gérer les dépendances entre services
- ✅ Optimiser les logs avec rotation

### Compétences transversales

- Analyse de vulnérabilités
- Démarche progressive d'amélioration
- Tests de résilience
- Documentation de configuration

---

## ⏱️ Planning de la session (3h)

| Horaire | Phase | Durée | Contenu |
|---------|-------|-------|---------|
| 9h00 | Intro | 15 min | Présentation du projet |
| 9h15 | Phase 1 | 30 min | Découverte et identification des vulnérabilités |
| 9h45 | Théorie | 15 min | Concepts de sécurité Docker |
| 10h00 | Phase 2 | 1h15 | Sécurisation (images, users, secrets) |
| 11h15 | Pause | 15 min | ☕ |
| 11h30 | Théorie | 15 min | Concepts de production |
| 11h45 | Phase 3 | 1h00 | Production (limites, restart, healthchecks) |
| 12h45 | Récap | 15 min | Questions, validation finale |

---

## 🚀 Démarrage rapide pour l'enseignant

### 1. Prérequis à installer

Sur votre machine de démonstration :
```bash
# Vérifier Docker
docker --version  # >= 24.0
docker compose version  # >= 2.20

# Installer un scanner (au choix)
# Docker Scout (inclus dans Docker Desktop)
docker scout --help

# Ou Trivy
brew install trivy  # macOS
# apt-get install trivy  # Linux
```

### 2. Télécharger les images (avant le cours)

```bash
# Économiser du temps pendant le cours
docker pull python:3.11
docker pull python:3.11-slim
docker pull node:20
docker pull node:20-alpine
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull nginxinc/nginx-unprivileged:alpine
```

### 3. Tester le projet

```bash
# Phase 1 (vulnérable)
cd phase1
docker compose up -d
# Vérifier : http://localhost:8080
docker compose down -v

# Phase 2 (sécurisé)
cd ../phase2
cp .env.example .env
# Éditer .env avec des valeurs de test
docker compose up -d
docker compose ps  # Vérifier que tout tourne
docker compose down -v

# Phase 3 (production)
cd ../phase3
cp ../phase2/.env .
docker compose up -d
docker compose ps  # Vérifier (healthy)
./scripts/load_test.sh
docker compose down -v
```

### 4. Préparer les slides

Les slides sont dans :
```
/mnt/c/support/users/fac/cours-devops-docker/content/chapitres/securite-production.adoc
```

Pour les générer :
```bash
cd /mnt/c/support/users/fac/cours-devops-docker
make serve
# Ouvrir http://localhost:8000
```

---

## 📚 Documents essentiels

### Pour vous (enseignant)

1. **GUIDE_ENSEIGNANT.md** (⭐ LE PLUS IMPORTANT)
   - Plan minute par minute
   - Pièges courants et solutions
   - Conseils pédagogiques
   - Scripts de dépannage

2. **Slides AsciiDoc**
   - Théorie sécurité et production
   - Exemples de code
   - Slides de récapitulatif

### Pour les étudiants

1. **Phase 1/INSTRUCTIONS.md**
   - Guide de découverte
   - Questions d'investigation
   - Commandes de validation

2. **Phase 2/INSTRUCTIONS.md**
   - Exercices de sécurisation
   - Étapes détaillées
   - Points de validation

3. **Phase 3/INSTRUCTIONS.md**
   - Exercices de production
   - Tests de charge et résilience
   - Checklist finale

---

## 🎓 Prérequis étudiants

### Connaissances requises

Les étudiants doivent avoir déjà vu :
- ✅ Bases Docker (images, conteneurs, volumes)
- ✅ Docker Compose (services, réseaux, dépendances)
- ✅ Ligne de commande Linux/Bash
- ✅ Git (clone, commit, .gitignore)

Idéalement, avoir fait les TP 1-13 du cours (notamment Compose et ELK).

### Matériel étudiant

Chaque étudiant doit avoir :
- Ordinateur avec Docker Desktop installé (Windows/Mac) ou Docker Engine (Linux)
- Minimum 4 Go de RAM disponible
- Éditeur de code (VS Code recommandé)
- Accès internet (pour pull images)
- Terminal (bash/zsh/PowerShell)

### Vérification pré-session

Envoyer ce script de test 1 jour avant :
```bash
#!/bin/bash
echo "🔍 Vérification des prérequis SecureVote"

# Docker
docker --version || echo "❌ Docker non installé"
docker compose version || echo "❌ Docker Compose non installé"

# Ports
for port in 8080 5000 5432 6379 3000; do
  if lsof -i:$port > /dev/null 2>&1; then
    echo "⚠️  Port $port déjà utilisé"
  fi
done

# RAM
free -m | awk 'NR==2{printf "💾 RAM disponible: %s Mo\n", $7}'

# Test rapide
docker run hello-world && echo "✅ Docker fonctionne"
```

---

## 💡 Points clés du cours

### Messages essentiels

1. **Sécurité = Principe du moindre privilège**
   - Ne jamais exécuter en root
   - N'exposer que les ports nécessaires
   - Isoler avec des réseaux

2. **Secrets ≠ Code versionné**
   - .env pour les secrets
   - .gitignore pour la protection
   - .env.example pour la documentation

3. **Images légères = Moins de vulnérabilités**
   - slim/alpine réduisent de 90-95% les CVE
   - Scanner régulièrement
   - Multi-stage builds pour optimiser

4. **Production = Résilience**
   - Health checks pour détecter les problèmes
   - Restart policies pour auto-guérir
   - Limites pour protéger le système

### Démonstrations marquantes

**Démo 1 : Impact du scan**
```bash
# Montrer la différence
docker scout cves python:3.11 --only-severity critical
# ~50 CVE critical

docker scout cves python:3.11-slim --only-severity critical
# ~2 CVE critical
```

**Démo 2 : Danger du root**
```bash
# En tant que root, on peut tout casser
docker exec securevote-backend rm -rf /etc
# 💥 Conteneur détruit

# En tant que user, protégé
docker exec securevote-backend rm -rf /etc
# Permission denied ✅
```

**Démo 3 : Auto-healing**
```bash
# Tuer un service
docker compose kill backend

# Observer la récupération automatique
watch -n 1 docker compose ps
# Redémarre et redevient healthy en ~30s
```

---

## 🔧 Dépannage rapide

### Problème : "Port already in use"

**Solution :**
```bash
# Changer le port dans .env
echo "PROXY_PORT=8081" >> .env
```

### Problème : "Permission denied" après USER non-root

**Cause :** Fichiers non accessibles par l'utilisateur

**Solution :**
```dockerfile
# Utiliser chown
COPY --chown=user:group . /app
# Ou
RUN chown -R user:group /app
```

### Problème : Healthcheck toujours "unhealthy"

**Debug :**
```bash
# Voir les logs
docker compose logs backend

# Tester manuellement
docker compose exec backend curl http://localhost:5000/health

# Augmenter start_period si init longue
healthcheck:
  start_period: 60s  # Au lieu de 40s
```

### Problème : Variables .env non lues

**Solution :**
```bash
# Vérifier que .env est dans le bon dossier
ls -la .env
# Doit être à côté de docker-compose.yml

# Vérifier le contenu
cat .env

# Vérifier la substitution
docker compose config | grep PASSWORD
```

---

## 📊 Évaluation et suivi

### Checkpoints de validation

**Fin Phase 1 :**
- [ ] Tous les étudiants ont démarré l'application
- [ ] Au moins 5 vulnérabilités identifiées par binôme

**Fin Phase 2 :**
- [ ] Images scannées avec <10 CVE critical
- [ ] `whoami` retourne un user non-root partout
- [ ] `.env` présent et `.gitignore` configuré
- [ ] Application fonctionnelle sur http://localhost:8080

**Fin Phase 3 :**
- [ ] Tous les services sont (healthy)
- [ ] Test de charge réussi sans dépassement de limites
- [ ] Test de kill avec récupération automatique
- [ ] Application stable et performante

### Grille d'évaluation (optionnel)

Si vous voulez noter la session :

| Critère | Points |
|---------|--------|
| Sécurité (images, users, secrets, réseau) | 40 |
| Production (limites, restart, health) | 40 |
| Fonctionnement et tests | 20 |
| **TOTAL** | 100 |

Détails dans GUIDE_ENSEIGNANT.md

---

## 🎯 Après le cours

### Ressources à partager

Envoyer aux étudiants :
- Lien vers le repository complet
- Documentation officielle Docker Security
- CIS Docker Benchmark
- Tutoriels Trivy/Docker Scout

### Exercices complémentaires (optionnel)

Pour approfondir :
1. Ajouter SSL/TLS avec Let's Encrypt
2. Mettre en place un registre privé (Harbor)
3. Intégrer dans un pipeline CI/CD
4. Déployer sur un serveur distant
5. Ajouter Prometheus + Grafana

### Retour d'expérience

Demander un feedback anonyme :
- Le rythme était-il approprié ?
- Les explications étaient-elles claires ?
- Qu'avez-vous le plus apprécié ?
- Que faudrait-il améliorer ?

---

## 📞 Support et contact

### Pendant le cours

**Si bloqué techniquement :**
1. Vérifier les logs : `docker compose logs`
2. Consulter le GUIDE_ENSEIGNANT.md (section Dépannage)
3. Proposer de passer à la phase suivante et revenir plus tard
4. En dernier recours : fournir les fichiers de la phase suivante

**Si en retard sur le timing :**
- Phase 1 peut être raccourcie (montrer directement les vulnérabilités)
- Phase 3, exercice 7 (logs) peut être supprimé
- Exercice bonus (registre) peut être supprimé

### Après le cours

Pour questions ou améliorations de ce cours :
- Ouvrir une issue sur le repository GitHub du cours
- Contacter l'auteur du cours

---

## ✅ Checklist finale avant le cours

### J-7
- [ ] Testé les 3 phases sur ma machine
- [ ] Images Docker téléchargées
- [ ] Slides générées et vérifiées
- [ ] Repository Git créé et accessible
- [ ] Planning imprimé

### J-1
- [ ] Testé sur le réseau de l'école
- [ ] Vérifications techniques (projecteur, WiFi)
- [ ] .env d'exemple prêts
- [ ] Screenshots de scans préparés
- [ ] Liste d'étudiants récupérée

### Jour J (-30 min)
- [ ] Slides ouvertes (http://localhost:8000)
- [ ] Test rapide `docker compose up`
- [ ] Ports vérifiés disponibles
- [ ] Tableau préparé (liste vulnérabilités)
- [ ] URL du projet accessible

---

## 🎉 Conclusion

Ce package complet vous donne tous les outils pour une session réussie. Le projet SecureVote est conçu pour être :

- **Pédagogique** : Progression claire et logique
- **Pratique** : Les étudiants mettent les mains dans le code
- **Réaliste** : Basé sur des problèmes réels de production
- **Complet** : De la vulnérabilité à la production

**N'oubliez pas :**
- 📖 Lire le GUIDE_ENSEIGNANT.md en détail
- ⏱️ Respecter les checkpoints pour rester dans le timing
- 🤝 Être disponible pour aider (circuler entre les étudiants)
- 🎯 L'objectif est l'apprentissage, pas la perfection

**Bon courage et bon cours ! 🚀**

Si vous avez des questions ou suggestions d'amélioration, n'hésitez pas à contribuer au projet.
