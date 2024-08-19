
FROM ghcr.io/astefanutti/decktape:3.13.0 AS pdf-generator

USER root
RUN apk add --no-cache ghostscript

USER ${CURRENT_UID}
COPY ${DIST_DIR} /slides
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]