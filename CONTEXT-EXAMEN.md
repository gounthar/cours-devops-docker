# Contexte : Création de l'énoncé de l'examen final

## Date de création
16 octobre 2025

## Objectif
Refonte ambitieuse de l'énoncé de l'examen final du module Docker DevOps M2 ILI (année 2024-2025).

## Décisions principales

### 1. Barème - Structure finale (année 2025-2026)

**Évolution** : Structure 10+10 avec système de compléments valorisés (non plus "bonus").

**Solution retenue** :
- **Partie 1 (Bruno Verachten - Infrastructure)** : notée sur 10 points
  - Critères principaux : 10 points
  - Compléments valorisés : permettent de compenser et atteindre 10/10
  - Note Partie 1 = min(10, Critères + Compléments)

- **Partie 2 (Daniel Le Berre - CI/CD)** : notée sur 10 points
  - Obligatoire : 10 points
  - Bonus Release-Tag : bonus additionnel

**Note finale** : Partie 1 + Partie 2 = /20

**Justification** :
- Terminologie honnête : "compléments valorisés" pas "bonus obligatoires"
- Les compléments servent à compenser les points manquants pour atteindre 10/10
- Encourage les approfondissements techniques
- Structure simple : addition directe pour note finale
- Alignement avec proposition de Daniel Le Berre

### 2. Structure des slides

**Problématique** : Slides trop denses, illisibles

**Solution** : Découpage maximal = 1 idée par slide

