from flask import Flask, jsonify, request
from flask_cors import CORS
import psycopg2
import redis
import os
import json

app = Flask(__name__)
CORS(app)

# Configuration depuis les variables d'environnement
DATABASE_URL = os.getenv('DATABASE_URL')
REDIS_URL = os.getenv('REDIS_URL')
SECRET_KEY = os.getenv('SECRET_KEY', 'default-secret')

app.config['SECRET_KEY'] = SECRET_KEY

# Connexion Redis
redis_client = redis.from_url(REDIS_URL)

def get_db_connection():
    """Crée une connexion à la base de données"""
    conn = psycopg2.connect(DATABASE_URL)
    return conn

def init_db():
    """Initialise la base de données avec les tables nécessaires"""
    conn = get_db_connection()
    cur = conn.cursor()

    # Créer la table des options de vote
    cur.execute("""
        CREATE TABLE IF NOT EXISTS vote_options (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            description TEXT
        )
    """)

    # Créer la table des votes
    cur.execute("""
        CREATE TABLE IF NOT EXISTS votes (
            id SERIAL PRIMARY KEY,
            option_id INTEGER REFERENCES vote_options(id),
            voter_ip VARCHAR(45),
            voted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Insérer des options de vote par défaut
    cur.execute("SELECT COUNT(*) FROM vote_options")
    if cur.fetchone()[0] == 0:
        cur.execute("""
            INSERT INTO vote_options (name, description) VALUES
            ('Docker', 'La plateforme de conteneurisation'),
            ('Kubernetes', 'L''orchestrateur de conteneurs'),
            ('Podman', 'Alternative à Docker'),
            ('LXC', 'Conteneurs Linux natifs')
        """)

    conn.commit()
    cur.close()
    conn.close()
    print("Base de données initialisée")

@app.route('/health')
def health():
    """Endpoint de santé basique"""
    # VULNÉRABILITÉ : Ne vérifie pas réellement les dépendances !
    return jsonify({"status": "ok"}), 200

@app.route('/api/options', methods=['GET'])
def get_options():
    """Récupère toutes les options de vote"""
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name, description FROM vote_options")
    options = cur.fetchall()
    cur.close()
    conn.close()

    return jsonify([
        {"id": opt[0], "name": opt[1], "description": opt[2]}
        for opt in options
    ])

@app.route('/api/vote', methods=['POST'])
def vote():
    """Enregistre un vote"""
    data = request.get_json()
    option_id = data.get('option_id')
    voter_ip = request.remote_addr

    if not option_id:
        return jsonify({"error": "option_id requis"}), 400

    conn = get_db_connection()
    cur = conn.cursor()

    # Enregistrer le vote
    cur.execute(
        "INSERT INTO votes (option_id, voter_ip) VALUES (%s, %s)",
        (option_id, voter_ip)
    )

    conn.commit()
    cur.close()
    conn.close()

    # Invalider le cache des résultats
    redis_client.delete('results')

    return jsonify({"status": "success", "message": "Vote enregistré"}), 201

@app.route('/api/results', methods=['GET'])
def get_results():
    """Récupère les résultats avec cache Redis"""
    # Vérifier le cache
    cached = redis_client.get('results')
    if cached:
        return jsonify(json.loads(cached))

    # Sinon, interroger la base de données
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT vo.name, COUNT(v.id) as vote_count
        FROM vote_options vo
        LEFT JOIN votes v ON vo.id = v.option_id
        GROUP BY vo.id, vo.name
        ORDER BY vote_count DESC
    """)

    results = cur.fetchall()
    cur.close()
    conn.close()

    results_json = [
        {"name": r[0], "votes": r[1]}
        for r in results
    ]

    # Mettre en cache pour 60 secondes
    redis_client.setex('results', 60, json.dumps(results_json))

    return jsonify(results_json)

@app.route('/api/reset', methods=['POST'])
def reset_votes():
    """Réinitialise tous les votes (pour les tests)"""
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM votes")
    conn.commit()
    cur.close()
    conn.close()

    # Invalider le cache
    redis_client.delete('results')

    return jsonify({"status": "success", "message": "Votes réinitialisés"}), 200

if __name__ == '__main__':
    # Initialiser la DB au démarrage
    init_db()

    # VULNÉRABILITÉ : debug=True en production expose des informations sensibles !
    # VULNÉRABILITÉ : host='0.0.0.0' expose sur toutes les interfaces
    app.run(host='0.0.0.0', port=5000, debug=True)
