FROM alpine:3.22
LABEL maintainer="John Doe"
RUN apk update && apk add curl
# Si vous utilisez le proxy de l'Université
ENTRYPOINT ["curl","-x", "http://prx:3128", "-L", "--connect-timeout", "60"]
# Si vous utilisez votre propre proxy docker
# CMD ["curl","-x", "http://host.docker.internal:3128", "-L", "--connect-timeout", "60"]