# Guide Enseignant - Session Sécurité et Production Docker (3h)

## Vue d'ensemble

**Durée totale :** 3 heures
**Format :** Projet fil rouge "SecureVote"
**Public :** Étudiants ayant déjà les bases Docker et Compose
**Prérequis :** TP1-13 complétés (notamment volumes, réseaux, Compose, ELK)

## Objectifs pédagogiques

À l'issue de cette session, les étudiants seront capables de :

1. **Sécurité**
   - Scanner les images pour détecter les vulnérabilités (Docker Scout/Trivy)
   - Créer et utiliser des utilisateurs non-root dans les conteneurs
   - Gérer les secrets de manière sécurisée (.env, .gitignore)
   - Isoler les services avec des réseaux Docker

2. **Production**
   - Définir et ajuster les limites de ressources (CPU/RAM)
   - Configurer les politiques de redémarrage appropriées
   - Implémenter des health checks applicatifs
   - Gérer les dépendances et l'ordre de démarrage
   - Optimiser les logs avec rotation

3. **Pratique**
   - Transformer une application vulnérable en déploiement production-ready
   - Tester la résilience d'une application
   - Valider les configurations avec des tests de charge

## Matériel nécessaire

### Pour l'enseignant
- [ ] Slides AsciiDoc/Reveal.js (content/chapitres/securite-production.adoc)
- [ ] Projet SecureVote complet (phases 1, 2, 3)
- [ ] Docker Scout ou Trivy installé pour les démonstrations
- [ ] Accès à un registre Docker (facultatif pour bonus)

### Pour les étudiants
- [ ] Docker et Docker Compose installés
- [ ] 4 Go de RAM disponible minimum
- [ ] Éditeur de code (VS Code recommandé)
- [ ] curl, wget (outils de test)
- [ ] Git (pour cloner le projet)

### Ports nécessaires
- 8080 (proxy)
- 5000 (backend - Phase 1 uniquement)
- 5432 (database - Phase 1 uniquement)
- 6379 (cache - Phase 1 uniquement)
- 3000 (frontend - Phase 1 uniquement)

## Plan détaillé de la session

### Introduction (15 min) - 9h00-9h15

**Objectifs :**
- Présenter le projet fil rouge SecureVote
- Expliquer la progression pédagogique (3 phases)
- Motiver l'importance de la sécurité et des bonnes pratiques

**Déroulement :**
1. Slides de présentation (5 min)
2. Architecture de SecureVote (3 min)
   - Montrer le schéma : Frontend → Backend → DB/Cache
   - Expliquer le rôle de chaque service
3. Distribution du projet et vérification des prérequis (7 min)
   - Clonage du repository
   - `docker --version` et `docker compose version`
   - Ports disponibles

**Conseil :** Insister sur le fait que l'application Phase 1 est **volontairement vulnérable** à des fins pédagogiques.

---

### Phase 1 : Découverte (30 min) - 9h15-9h45

**Objectifs :**
- Les étudiants démarrent l'application "dangereuse"
- Identifient les vulnérabilités par eux-mêmes
- Comprennent les risques concrets

**Déroulement :**

**9h15-9h20 : Démarrage (5 min)**
- Démo rapide du `docker compose up -d`
- Accès à http://localhost:8080
- Test de l'application (voter, voir résultats)

**9h20-9h40 : Investigation guidée (20 min)**

Faire travailler les étudiants en binômes avec les questions :

1. **Qui exécute les processus ?** (5 min)
   ```bash
   docker compose exec backend whoami  # root !
   docker compose exec frontend whoami  # root !
   ```
   → Discussion : Pourquoi est-ce dangereux ?

2. **Quels secrets sont exposés ?** (5 min)
   ```bash
   docker compose exec backend env | grep PASSWORD
   cat docker-compose.yml | grep PASSWORD
   ```
   → Discussion : Que se passe-t-il si on commit ça dans Git ?

