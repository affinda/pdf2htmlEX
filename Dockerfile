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
    sudo git

RUN mkdir -p /opt/pdf2htmlEX/buildScripts
WORKDIR /opt/pdf2htmlEX/buildScripts
COPY ["./buildScripts/versionEnvs", "./buildScripts/reportEnvs", "./buildScripts/getBuildToolsApt", "./buildScripts/getDevLibrariesApt", "./"]

WORKDIR /opt/pdf2htmlEX
RUN ./buildScripts/versionEnvs
RUN ./buildScripts/reportEnvs

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    ./buildScripts/getBuildToolsApt

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
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
RUN FONTFORGE_SRC=$FONTFORGE_VERSION.tar.gz && \
    wget https://github.com/fontforge/fontforge/archive/$FONTFORGE_SRC && \
    tar xvf $FONTFORGE_SRC && \
    mv fontforge-$FONTFORGE_VERSION fontforge

COPY ./buildScripts/buildFontforge ./buildScripts/buildFontforge
RUN ./buildScripts/buildFontforge

FROM builder-base as builder
COPY --link --from=builder-poppler /opt/pdf2htmlEX/poppler /opt/pdf2htmlEX/poppler
COPY --link --from=builder-poppler /opt/pdf2htmlEX/poppler-data /opt/pdf2htmlEX/poppler-data
COPY --link --from=builder-fontforge /opt/pdf2htmlEX/fontforge /opt/pdf2htmlEX/fontforge

WORKDIR /opt/pdf2htmlEX
COPY ./ ./
RUN ./buildScripts/buildPdf2htmlEX

RUN ./buildScripts/installPdf2htmlEX

RUN ./buildScripts/reportEnvs

#RUN ./buildScripts/createAppImage

RUN ./buildScripts/createDebianPackage


FROM ubuntu:22.04 as runtime
ARG DPKG_NAME
ENV DPKG_NAME=$DPKG_NAME
COPY --from=builder /opt/pdf2htmlEX/imageBuild/$DPKG_NAME /root/$DPKG_NAME

#
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update && \
  apt -y upgrade && \
  apt -y --no-install-recommends install \
    /root/$DPKG_NAME

## make the /pdf directory the default working directory for any run of pdf2htmlEX
WORKDIR /pdf

ENTRYPOINT ["/usr/bin/pdf2htmlEX"]