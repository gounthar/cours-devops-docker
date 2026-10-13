# Configuration de Gunicorn, le serveur WSGI de production
# (le serveur intégré de Flask n'est fait que pour le développement)

bind = "0.0.0.0:5000"
workers = 2
accesslog = "-"  # journal des requêtes sur la sortie standard


def on_starting(server):
    """Initialise la base une seule fois, dans le processus maître,
    avant le lancement des workers.

    Le bloc `if __name__ == '__main__'` d'app.py n'est jamais exécuté
    sous Gunicorn : sans ce hook, les tables ne seraient pas créées.
    """
    from app import init_db
    init_db()
