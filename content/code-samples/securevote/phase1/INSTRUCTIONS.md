# Phase 1 : Découverte - SecureVote (30 minutes)

## Objectif

Démarrer l'application SecureVote et identifier les vulnérabilités de sécurité présentes dans cette version initiale.

## Prérequis

- Docker et Docker Compose installés
- Ports 8080, 5000, 5432, 6379, 3000 disponibles

## Étape 1 : Démarrage de l'application (5 min)

1. Clonez ou téléchargez le projet SecureVote Phase 1

2. Naviguez dans le répertoire :
```bash
cd securevote/phase1
```

3. Démarrez l'application :
```bash
docker compose up -d
```

4. Vérifiez que tous les conteneurs sont démarrés :
```bash
docker compose ps
```

Vous devriez voir 5 conteneurs : database, cache, backend, frontend, proxy

5. Accédez à l'application : http://localhost:8080

## Étape 2 : Test de l'application (5 min)

1. Testez l'interface de vote
   - Votez pour différentes options
   - Observez les résultats en temps réel
   - Testez le bouton "Réinitialiser les votes"

2. Vérifiez les logs :
```bash
docker compose logs -f backend
docker compose logs -f frontend
```

3. Observez les connexions aux services :
```bash
docker compose logs database
docker compose logs cache
```

## Étape 3 : Analyse des vulnérabilités (20 min)

### 3.1 Inspection des conteneurs

Répondez aux questions suivantes :

**Question 1 : Qui exécute les processus ?**
```bash
docker compose exec backend whoami
docker compose exec frontend whoami
docker compose exec proxy whoami
```
Résultat attendu : Tous retournent `root` ❌

**Question 2 : Quels ports sont exposés ?**
```bash
docker compose ps
```
Notez tous les ports exposés sur l'hôte.

**Question 3 : Inspectez les variables d'environnement**
```bash
docker compose exec backend env | grep -E "PASSWORD|SECRET"
docker compose exec database env | grep POSTGRES
```
Que constatez-vous ? ❌

### 3.2 Analyse du fichier docker-compose.yml

Ouvrez le fichier `docker-compose.yml` et identifiez :

1. **Secrets en clair** :
   - Où sont stockés les mots de passe ?
   - Sont-ils versionnés dans Git ?

2. **Ports exposés inutilement** :
   - Le port PostgreSQL (5432) doit-il être exposé sur l'hôte ?
   - Le port Redis (6379) doit-il être exposé sur l'hôte ?

3. **Configuration manquante** :
   - Y a-t-il des limites de ressources (CPU/RAM) ?
   - Y a-t-il des politiques de redémarrage ?
   - Y a-t-il des health checks ?
   - Y a-t-il des réseaux isolés ?

### 3.3 Analyse des Dockerfiles

Examinez les Dockerfiles dans `backend/Dockerfile` et `frontend/Dockerfile` :

1. **Images de base** :
   - Quelle version de Python est utilisée ? (`python:3.11`)
   - Est-ce une image `slim` ou `alpine` ?
   - Quelle version de Node est utilisée ? (`node:20`)

2. **Utilisateurs** :
   - Un utilisateur non-root est-il créé ?
   - Quel utilisateur exécute les commandes ?

3. **Optimisations** :
   - Le cache npm/pip est-il nettoyé ?
   - L'image est-elle optimisée ?

### 3.4 Scanner les vulnérabilités

Si vous avez Docker Scout ou Trivy installé :

```bash
# Avec Docker Scout
docker scout cves securevote-backend:latest
docker scout cves securevote-frontend:latest

# Ou avec Trivy
trivy image securevote-backend:latest
trivy image securevote-frontend:latest
```

Comptez le nombre de vulnérabilités HIGH et CRITICAL.

## Étape 4 : Résumé des vulnérabilités (groupe)

En binôme ou en groupe, listez toutes les vulnérabilités identifiées :

### Vulnérabilités de sécurité :
- [ ] Tous les conteneurs s'exécutent en tant que root
- [ ] Secrets (passwords) stockés en clair dans docker-compose.yml
- [ ] Ports de base de données exposés inutilement
- [ ] Pas de mot de passe sur Redis
- [ ] Images non scannées et potentiellement vulnérables
- [ ] Flask en mode debug en production
- [ ] Pas de réseau isolé entre les services

### Problèmes de configuration production :
- [ ] Aucune limite de ressources (CPU/RAM)
- [ ] Aucune politique de redémarrage
- [ ] Aucun health check implémenté
- [ ] Logs non optimisés (pas de rotation)
- [ ] Frontend utilise le serveur de dev React (pas optimisé)

## Étape 5 : Préparation pour la Phase 2

Maintenant que vous avez identifié les problèmes, vous allez les corriger dans la Phase 2 !

Gardez ce fichier sous la main pour cocher les corrections au fur et à mesure.

## Commandes utiles

```bash
# Voir les logs en temps réel
docker compose logs -f

# Observer la consommation de ressources
docker stats

# Inspecter un conteneur
docker compose exec backend sh
docker inspect securevote-backend

# Arrêter tous les services
docker compose down

# Supprimer également les volumes
docker compose down -v
```

## Points clés à retenir

1. **Ne jamais exécuter de conteneurs en root** - Créez toujours des utilisateurs dédiés
2. **Ne jamais stocker de secrets en clair** - Utilisez .env, secrets, ou gestionnaires dédiés
3. **N'exposer que les ports nécessaires** - Les services internes n'ont pas besoin d'être exposés
4. **Toujours scanner les images** - Les vulnérabilités sont fréquentes
5. **Configurer pour la production** - Limites, restart, healthchecks sont essentiels

## Prochaine étape

➡️ Passez à la **Phase 2 : Sécurisation** pour corriger tous ces problèmes !
