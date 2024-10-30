FROM node:20-alpine

# Install latest version of required dependencies
# hadolint ignore=DL3018
RUN apk add --no-cache \
  curl \
  git \
  tini \
  unzip

# Install NPM dependencies globally (latest versions)
# hadolint ignore=DL3016,DL3059
RUN npm install --global npm npm-check-updates

# Install App's dependencies (dev and runtime)
COPY ./npm-packages /app/npm-packages
# By creating the symlink, the npm operation are kept at the root of /app
# but the operation can still be executed to the package*.json files without ENOENT error
RUN ln -s /app/npm-packages/package.json /app/package.json \
  && ln -s /app/npm-packages/package-lock.json /app/package-lock.json

WORKDIR /app

# Install NPM dependencies using the package-lock.json
RUN { npm install-clean && npx update-browserslist-db@latest; } || npm install

## Link some NPM commands installed as dependencies to be available within the PATH
# There muste be 1 and only 1 `npm link` for each command
# hadolint ignore=DL3059
RUN npm link gulp

COPY ./gulp/gulpfile.js /app/gulpfile.js

VOLUME ["/app"]

# HTTP
EXPOSE 8000

ENTRYPOINT ["/sbin/tini","-g","gulp"]
CMD ["default"]
