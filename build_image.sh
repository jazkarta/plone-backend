#!/bin/sh
PIP_VERSION=22.3

# Script to build a plone backend image based on configuration in files:
# image.txt
# requirements.txt
# plone_version.txt

BUILD_PATH=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)


[ -f image.txt ] || {
    echo Please place a file in image.txt with the desired image tag
    exit 1
}

[ -f requirements.txt ] || {
    echo Please place a file in requirements.txt with the needed requirements
    exit 1
}

[ -f plone_version.txt ] || {
    echo "Please place a file in plone_version.txt with a valid Plone version (for instance 5.2.9)"
    exit 1
}

[ -f pip_version.txt ] && {
    PIP_VERSION=$(cat pip_version.txt |xargs echo -n)
}


IMAGE=$(cat image.txt |xargs echo -n)
EXTRA_PACKAGES=$(cat requirements.txt |xargs echo -n)
PLONE_VERSION=$(cat plone_version.txt |xargs echo -n)

export DOCKER_BUILDKIT=1

docker build --ssh default --progress=plain "$BUILD_PATH" -t $IMAGE \
    --build-arg EXTRA_PACKAGES="${EXTRA_PACKAGES}" \
    --build-arg PLONE_VERSION="${PLONE_VERSION}" \
    --build-arg PLONE_VOLTO= \
    --build-arg PIP_VERSION=${PIP_VERSION}
