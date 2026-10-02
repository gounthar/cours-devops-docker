FROM alpine:3.24
LABEL maintainer="John Doe"
RUN apk add --no-cache curl
# Forme shell : Docker lance /bin/sh -c "curl ..."
ENTRYPOINT curl -L --connect-timeout 60 \
  -x http://cache-etu.univ-artois.fr:3128
CMD ["http://example.com"]
