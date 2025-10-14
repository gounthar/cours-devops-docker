# Images nécessaires pour la section GitHub Codespaces

Ce document liste les images (screenshots) qui doivent être ajoutées au répertoire `content/media/` pour compléter la section GitHub Codespaces.

## Images à créer

### 1. `codespaces-interface-placeholder.png`
**Slide concerné :** "Interface Codespaces 💻"
**Description :** Screenshot de l'interface GitHub Codespaces montrant :
- La barre latérale gauche (explorateur de fichiers)
- L'éditeur central avec un fichier ouvert
- Le terminal en bas avec quelques commandes Docker
- Les différentes sections bien visibles

**Spécifications :**
- Résolution recommandée : 1280x720 ou plus
- Format : PNG
- Annotations : Optionnellement annoter les 3 zones principales (gauche, centre, bas)
- Contenu terminal : Quelques commandes basiques visibles (`whoami`, `docker --version`)

**Comment créer :**
1. Créer un Codespace sur n'importe quel dépôt
2. Ouvrir quelques fichiers pour montrer l'explorateur
3. Exécuter `whoami` et `docker --version` dans le terminal
4. Prendre une capture d'écran plein écran
5. Optionnel : Annoter avec des flèches/labels pour "Explorateur", "Éditeur", "Terminal"

### 2. (Optionnel) `codespaces-create-button.png`
**Slide concerné :** "Démarrer avec Codespaces 🚀"
**Description :** Screenshot montrant le bouton "Code" vert sur GitHub avec l'onglet Codespaces ouvert
**Utilité :** Aide visuelle pour guider les étudiants

**Spécifications :**
- Crop serré sur le dropdown "Code"
- Montrer l'onglet "Codespaces" sélectionné
- Bouton "Create codespace on main" bien visible

### 3. (Optionnel) `codespaces-terminal-output.png`
**Slide concerné :** "Terminal Codespaces 🖥️"
**Description :** Screenshot du terminal montrant les 3 commandes de vérification avec leur sortie
**Utilité :** Montrer exactement ce que les étudiants doivent voir

**Commandes à capturer :**
```bash
$ whoami
codespace
$ docker --version
Docker version 24.0.7, build afdd53b
$ docker run hello-world
[... sortie complète du hello-world ...]
```

### 4. (Optionnel) `codespaces-billing-page.png`
**Slide concerné :** "Gestion de votre Codespace 🔧"
**Description :** Screenshot de la page GitHub Settings > Billing montrant l'utilisation Codespaces
**Utilité :** Montrer où surveiller son quota

**Spécifications :**
- Anonymiser les données personnelles
- Montrer la section "Codespaces" avec le graphique d'utilisation
- Montrer le compteur "X hours used of 60 hours free"

## Images existantes réutilisables (si disponibles)

Vérifier si ces images existent déjà dans `content/media/` :
- [ ] Screenshot VSCode générique (peut servir pour l'interface)
- [ ] Logo GitHub (pour décoration)
- [ ] Logo Docker (pour décoration)

## Priorités

### Haute priorité (essentiel)
- ✅ `codespaces-interface-placeholder.png` - Déjà référencé dans le code

### Moyenne priorité (améliore la compréhension)
- `codespaces-create-button.png`
- `codespaces-terminal-output.png`

### Basse priorité (nice to have)
- `codespaces-billing-page.png`

## Notes techniques

- **Format :** Privilégier PNG pour les screenshots (compression lossless)
- **Résolution :** Minimum 1280x720, idéalement 1920x1080 ou plus
- **Poids :** Optimiser pour le web (<500KB par image si possible)
- **Localisation :** Interface en anglais (GitHub Codespaces n'est pas traduit en français)
- **Thème :** Peu importe (dark ou light), mais cohérent dans toutes les images

## Outils recommandés pour créer les screenshots

- **Windows :** Snipping Tool, Windows+Shift+S
- **macOS :** Cmd+Shift+4
- **Linux :** gnome-screenshot, flameshot
- **Annotation :**
  - Windows : Paint, Greenshot
  - macOS : Preview, Skitch
  - Linux : GIMP, Pinta
  - Web : Excalidraw, draw.io

## Prochaines étapes

1. [ ] Créer un Codespace de test pour les screenshots
2. [ ] Prendre les screenshots avec les bonnes dimensions
3. [ ] Annoter si nécessaire (flèches, labels)
4. [ ] Optimiser les images (compression)
5. [ ] Ajouter dans `content/media/`
6. [ ] Tester le rendu avec `make serve`
7. [ ] Mettre à jour ce fichier une fois terminé

## Alternative temporaire

En attendant les vraies images, le placeholder actuel (`codespaces-interface-placeholder.png`) peut être :
- Un simple rectangle avec du texte indiquant "Interface GitHub Codespaces - Image à venir"
- Créé avec ImageMagick : `convert -size 1280x720 xc:lightgray -pointsize 40 -draw "text 400,360 'GitHub Codespaces Interface'" codespaces-interface-placeholder.png`
- Ou simplement laissé manquant (AsciiDoc affichera juste le texte alt)
