# syntax=docker/dockerfile:1.4
FROM python:3.8-slim-buster as base
FROM base as builder

RUN mkdir /wheelhouse

RUN apt-get update \
    && buildDeps="git openssh-client dpkg-dev gcc libbz2-dev libc6-dev libffi-dev libjpeg62-turbo-dev libldap2-dev libopenjp2-7-dev libpcre3-dev libpq-dev libsasl2-dev libssl-dev libtiff5-dev libxml2-dev libxslt1-dev wget zlib1g-dev python3-dev build-essential" \
    && apt-get install -y --no-install-recommends $buildDeps\
    && rm -rf /var/lib/apt/lists/* /usr/share/doc \
    && mkdir -p /root/.ssh \
    && echo 'Host *\n    StrictHostKeyChecking no' > /root/.ssh/config


ARG PIP_VERSION=22.0.4
ENV PIP_VERSION=$PIP_VERSION

RUN pip install -U "pip==${PIP_VERSION}"

ARG PLONE_VERSION=5.2.9
ARG PLONE_VOLTO="plone.volto==3.1.0a4"
ENV PIP_PARAMS=""
ENV PLONE_VERSION=$PLONE_VERSION
ENV PLONE_VOLTO=$PLONE_VOLTO

RUN --mount=type=cache,target=/root/.cache pip wheel Paste Plone ${PLONE_VOLTO} -c https://dist.plone.org/release/$PLONE_VERSION/constraints.txt  ${PIP_PARAMS} --wheel-dir=/wheelhouse

ARG EXTRA_PACKAGES="relstorage==3.4.5 psycopg2==2.9.3 python-ldap==3.4.0"
ENV EXTRA_PACKAGES=$EXTRA_PACKAGES

RUN --mount=type=ssh --mount=type=cache,target=/root/.cache pip wheel ${EXTRA_PACKAGES} -c https://dist.plone.org/release/$PLONE_VERSION/constraints.txt  ${PIP_PARAMS} --wheel-dir=/wheelhouse

FROM base

LABEL maintainer="Plone Community <dev@plone.org>" \
      org.label-schema.name="plone-backend" \
      org.label-schema.description="Plone backend image image using Python 3.8" \
      org.label-schema.vendor="Plone Foundation"


RUN useradd --system -m -d /app -U -u 500 plone \
    && runDeps="git libjpeg62 libopenjp2-7 libpq5 libtiff5 libxml2 libxslt1.1 lynx poppler-utils rsync wv busybox libmagic1 gosu" \
    && apt-get update \
    && apt-get install -y --no-install-recommends $runDeps \
    && busybox --install -s \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc \
    && mkdir -p /data/filestorage /data/blobstorage /data/log /data/cache

COPY --from=builder /wheelhouse /wheelhouse

WORKDIR /app

ARG PIP_VERSION=22.0.4
ENV PIP_PARAMS=""
ENV PIP_VERSION=$PIP_VERSION

RUN python -m venv . \
    && ./bin/pip install -U "pip==${PIP_VERSION}" \
    && ./bin/pip install --force-reinstall --no-index --no-deps ${PIP_PARAMS} /wheelhouse/* \
    && find . \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' + \
    && rm -rf .cache

COPY skeleton/ /app

RUN ln -s /data var \
    && find /data  -not -user plone -exec chown plone:plone {} \+ \
    && find /app -not -user plone -exec chown plone:plone {} \+

EXPOSE 8080
VOLUME /data

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s CMD wget -q http://127.0.0.1:8080/ok -O - | grep OK || exit 1

ENTRYPOINT [ "/app/docker-entrypoint.sh" ]
CMD ["start"]