3. **Quels ports sont exposés ?** (5 min)
   ```bash
   docker compose ps
   psql -h localhost -U admin -d securevote  # Connexion directe !
   ```
   → Discussion : Est-ce nécessaire d'exposer PostgreSQL ?

4. **Scanner les vulnérabilités** (5 min)
   ```bash
   docker scout cves phase1-backend --only-severity critical
   ```
   → Discussion : Combien de CVE critiques ? Pourquoi ?

**9h40-9h45 : Récapitulatif collectif (5 min)**
- Tour de table : Quelles vulnérabilités avez-vous trouvées ?
- Lister au tableau les problèmes identifiés
- Transition vers Phase 2 : "Maintenant, on corrige tout ça !"

**Points d'attention enseignant :**
- Certains étudiants peuvent trouver rapidement, d'autres plus lentement → prévoir des indices
- Si scan trop long, préparer un screenshot des résultats
- Gérer le temps : ne pas s'attarder sur une vulnérabilité, on les corrigera en Phase 2

---

### Théorie : Sécurité (15 min) - 9h45-10h00

**Objectifs :**
- Expliquer les concepts de sécurité Docker
- Donner les outils et bonnes pratiques

**Déroulement :**

**9h45-9h50 : Scan de vulnérabilités (5 min)**
- Slides sur Docker Scout et Trivy
- CVE : qu'est-ce que c'est ?
- Démo rapide de scan comparatif :
  ```bash
  docker scout compare python:3.11 --to python:3.11-slim
  ```

**9h50-9h55 : Utilisateurs non-root (5 min)**
- Pourquoi root est dangereux dans un conteneur
- Principe du moindre privilège
- Exemple de Dockerfile avec USER

**9h55-10h00 : Gestion des secrets (5 min)**
- Ne JAMAIS committer de secrets
- .env + .gitignore
- Démonstration d'un leak de secrets sur GitHub (screenshot anonymisé)
- Alternatives : Docker Secrets, Vault

**Conseil :** Garder cette partie concise, les étudiants appliqueront en pratique juste après.

---

### Phase 2 : Sécurisation (1h15) - 10h00-11h15

**Objectifs :**
- Corriger toutes les vulnérabilités identifiées
- Appliquer les bonnes pratiques de sécurité

**Déroulement :**

**10h00-10h20 : Exercice 1 - Images sécurisées (20 min)**
- Les étudiants modifient les Dockerfiles
- Passage de `python:3.11` à `python:3.11-slim`
- Passage de `node:20` à `node:20-alpine`
- Build multi-stage pour le frontend
- Re-scan et comparaison

**Points de vigilance :**
- Le build peut être long (prévoir images pré-téléchargées si réseau lent)
- Expliquer le concept de multi-stage builds si nécessaire
- Aide : Montrer le Dockerfile phase2 comme référence

**10h20-10h45 : Exercice 2 - Utilisateurs non-root (25 min)**
- Modification des Dockerfiles pour créer des users
- Backend : `flaskuser`
- Frontend : `reactuser`
- Proxy : `nginxinc/nginx-unprivileged`
- Vérification avec `whoami` et `docker compose top`

**Points de vigilance :**
- Erreur courante : oublier `chown` des fichiers → permission denied
- Erreur courante : nginx standard écoute sur port 80 (privilégié) → passer à 8080
- Tester impérativement que l'application fonctionne encore

**10h45-11h15 : Exercice 3 - Secrets sécurisés (30 min)**
- Création du fichier `.env`
- Génération de secrets forts avec Python
- Modification de `docker-compose.yml` pour utiliser `${VAR}`
- Ajout de `.gitignore`
- Vérification qu'aucun secret n'est visible dans `docker compose config`

**Points de vigilance :**
- **Crucial :** Vérifier que `.env` est bien dans `.gitignore`
- Montrer un `git status` pour confirmer
- Expliquer `.env.example` pour documenter les variables nécessaires
- Test : `mv .env .env.backup && docker compose up` → doit échouer