**Résultat** :
- **102 slides au total** (contre 44 dans la v1, et ~5 dans l'original)
- 13 sections principales (horizontales)
- 89 sous-sections (verticales)

### 3. Compléments valorisés (Partie 1)

**7 compléments au choix** (au lieu de 3 dans l'original) :

| Complément | Points | Description |
|-------|--------|-------------|
| Observabilité (Prometheus + Grafana) | +1 pt | Métriques système + applicatives, dashboards, alertes |
| Pipeline de validation (Goss) | +1 pt | Tests automatiques du docker-compose |
| Gestion auto dépendances (Updatecli/Renovate/Dependabot) | +0.75 pt | PRs automatiques de mise à jour |
| Performance & Load Testing (k6/Gatling) | +1 pt | Tests de charge + optimisations prouvées |
| Haute disponibilité | +1 pt | Multi-instances + load balancing + zero-downtime |
| Multi-environnements | +0.75 pt | Dev/Staging/Prod avec overrides |
| Forge GitLab auto-hébergée | +1.5 pts | GitLab CE en Docker Compose + maintenu à jour |

**Rôle** : Compenser les points manquants et atteindre 10/10 (Note = min(10, Critères + Compléments))

### 4. Critères d'évaluation Partie 1

**Critères principaux (10 points)** :

| Critère | Points | Focus |
|---------|--------|-------|
| Architecture fonctionnelle | 3 pts | Stack complète fonctionnelle et accessible |
| Qualité technique | 3 pts | Multi-stage builds, health checks, resources, sécurité |
| Documentation | 2 pts | README complet avec schéma et justifications |
| Bonnes pratiques | 2 pts | Images optimisées, logs structurés, secrets gérés |

**Exigences détaillées** :

1. **Architecture multi-tiers** : Reverse-proxy + App Server + Database + ELK
2. **Docker Compose** : Fichier structuré, .env, networks, volumes nommés
3. **Images optimisées** : Multi-stage builds, < 500MB app, < 200MB services, .dockerignore, pas de secrets
4. **Health checks** : Sur tous les services, restart policies, depends_on avec conditions
5. **Resource management** : Limites CPU/RAM sur chaque service
6. **Logging structuré** : JSON → Logstash → Kibana
7. **Sécurité** : Pas de root, secrets gérés, Trivy scanning
8. **Documentation** : README avec architecture, prérequis, config, utilisation, troubleshooting

## Fichiers créés

### 1. Contenu AsciiDoc
- **Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/content/chapitres/examen-final.adoc`
- **Lignes** : 815
- **Format** : AsciiDoc pour Reveal.js
- **Encodage** : UTF-8 avec ligne vide finale

### 2. Fichier de test standalone
- **Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/content/index-examen.adoc`
- **Usage** : Tester le rendu indépendamment du cours principal
- **Build** : `SOURCE_FILE=index-examen.adoc make build`

### 3. Schémas

#### Architecture cible
- **Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/content/media/exam-architecture-diagram.png`
- **Format** : PNG (2075x267px)
- **Générateur** : Graphviz DOT
- **Contenu** : Client → Reverse Proxy → App Server → Database + ELK Stack (avec flux logs)

#### Git-flow
- **Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/content/media/gitflow-diagram.png`
- **Format** : PNG (303x1091px)
- **Générateur** : Graphviz DOT
- **Contenu** : Branches main/develop/feature/release/hotfix avec légende

### 4. Slides HTML générés
- **Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/dist/index-examen.html`
- **Taille** : 73 KB
- **Framework** : Reveal.js
- **Slides** : 102 au total

## Modifications du build system

### 1. Gulpfile.js
**Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/gulp/gulpfile.js`

**Modification** : Ajout du support de SOURCE_FILE

```javascript
function html(cb) {
    const sourceFile = process.env.SOURCE_FILE || 'index.adoc';
    asciidoctor.convertFile(
        current_config.sourcesDir + '/' + sourceFile,
        // ...
    );
    cb();
}
```

**Usage** : Permet de générer d'autres fichiers que index.adoc

### 2. Docker Compose
**Fichier** : `/mnt/c/support/users/fac/cours-devops-docker/docker-compose.yml`

**Modification** : Ajout de la variable SOURCE_FILE dans l'environnement

```yaml
x-slides-base: &slides-base
  environment:
    - PRESENTATION_URL=${PRESENTATION_URL}
    - REPOSITORY_URL=${REPOSITORY_URL}
    - SOURCE_FILE=${SOURCE_FILE}  # <-- Ajouté
```

## Commandes utiles

### Build des slides d'examen
```bash
SOURCE_FILE=index-examen.adoc make build
```

### Visualiser les slides
```bash
cd dist
python3 -m http.server 8080
# Ouvrir http://localhost:8080/index-examen.html
```

### Navigation Reveal.js
- **Flèches gauche/droite** : Sections principales (horizontales)
- **Flèches haut/bas** : Sous-sections (verticales)
- **Touche 'o'** : Vue d'ensemble (Overview)
- **Touche 'Esc'** : Sortir du mode overview

## Philosophie pédagogique

### Objectifs
1. **Préparer** les étudiants à l'entreprise (pas les piéger)
2. **Valoriser** l'excellence via les bonus
3. **Encourager** la qualité plutôt que la quantité
4. **Développer** des compétences modernes et recherchées

### Messages clés
- "Qualité > Quantité" pour les bonus
- "Demander de l'aide n'est pas une faiblesse"
- "IA pour apprendre, pas pour éviter de réfléchir"
- Documentation au fur et à mesure, pas à la fin

## Warnings et conseils

### Erreurs courantes mises en avant
- ❌ Secrets dans Git (.env committé)
- ❌ Images Docker trop grosses
- ❌ Pas de health checks
- ❌ Volumes anonymes → perte de données
- ❌ Tout en root
- ❌ Documentation absente

### Ressources fournies
- Documentation officielle Docker
- Docker Compose samples (awesome-compose)
- GitLab CI/CD docs
- Le cours lui-même
- IA (avec warnings sur le plagiat)

## Prochaines étapes

### À faire
- [ ] Créer le fichier PowerPoint (projet_devops_m2_ili_2024-2025.pptx)
- [ ] Valider avec l'enseignant
- [ ] Tester avec les étudiants (feedback)
- [ ] Ajuster si nécessaire

### À ne pas oublier
- Les schémas sont auto-générés (ne pas les éditer manuellement)
- Le fichier index-examen.adoc est pour les tests (ne pas intégrer à index.adoc)
- Les modifications du build system (gulpfile.js, docker-compose.yml) sont à conserver

## Notes techniques

### Warnings AsciiDoc résolus
- ✅ Numérotation des listes : Les "Exigences qualité" ont été renumérotées de 1 à 5 (au lieu de 4 à 8)
- ✅ Aucun warning lors du build final

### Performance
- Build time : ~5-7 secondes
- HTML généré : 73 KB (acceptable)
- Aucune image manquante

## Contact et responsabilités

### Partie 1 - Infrastructure (Bruno Verachten)
- Architecture Docker
- Compose
- Images
- Health checks
- Sécurité
- Logging
- Bonus

### Partie 2 - CI/CD (Daniel Le Berre)
- Pipelines GitLab CI
- Git-flow
- Tests
- SonarQube
- Artefacts

### Coordination
- Farid Ait-Kara (3e enseignant)

## Historique des versions

### v1.0 - 16 octobre 2025
- Création initiale avec 44 slides
- Problème : slides trop denses
- Problème : barème confus (10 pts vs 20 pts)

### v2.0 - 16 octobre 2025
- 102 slides (1 idée = 1 slide)
- Barème clarifié : Partie 1 sur 20 (16 oblig + 4 bonus)
- 7 bonus proposés au lieu de 3
- Schémas créés
- Build system adapté
- Contexte sauvegardé dans ce fichier

### v3.0 - 8 décembre 2025 (finale année 2025-2026)
- **Alignement avec Partie 2** : Structure 10+10
- Partie 1 : 10 pts critères principaux + compléments valorisés (plafond 10)
- Partie 2 : 10 pts (proposition de Daniel Le Berre v4)
- Changement terminologique : "compléments valorisés" au lieu de "bonus"
- Les compléments servent à compenser et atteindre 10/10
- Note finale : addition simple (Partie 1 + Partie 2 = /20)

---

**Dernière mise à jour** : 8 décembre 2025
**Auteur** : Claude (avec Bruno Verachten)
**Projet** : Cours DevOps Docker M2 ILI
