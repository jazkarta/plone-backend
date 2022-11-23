# syntax=docker/dockerfile:1.4
FROM python:3.8-slim-buster as base
FROM base as builder

######################## builder image ##########################

RUN mkdir /wheelhouse

RUN --mount=type=cache,target=/var/cache/debconf --mount=type=cache,target=/var/cache/apt/archives --mount=type=cache,target=/var/lib/apt/list --mount=type=tmpfs,target=/usr/share/doc apt-get update \
    && buildDeps="git openssh-client dpkg-dev gcc libbz2-dev libc6-dev libffi-dev libjpeg62-turbo-dev libldap2-dev libopenjp2-7-dev libpcre3-dev libpq-dev libsasl2-dev libssl-dev libtiff5-dev libxml2-dev libxslt1-dev wget zlib1g-dev python3-dev build-essential" \
    && apt-get install -y --no-install-recommends $buildDeps \
    && rm -rf /var/cache/debconf/* \
    && mkdir -p /root/.ssh \
    && echo 'Host *\n    StrictHostKeyChecking no' > /root/.ssh/config


ARG PIP_VERSION=22.0.4
ENV PIP_VERSION=$PIP_VERSION
ARG SETUPTOOLS_VERSION=65.6.0
ENV SETUPTOOLS_VERSION=$SETUPTOOLS_VERSION

RUN pip install -U "pip==${PIP_VERSION}" "setuptools==${SETUPTOOLS_VERSION}"

ARG PLONE_VERSION=5.2.9
ARG PLONE_VOLTO="plone.volto==3.1.0a4"
ENV PIP_PARAMS=""
ENV PLONE_VERSION=$PLONE_VERSION
ENV PLONE_VOLTO=$PLONE_VOLTO

RUN --mount=type=cache,target=/root/.cache pip wheel Paste Plone ${PLONE_VOLTO} -c https://dist.plone.org/release/$PLONE_VERSION/constraints.txt  ${PIP_PARAMS} --wheel-dir=/wheelhouse

ARG EXTRA_PACKAGES="relstorage==3.4.5 psycopg2==2.9.3 python-ldap==3.4.0"
ENV EXTRA_PACKAGES=$EXTRA_PACKAGES

RUN --mount=type=ssh --mount=type=cache,target=/root/.cache [ -z "${EXTRA_PACKAGES}" ] || pip wheel ${EXTRA_PACKAGES} -c https://dist.plone.org/release/$PLONE_VERSION/constraints.txt  ${PIP_PARAMS} --wheel-dir=/wheelhouse

######################## Final image ##########################

FROM base

LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="plone-backend" \
      org.label-schema.description="Plone backend image image using Python 3.8" \
      org.label-schema.vendor="Plone Foundation"


RUN --mount=type=cache,target=/var/cache/debconf --mount=type=cache,target=/var/lib/apt/list --mount=type=tmpfs,target=/usr/share/doc \
    runDeps="libjpeg62 libopenjp2-7 libpq5 libtiff5 libxml2 libxslt1.1 poppler-utils wv busybox libmagic1" \
    && apt-get update \
    && apt-get install -y --no-install-recommends $runDeps \
    && busybox --install -s \
    && mkdir -p /data/filestorage /data/blobstorage /data/log /data/cache \
    && rm -rf /var/cache/debconf/* /var/cache/apt/archives/* /var/lib/dpkg/status* /var/log/dpkg* /var/log/apt/*

WORKDIR /app

ARG PIP_VERSION=22.0.4
ENV PIP_VERSION=$PIP_VERSION
ARG SETUPTOOLS_VERSION=65.6.0
ENV SETUPTOOLS_VERSION=$SETUPTOOLS_VERSION

RUN --mount=from=builder,target=/builder --mount=type=cache,target=/root/.cache \
    ln -s /data var \
    && pip install -U "pip==${PIP_VERSION}" "setuptools==${SETUPTOOLS_VERSION}" \
    && pip install --no-index --no-deps /builder/wheelhouse/*

COPY skeleton/ /app

RUN --mount=from=sources,target=/sources-mount <<EOT
    set -e -x
    cp -a /sources-mount /sources
    to_install=""
    for setup_file in $(ls /sources/*/setup.py); do
        directory="$(dirname $setup_file)"
        to_install="$to_install -e $directory"
    done
    pip install $to_install
EOT

EXPOSE 8080
VOLUME /data

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s CMD wget -q http://127.0.0.1:8080/ok -O - | grep OK || exit 1

ENTRYPOINT [ "/app/docker-entrypoint.sh" ]
CMD ["start"]
