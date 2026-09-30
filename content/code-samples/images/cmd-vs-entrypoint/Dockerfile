FROM alpine:3.24
LABEL maintainer="John Doe"

RUN apk add curl

CMD ["curl","--proxy", "http://cache-etu.univ-artois.fr:3128", "-L", "http://google.com"]

