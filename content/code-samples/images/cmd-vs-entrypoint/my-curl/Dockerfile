FROM alpine:3.21
LABEL maintainer="John Doe"
RUN apk update && apk add curl
# Si vous utilisez le proxy de l'Université
CMD ["curl","-x", "http://prx:3128", "-L", "--connect-timeout", "60", "http://google.com"]
# Si vous utilisez votre propre proxy docker
# CMD ["curl","-x", "http://host.docker.internal:3128", "-L", "--connect-timeout", "60", "http://google.com"]