# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.22

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
    openssl-dev \
    python3-dev \
    zip \
    zlib-dev && \
  apk add --update --no-cache \
    file \
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
    setuptools \
    wheel && \
  pip install -U --no-cache-dir --find-links https://wheel-index.linuxserver.io/alpine-3.22/ -r /app/changedetection/requirements.txt && \
  PLAYWRIGHT_PY_RELEASE=$(curl -sX GET "https://api.github.com/repos/microsoft/playwright-python/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  git clone --depth 1 --branch "${PLAYWRIGHT_PY_RELEASE}" https://github.com/microsoft/playwright-python /tmp/playwright-python && \
  cd /tmp/playwright-python && \
  pip install -U --no-cache-dir . && \
  rm -f /lsiopy/lib/python3.12/site-packages/playwright/driver/node && \
  ln -s /usr/bin/node /lsiopy/lib/python3.12/site-packages/playwright/driver/node && \
  # Force UTF-8 encoding for browser steps to prevent exception
  sed -i "s|xpath_element_js = importlib.resources.files(\"changedetectionio.content_fetchers.res\").joinpath('xpath_element_scraper.js').read_text()|xpath_element_js = importlib.resources.files(\"changedetectionio.content_fetchers.res\").joinpath('xpath_element_scraper.js').read_text(encoding='utf-8')|" /app/changedetection/changedetectionio/blueprint/browser_steps/browser_steps.py && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* \
    $HOME/.cache \
    $HOME/.npm

COPY root/ /

EXPOSE 5000

VOLUME /config
