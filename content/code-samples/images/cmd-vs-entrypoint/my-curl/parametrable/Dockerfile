FROM alpine:3.24
LABEL maintainer="John Doe"
RUN apk add --no-cache curl
# Si vous utilisez le proxy de l'Université
ENTRYPOINT ["curl", "-L", "--connect-timeout", "60", \
  "-x", "http://cache-etu.univ-artois.fr:3128"]
# Si vous utilisez votre propre proxy docker
# (sous Linux, lancer avec --add-host=host.docker.internal:host-gateway)
# ENTRYPOINT ["curl", "-L", "--connect-timeout", "60", \
#   "-x", "http://host.docker.internal:3128"]
