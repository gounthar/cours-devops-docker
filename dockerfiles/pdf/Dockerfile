FROM ghcr.io/astefanutti/decktape:3.14.0 AS pdf-generator

# Define build-time variables
ARG CURRENT_UID
ARG DIST_DIR

# Set environment variables
ENV CURRENT_UID=${CURRENT_UID}
ENV DIST_DIR=${DIST_DIR}

USER root
RUN apk add --no-cache ghostscript dos2unix

# Copy entrypoint.sh to the root directory and set permissions
COPY entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh

# Switch to the CURRENT_UID user
USER ${CURRENT_UID}
COPY ${DIST_DIR} /slides

ENTRYPOINT ["/entrypoint.sh"]
