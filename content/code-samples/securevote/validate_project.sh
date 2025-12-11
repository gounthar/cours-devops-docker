#!/bin/bash

# Script de validation du projet SecureVote
# Vérifie que tous les fichiers nécessaires sont présents

set -e

echo "🔍 Validation du projet SecureVote"
echo "===================================="
echo ""

ERRORS=0
WARNINGS=0

check_file() {
    local file=$1
    local required=${2:-true}

    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        if [ "$required" = "true" ]; then
            echo "❌ MANQUANT: $file"
            ((ERRORS++))
        else
            echo "⚠️  OPTIONNEL: $file"
            ((WARNINGS++))
        fi
    fi
}

check_dir() {
    local dir=$1

    if [ -d "$dir" ]; then
        echo "✅ $dir/"
    else
        echo "❌ MANQUANT: $dir/"
        ((ERRORS++))
    fi
}

echo "📚 Documentation"
echo "----------------"
check_file "README.md"
check_file "SOMMAIRE.md"
check_file "GUIDE_ENSEIGNANT.md"
check_file "AIDE-MEMOIRE.md"
echo ""

echo "📁 Phase 1 - Découverte"
echo "------------------------"
check_dir "phase1"
check_file "phase1/INSTRUCTIONS.md"
check_file "phase1/docker-compose.yml"
check_file "phase1/backend/Dockerfile"
check_file "phase1/backend/app.py"
check_file "phase1/backend/requirements.txt"
check_file "phase1/frontend/Dockerfile"
check_file "phase1/frontend/package.json"
check_file "phase1/frontend/src/App.js"
check_file "phase1/frontend/src/App.css"
check_file "phase1/frontend/src/index.js"
check_file "phase1/frontend/src/index.css"
check_file "phase1/frontend/public/index.html"
check_file "phase1/proxy/nginx.conf"
echo ""

echo "📁 Phase 2 - Sécurisation"
echo "-------------------------"
check_dir "phase2"
check_file "phase2/INSTRUCTIONS.md"
check_file "phase2/docker-compose.yml"
check_file "phase2/.env.example"
check_file "phase2/.gitignore"
check_file "phase2/backend/Dockerfile"
check_file "phase2/backend/app.py"
check_file "phase2/backend/requirements.txt"
check_file "phase2/frontend/Dockerfile"
check_file "phase2/frontend/package.json"
check_file "phase2/frontend/src/App.js"
check_file "phase2/frontend/src/App.css"
check_file "phase2/frontend/src/index.js"
check_file "phase2/frontend/src/index.css"
check_file "phase2/frontend/public/index.html"
check_file "phase2/proxy/nginx.conf"
echo ""

echo "📁 Phase 3 - Production"
echo "-----------------------"
check_dir "phase3"
check_file "phase3/INSTRUCTIONS.md"
check_file "phase3/docker-compose.yml"
check_file "phase3/.env.example"
check_file "phase3/.gitignore"
check_file "phase3/backend/Dockerfile"
check_file "phase3/backend/app.py"
check_file "phase3/backend/requirements.txt"
check_file "phase3/frontend/Dockerfile"
check_file "phase3/frontend/package.json"
check_file "phase3/frontend/src/App.js"
check_file "phase3/frontend/src/App.css"
check_file "phase3/frontend/src/index.js"
check_file "phase3/frontend/src/index.css"
check_file "phase3/frontend/public/index.html"
check_file "phase3/proxy/nginx.conf"
check_file "phase3/scripts/load_test.sh"
check_file "phase3/scripts/kill_test.sh"
echo ""

echo "🎯 Slides (dans le repo principal)"
echo "------------------------------------"
check_file "../../../chapitres/securite-production.adoc"
echo ""

echo "📊 Résumé"
echo "========="
echo "Erreurs: $ERRORS"
echo "Avertissements: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ Projet complet et prêt à être utilisé !"
    exit 0
else
    echo "❌ Des fichiers sont manquants. Veuillez les créer avant d'utiliser le projet."
    exit 1
fi
