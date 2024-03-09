# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.19

ARG BUILD_DATE
ARG VERSION
ARG CHANGEDETECTION_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thespad"

ENV PYTHONUNBUFFERED=1

RUN \
  apk add --update --no-cache --virtual=build-dependencies \
    build-base \
    cargo \
    git \
    jpeg-dev \
    libc-dev \
    libffi-dev \
    libxslt-dev \
    npm \
    openssl-dev \
    python3-dev \
    zip \
    zlib-dev && \
  apk add --update --no-cache \
    libjpeg \
    libxslt \
    nodejs \
    poppler-utils \
    python3 && \
  echo "**** install changedetection.io ****" && \
  mkdir -p /app/changedetection && \
  if [ -z ${CHANGEDETECTON_RELEASE+x} ]; then \
    CHANGEDETECTON_RELEASE=$(curl -sX GET "https://api.github.com/repos/dgtlmoon/changedetection.io/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  curl -s -o \
    /tmp/changedetection.tar.gz -L \
    "https://github.com/dgtlmoon/changedetection.io/archive/${CHANGEDETECTON_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/changedetection.tar.gz -C \
    /app/changedetection/ --strip-components=1 && \
  rm /tmp/changedetection.tar.gz && \
  python3 -m venv /lsiopy && \
  pip install -U --no-cache-dir \
    pip \
    wheel && \
  pip install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.19/ -r /app/changedetection/requirements.txt && \
  PLAYWRIGHT_PY_RELEASE=$(curl -sX GET "https://api.github.com/repos/microsoft/playwright-python/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  git clone --depth 1 --branch "${PLAYWRIGHT_PY_RELEASE}" https://github.com/microsoft/playwright-python /tmp/playwright-python && \
  cd /tmp/playwright-python && \
  pip install -U --no-cache-dir . && \
  git clone --depth 1 --branch "${PLAYWRIGHT_PY_RELEASE}" https://github.com/microsoft/playwright /tmp/playwright && \
  cd /tmp/playwright && \
  npm ci && \
  npm run build && \
  # Don't build for other platforms
  sed -i '/-darwin-x64/d' ./utils/build/build-playwright-driver.sh && \
  sed -i '/-darwin-arm64/d' ./utils/build/build-playwright-driver.sh && \
  sed -i '/-linux-arm64/d' ./utils/build/build-playwright-driver.sh && \
  sed -i '/-win-x64/d' ./utils/build/build-playwright-driver.sh && \
  # Don't download a static node binary, use the OS install
  sed -i '/curl ${NODE_URL}/d' ./utils/build/build-playwright-driver.sh && \
  sed -i '/elif \[\[ "${ARCHIVE}" == "tar.gz" \]\]; then/,/else/d'  ./utils/build/build-playwright-driver.sh && \
  sed -i '/cp .\/output\/${NODE_DIR}\/LICENSE .\/output\/playwright-${SUFFIX}\//d' ./utils/build/build-playwright-driver.sh && \
  sed -i 's/"..\/..\/${NODE_DIR}\/${NPM_PATH}"/\/usr\/lib\/node_modules\/npm\/bin\/npm-cli.js/' ./utils/build/build-playwright-driver.sh && \
  ./utils/build/build-playwright-driver.sh && \
  rm -rf /lsiopy/lib/python3.11/site-packages/playwright/driver/* && \
  cp -R ./utils/build/output/playwright-linux/* /lsiopy/lib/python3.11/site-packages/playwright/driver && \
  ln -s /usr/bin/node /lsiopy/lib/python3.11/site-packages/playwright/driver/node && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    $HOME/.cache \
    $HOME/.npm

COPY root/ /

EXPOSE 5000

VOLUME /config