**11h15 : Checkpoint Phase 2**
- Vérification collective : Tous les services tournent ?
- Tous les `whoami` retournent un user non-root ?
- Application accessible et fonctionnelle ?
- → Si non, aide individuelle

**Conseil :** Cette phase est la plus longue et la plus importante. Circule entre les étudiants pour aider.

---

### Pause (15 min) - 11h15-11h30

---

### Théorie : Production (15 min) - 11h30-11h45

**Objectifs :**
- Expliquer les différences Dev vs Prod
- Présenter les concepts de résilience

**Déroulement :**

**11h30-11h35 : Limites de ressources (5 min)**
- Pourquoi limiter CPU/RAM ?
- Exemple : Un conteneur qui consomme 100% CPU
- Syntaxe `deploy.resources.limits`
- Comment observer : `docker stats`

**11h35-11h40 : Politiques de redémarrage (5 min)**
- `no`, `always`, `on-failure`, `unless-stopped`
- Quand utiliser quelle politique ?
- Exemple : Backend vs Database

**11h40-11h45 : Health checks (5 min)**
- Différence entre "started" et "healthy"
- Syntaxe `healthcheck`
- Endpoint `/health` applicatif
- Démo : `depends_on` avec `condition: service_healthy`

---

### Phase 3 : Production (1h) - 11h45-12h45

**Objectifs :**
- Optimiser pour la production
- Tester la résilience

**Déroulement :**

**11h45-12h05 : Exercice 4 - Limites de ressources (20 min)**
- Observer `docker stats` à vide
- Lancer le script de test de charge `load_test.sh`
- Observer sous charge
- Définir les limites avec marge
- Re-tester

**Points de vigilance :**
- Expliquer que les valeurs dépendent du matériel
- Les limites sont des maximums, pas des allocations
- `reservations` = garanties minimum

**12h05-12h30 : Exercice 5 - Restart et Health (25 min)**
- Ajouter `restart:` à tous les services
- Créer les healthchecks dans docker-compose.yml
- Modifier `app.py` pour un `/health` fonctionnel
- Tester avec `docker compose kill backend`
- Observer le redémarrage automatique
- Lancer le script `kill_test.sh`

