FROM alpine:3.18
LABEL maintainer="John Doe"

RUN apk add curl

CMD ["curl","--proxy", "http://prx:3128", "-L", "http://google.com"]

