# syntax=docker/dockerfile:1.6

ARG DPKG_NAME=pdf2htmlEX.deb
ARG POPPLER_VERSION=poppler-24.06.1
ARG PDF2HTMLEX_BRANCH=master
ARG FONTFORGE_VERSION=20230101

FROM ubuntu:22.04 as builder-base
# Repeat ARG for each stage
ARG DPKG_NAME
ARG PDF2HTMLEX_BRANCH
ENV DPKG_NAME=$DPKG_NAME
ENV PDF2HTMLEX_BRANCH=$PDF2HTMLEX_BRANCH
ENV UNATTENDED=--assume-yes
ENV DEBIAN_FRONTEND=noninteractive
ENV MAINTAINER_VALUE="Chris Culhane <chris.culhane@affinda.com>"

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y \
    sudo git && \
    mkdir -p /opt/pdf2htmlEX/buildScripts

WORKDIR /opt/pdf2htmlEX/buildScripts
COPY ["./buildScripts/versionEnvs", "./buildScripts/reportEnvs", "./buildScripts/getBuildToolsApt", "./buildScripts/getDevLibrariesApt", "./"]

WORKDIR /opt/pdf2htmlEX
RUN ./buildScripts/versionEnvs && \
    ./buildScripts/reportEnvs && \
    ./buildScripts/getBuildToolsApt && \
    ./buildScripts/getDevLibrariesApt


FROM builder-base as builder-poppler
ARG POPPLER_VERSION

RUN wget https://poppler.freedesktop.org/$POPPLER_VERSION.tar.xz && \
    tar xvf $POPPLER_VERSION.tar.xz && \
    echo "Getting poppler-data version: 0.4.12" &&\
    mv $POPPLER_VERSION poppler && \
    wget https://poppler.freedesktop.org/poppler-data-0.4.12.tar.gz && \
    tar xvf poppler-data-0.4.12.tar.gz && \
    mv poppler-data-0.4.12 poppler-data

COPY ./buildScripts/buildPoppler ./buildScripts/buildPoppler
RUN ./buildScripts/buildPoppler

FROM builder-base as builder-fontforge
ARG FONTFORGE_VERSION
RUN wget https://github.com/fontforge/fontforge/archive/$FONTFORGE_VERSION.tar.gz && \
    tar xvf $FONTFORGE_VERSION.tar.gz && \
    mv fontforge-$FONTFORGE_VERSION fontforge

COPY ./buildScripts/buildFontforge ./buildScripts/buildFontforge
RUN ./buildScripts/buildFontforge

FROM builder-base as builder
COPY --link --from=builder-poppler /opt/pdf2htmlEX/poppler /opt/pdf2htmlEX/poppler
COPY --link --from=builder-poppler /opt/pdf2htmlEX/poppler-data /opt/pdf2htmlEX/poppler-data
COPY --link --from=builder-fontforge /opt/pdf2htmlEX/fontforge /opt/pdf2htmlEX/fontforge

WORKDIR /opt/pdf2htmlEX
# Only copy in neccesary files to prevent cache misses
COPY --link ./buildScripts ./buildScripts
COPY --link ./patches ./patches
COPY --link ./pdf2htmlEX ./pdf2htmlEX
COPY --link ["ChangeLog", "README.md", "LICENSE", "LICENSE_GPLv3",  "./"]
RUN ./buildScripts/buildPdf2htmlEX && \
    ./buildScripts/installPdf2htmlEX && \
    ./buildScripts/reportEnvs   && \
    ./buildScripts/createDebianPackage

FROM ubuntu:22.04 as runtime
ARG DPKG_NAME
ENV DPKG_NAME=$DPKG_NAME
COPY --from=builder /opt/pdf2htmlEX/imageBuild/$DPKG_NAME /root/$DPKG_NAME

# Install pdf2htmlEX
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update && \
  apt -y upgrade && \
  apt -y --no-install-recommends install \
    /root/$DPKG_NAME

## make the /pdf directory the default working directory for any run of pdf2htmlEX
WORKDIR /pdf

ENTRYPOINT ["/usr/bin/pdf2htmlEX"]


# First export requirements
FROM affinda/poetry:3.12.2 as api-requirements
WORKDIR /opt/pdf2htmlEX
COPY ["api/poetry.lock", "api/pyproject.toml", "./"]
RUN poetry export --without-hashes -f requirements.txt -o ./requirements.txt --without dev --no-interaction --no-ansi


FROM affinda/python:3.12.2 as api
# Affinda/python image based on Ubuntu 22.04 but with custom python version
ARG DPKG_NAME
ENV DPKG_NAME=$DPKG_NAME
COPY --from=builder --link /opt/pdf2htmlEX/imageBuild/$DPKG_NAME /root/$DPKG_NAME

USER root
WORKDIR /opt/pdf2htmlEX


# Install pdf2htmlEX
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update && \
  apt -y upgrade && \
  apt -y --no-install-recommends install \
    /root/$DPKG_NAME && \
  mkdir -p /opt/pdf2htmlEX && \
  chown -R affinda:affinda /opt/pdf2htmlEX


# Copy in pyproject.toml too as it contains config for lots of things
COPY --link --from=api-requirements ["/opt/pdf2htmlEX/requirements.txt", "/opt/pdf2htmlEX/pyproject.toml", "./"]

RUN --mount=type=cache,target=/root/.cache \
    uv pip install -v -r requirements.txt --link-mode copy

USER affinda
COPY --link "./api" "/opt/pdf2html/api"

ARG SENTRY_RELEASE
ENV SENTRY_RELEASE=$SENTRY_RELEASE

# Use the affinda non root user
CMD ["/opt/pdf2html/api/init.sh"]
