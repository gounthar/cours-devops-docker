#!/bin/bash

# Script pour tester la résilience en tuant des conteneurs

set -e

echo "💀 Test de résilience SecureVote"
echo "=================================="
echo ""

# Fonction pour tuer et observer
test_resilience() {
    local service=$1
    local wait_time=${2:-10}

    echo "🔪 Test du service: $service"
    echo "  1. État initial..."
    docker compose ps $service

    echo "  2. Arrêt brutal du conteneur..."
    docker compose kill $service

    echo "  3. Attente de $wait_time secondes..."
    sleep $wait_time

    echo "  4. État après redémarrage automatique..."
    docker compose ps $service

    # Vérifier si le conteneur est healthy
    if docker compose ps $service | grep -q "healthy"; then
        echo "  ✅ Service $service récupéré avec succès"
    else
        echo "  ⚠️  Service $service en cours de récupération..."
    fi

    echo ""
}

# Tester chaque service
echo "Test 1/3 : Backend"
test_resilience backend 30

echo "Test 2/3 : Database"
test_resilience database 20

echo "Test 3/3 : Cache"
test_resilience cache 15

echo "🏁 Tests de résilience terminés"
echo ""
echo "💡 Vérifiez l'état final avec: docker compose ps"
echo "💡 Vérifiez les logs avec: docker compose logs --tail=50"