**Points de vigilance :**
- `start_period` crucial pour le backend (temps d'init DB)
- Le healthcheck doit tester les vraies dépendances
- Montrer `docker compose ps` : colonne "STATUS" affiche (healthy)

**12h30-12h45 : Exercice 6 - Dépendances (15 min)**
- Ajouter `depends_on` avec conditions
- Ordre : DB/Cache → Backend → Frontend → Proxy
- Tester : `docker compose down && docker compose up -d`
- Observer les logs : démarrage ordonné

**Points de vigilance :**
- Sans `condition: service_healthy`, les services démarrent sans attendre
- Montrer la différence avec/sans conditions

**Conseil :** Cette phase est dense, ajuster le timing si nécessaire. L'exercice 6 peut être raccourci.

---

### Récapitulatif et Questions (15 min) - 12h45-13h00

**Objectifs :**
- Consolider les apprentissages
- Répondre aux questions
- Donner les ressources pour aller plus loin

**Déroulement :**

**12h45-12h50 : Avant/Après (5 min)**
- Slide récapitulative des transformations
- Métriques : CVE, users, secrets, ports, résilience
- Célébration : "Votre app est production-ready !"

**12h50-12h55 : Validation finale collective (5 min)**
- Tour de table rapide : Qui a une app 100% fonctionnelle ?
- Dépannage express pour ceux en difficulté
- Partage des screenshots de `docker compose ps` (tous healthy)

**12h55-13h00 : Questions et ressources (5 min)**
- Questions ouvertes
- Ressources pour aller plus loin (Kubernetes, Vault, etc.)
- Annonce du prochain cours (CI/CD ou autre)

---

## Exercice Bonus (si temps restant)

**Registre local (20 min)**

Si la session avance bien et qu'il reste du temps :

1. Démarrer un registre local
   ```bash
   docker run -d -p 5050:5000 --name registry registry:3
   ```

2. Tagger et pousser les images
   ```bash
   docker tag phase2-backend localhost:5050/securevote-backend:1.0.0
   docker push localhost:5050/securevote-backend:1.0.0
   ```

3. Modifier `docker-compose.yml` pour utiliser le registre local

4. Supprimer les images locales et re-déployer

**Intérêt pédagogique :** Comprendre la distribution d'images

---

## Astuces et pièges courants

### Problèmes techniques prévisibles

**1. Ports déjà utilisés**
- Solution : Modifier `PROXY_PORT=8081` dans `.env`
- Vérifier : `netstat -tuln | grep 8080`

**2. Build trop lent**
- Solution : Pré-télécharger les images avant le cours
  ```bash
  docker pull python:3.11-slim
  docker pull node:20-alpine
  docker pull postgres:15-alpine
  docker pull redis:7-alpine
  docker pull nginxinc/nginx-unprivileged:alpine
  ```

**3. Permissions sur les fichiers copiés**
- Erreur : "Permission denied" après USER non-root
- Solution : Utiliser `COPY --chown=user:group`
- Ou : `RUN chown -R user:group /app`

**4. Healthcheck échoue en boucle**
- Erreur : Service reste "unhealthy"
- Solution : Vérifier le `start_period` (assez long ?)
- Debug : `docker compose logs service`
- Debug : `docker compose exec service curl http://localhost:PORT/health`

**5. Variables d'environnement non substituées**
- Erreur : `${DB_PASSWORD}` apparaît en clair
- Solution : Vérifier que le `.env` est dans le même répertoire que `docker-compose.yml`
- Debug : `docker compose config` pour voir les valeurs réelles

### Erreurs pédagogiques à éviter

**1. Aller trop vite**
- Symptôme : Les étudiants copient-collent sans comprendre
- Solution : Poser des questions, faire verbaliser ce qu'ils font
- Exemple : "Pourquoi créez-vous un utilisateur ici ?"

**2. Ne pas valider les étapes**
- Symptôme : Accumuler les erreurs, frustration en Phase 3
- Solution : Checkpoints réguliers, vérifications collectives
- Utiliser : `docker compose ps`, `whoami`, `curl`

**3. Négliger le "pourquoi"**
- Symptôme : Les étudiants appliquent sans comprendre
- Solution : Toujours expliquer le risque avant la solution
- Exemple : Montrer un exploit root avant de créer un user

**4. Timing trop serré**
- Symptôme : Stress, incompréhensions, phases inachevées
- Solution : Prévoir du slack, identifier les exercices "bonus"
- Exercice 7 (logs) peut être supprimé si besoin

---

## Variantes et adaptations

### Session plus courte (2h)

**Couper :**
- Exercice 7 (logs) → à faire en autonomie
- Partie théorie registres → mentionner uniquement
- Exercice bonus registre → supprimer

**Garder :**
- Phases 1, 2, 3 essentielles
- Focus sur sécurité (users, secrets, scans)

### Session plus longue (4h)

**Ajouter :**
- Exercice registre privé (Harbor ou AWS ECR)
- CI/CD avec GitHub Actions pour build et push automatique
- Monitoring avec Prometheus + Grafana (TP13 déjà fait ELK)
- Certificats SSL avec Let's Encrypt

### Niveau débutant

**Adaptations :**
- Phase 1 : Donner plus d'indices, investigation guidée en classe
- Phase 2 : Fournir des templates de Dockerfile à compléter
- Phase 3 : Valeurs de limites pré-calculées

### Niveau avancé

**Challenges supplémentaires :**
- Implémenter le rate limiting dans Nginx
- Ajouter un système de backup automatique de la DB
- Configurer un healthcheck avec metrics Prometheus
- Déployer sur un véritable serveur distant
- Mettre en place une authentification avec JWT

---

## Évaluation des acquis

### Grille d'évaluation (optionnel)

| Critère | Points | Validation |
|---------|--------|------------|
| **Sécurité (40 pts)** | | |
| Images scannées et optimisées | 10 | < 10 CVE critical |
| Utilisateurs non-root | 10 | Aucun process UID 0 |
| Secrets protégés | 10 | .env + .gitignore OK |
| Réseau isolé | 10 | Services cloisonnés |
| **Production (40 pts)** | | |
| Limites de ressources | 10 | Toutes définies |
| Restart policies | 10 | Appropriées |
| Health checks | 10 | Tous fonctionnels |
| Dépendances | 10 | Ordre correct |
| **Fonctionnement (20 pts)** | | |
| Application opérationnelle | 10 | Vote et résultats OK |
| Résilience | 10 | Récupération après kill |
| **Total** | **100** | |

### Questions de validation orale

1. "Pourquoi ne pas exécuter les conteneurs en root ?"
2. "Quelle est la différence entre `on-failure` et `unless-stopped` ?"
3. "Que vérifie votre health check backend ?"
4. "Pourquoi limiter les ressources d'un conteneur ?"
5. "Comment avez-vous protégé vos secrets ?"

---

## Ressources complémentaires

### Pour les étudiants

**Documentation officielle :**
- https://docs.docker.com/engine/security/
- https://docs.docker.com/compose/compose-file/deploy/

**Outils de scan :**
- Docker Scout : https://docs.docker.com/scout/
- Trivy : https://github.com/aquasecurity/trivy
- Snyk : https://snyk.io/

**Bonnes pratiques :**
- CIS Docker Benchmark : https://www.cisecurity.org/benchmark/docker
- OWASP Docker Security Cheat Sheet

### Pour l'enseignant

**Veille :**
- DockerCon talks sur YouTube
- Docker Blog : https://www.docker.com/blog/
- CNCF Security papers

**Exemples réels :**
- https://github.com/docker/awesome-compose (exemples production)
- https://github.com/jenkinsci (Jenkins utilise extensively Docker)

---

## Checklist préparation cours

### Semaine avant

- [ ] Tester le projet SecureVote sur sa machine
- [ ] Vérifier que tous les fichiers sont présents (phases 1, 2, 3)
- [ ] Préparer les slides (build `make serve`)
- [ ] Créer un repository Git avec le projet
- [ ] Préparer les screenshots de résultats de scans

### Jour avant

- [ ] Télécharger toutes les images Docker
- [ ] Tester sur le réseau de l'école (parfois restrictions)
- [ ] Imprimer le planning détaillé
- [ ] Préparer les checkpoints de validation
- [ ] Vérifier matériel : projecteur, accès internet

### Jour J (30 min avant)

- [ ] Démarrer les slides
- [ ] Tester un `docker compose up` rapide
- [ ] Vérifier les ports disponibles
- [ ] Préparer le tableau (liste des vulnérabilités à remplir)
- [ ] URL du projet accessible (GitHub/GitLab)

---

## Retours d'expérience et amélioration continue

Après la session, prendre notes de :

**Points positifs :**
- Quels exercices ont bien fonctionné ?
- Quels moments ont suscité l'intérêt ?
- Quelles questions pertinentes des étudiants ?

**Points à améliorer :**
- Quels exercices ont pris trop de temps ?
- Où les étudiants ont-ils bloqué ?
- Quelles explications à clarifier ?

**Retours étudiants :**
- Sondage anonyme post-session
- Questions : Rythme ? Clarté ? Utilité ?
- Ajustements pour la prochaine session

---

## Conclusion

Ce guide vous donne toutes les clés pour une session réussie. N'hésitez pas à l'adapter à votre contexte et à vos étudiants.

**L'essentiel :**
- 🎯 Approche pratique progressive
- 🔒 Sécurité avant tout
- 🚀 Production-ready comme objectif
- 🤝 Accompagnement bienveillant

Bon cours ! 🎓
