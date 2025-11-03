# Configuration GitHub pour SecureVote

## Dependabot

Dependabot est configuré pour maintenir automatiquement les dépendances à jour.

### Ce qui est surveillé

- **Python (pip)** : `requirements.txt` dans **phase2 et phase3** uniquement
- **Node.js (npm)** : `package.json` dans **phase2 et phase3** uniquement
- **Docker** : Images de base dans **phase2 et phase3** uniquement
- **GitHub Actions** : Workflows (si ajoutés ultérieurement)

### ⚠️ Phase1 intentionnellement EXCLUE

**Phase1 n'est PAS surveillée par Dependabot** - c'est volontaire !

**Raison :** Phase1 doit rester vulnérable pour l'enseignement :
- Les étudiants doivent voir les **150+ CVE** dans les scans
- La différence entre phase1 et phase2 doit être **spectaculaire**
- Phase1 démontre ce qu'il **ne faut pas faire**

Si Dependabot mettait à jour phase1, elle ne serait plus vulnérable et perdrait sa valeur pédagogique.

### Fréquence

- **Tous les lundis à 9h00** (heure UTC)
- Maximum 5-10 PRs ouvertes simultanément par écosystème

### Labels automatiques

- `dependencies` : Toutes les mises à jour de dépendances
- `python` / `javascript` / `docker` : Type de dépendance
- `security` : Mises à jour de sécurité

### Format des commits

```
chore(deps): update python:3.11-slim docker tag to v3.11.8
```

## Pourquoi c'est important ?

Ce projet est utilisé comme **exemple pédagogique** pour enseigner la sécurité Docker. Il est crucial que :

1. Les images de base restent à jour (nouvelles versions de Python, Node, etc.)
2. Les CVE soient corrigées rapidement
3. Les étudiants voient un exemple de **maintenance proactive**

Dependabot crée automatiquement des PRs quand :
- Une nouvelle version de Python/Node/PostgreSQL/Redis/Nginx est disponible
- Une dépendance npm ou pip a une mise à jour
- Une faille de sécurité est détectée

## Valeur pédagogique

Les étudiants peuvent :
- Observer les PRs Dependabot dans l'onglet "Pull Requests"
- Voir comment les versions sont mises à jour
- Comprendre l'importance de la maintenance continue
- Apprendre à configurer Dependabot pour leurs propres projets

## Configuration

Voir `dependabot.yml` dans ce répertoire pour la configuration complète.
