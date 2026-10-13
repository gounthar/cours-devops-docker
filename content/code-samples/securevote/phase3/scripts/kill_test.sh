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
    docker compose ps "$service"

    # `docker compose kill` compte comme un arrêt manuel : aucune politique
    # `restart:` ne relance le conteneur. Pour simuler un vrai plantage, on tue
    # le processus principal depuis l'extérieur, comme le ferait le noyau (OOM).
    echo "  2. Plantage simulé (kill -9 du processus principal)..."
    local cid pid
    cid=$(docker compose ps -q "$service")
    if [ -z "$cid" ]; then
        echo "  ❌ Service $service introuvable (lancé depuis le dossier phase3/ ?)"
        return 1
    fi
    pid=$(docker inspect -f '{{.State.Pid}}' "$cid")
    if [ "${pid:-0}" -le 0 ]; then
        echo "  ❌ Service $service arrêté, rien à tuer"
        return 1
    fi
    docker run --rm --pid=host --privileged alpine:3.22 kill -9 "$pid"

    echo "  3. Attente de $wait_time secondes..."
    sleep $wait_time

    echo "  4. État après redémarrage automatique..."
    docker compose ps "$service"

    # Vérifier si le conteneur est healthy
    if docker compose ps "$service" | grep -q "(healthy)"; then
        echo "  ✅ Service $service récupéré avec succès"
    else
        echo "  ⚠️  Service $service en cours de récupération..."
    fi

    echo ""
}

# Tester chaque service
# Un service impossible à tester ne doit pas arrêter les suivants (set -e),
# mais le script doit finir en échec.
echecs=0
echo "Test 1/3 : Backend"
test_resilience backend 30 || echecs=$((echecs + 1))

echo "Test 2/3 : Database"
test_resilience database 20 || echecs=$((echecs + 1))

echo "Test 3/3 : Cache"
test_resilience cache 15 || echecs=$((echecs + 1))

echo "🏁 Tests de résilience terminés ($echecs service(s) non testé(s))"
echo ""
echo "💡 Vérifiez l'état final avec: docker compose ps"
echo "💡 Vérifiez les logs avec: docker compose logs --tail=50"
exit "$echecs"
