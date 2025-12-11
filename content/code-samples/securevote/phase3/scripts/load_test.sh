#!/bin/bash

# Script de test de charge pour SecureVote
# Simule plusieurs utilisateurs votant en parallèle

set -e

API_URL="${1:-http://localhost:8080}"
NUM_REQUESTS="${2:-100}"
CONCURRENCY="${3:-10}"

echo "🚀 Test de charge SecureVote"
echo "================================"
echo "URL: $API_URL"
echo "Requêtes: $NUM_REQUESTS"
echo "Concurrence: $CONCURRENCY"
echo ""

# Vérifier que curl est installé
if ! command -v curl &> /dev/null; then
    echo "❌ curl n'est pas installé"
    exit 1
fi

# Fonction pour voter
vote() {
    local option_id=$((RANDOM % 4 + 1))
    curl -s -X POST "$API_URL/api/vote" \
        -H "Content-Type: application/json" \
        -d "{\"option_id\": $option_id}" \
        > /dev/null
    echo -n "."
}

export -f vote
export API_URL

echo "📊 Envoi de $NUM_REQUESTS votes..."

# Exécuter les votes en parallèle
for i in $(seq 1 $NUM_REQUESTS); do
    (vote) &

    # Limiter la concurrence
    if [ $((i % CONCURRENCY)) -eq 0 ]; then
        wait
    fi
done

wait

echo ""
echo "✅ Test terminé !"
echo ""
echo "📈 Résultats disponibles sur: $API_URL/api/results"

# Afficher les résultats
echo ""
echo "Résultats actuels :"
curl -s "$API_URL/api/results" | python3 -m json.tool

echo ""
echo "💡 Surveillez les ressources avec: docker stats"
