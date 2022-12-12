#!/bin/sh
PIP_VERSION=22.3

# Script to build a plone backend image based on configuration in files:
# image.txt
# requirements.txt
# plone_version.txt

BUILD_PATH=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXTRA_PACKAGES=""
LOCAL_SOURCES=${LOCAL_SOURCES:-src}
SETUPTOOLS_VERSION=65.6.0


[ -f image.txt ] || {
    echo Please place a file in image.txt with the desired image tag
    exit 1
}

[ -f requirements.txt ] && {
    EXTRA_PACKAGES=$(printf "%s" "$(cat requirements.txt)")
}

[ -f plone_version.txt ] || {
    echo "Please place a file in plone_version.txt with a valid Plone version (for instance 5.2.9)"
    exit 1
}

[ -f pip_version.txt ] && {
    PIP_VERSION=$(printf "%s" "$(cat pip_version.txt)")
    echo Using pip version ${PIP_VERSION}
}

[ -f setuptools_version.txt ] && {
    SETUPTOOLS_VERSION=$(printf "%s" "$(cat setuptools_version.txt)")
    echo Using setuptools version ${SETUPTOOLS_VERSION}
}

[ -f local_sources.txt ] && {
    LOCAL_SOURCES=$(printf "%s" "$(cat local_sources.txt)")
    echo Getting sources from  ${LOCAL_SOURCES}
}

[ -d "$LOCAL_SOURCES" ] || {
    echo "Directory $LOCAL_SOURCES not found. Point the environment variable LOCAL_SOURCES to a directory containing your custom python packages"
    exit 1
}

ls "$LOCAL_SOURCES"/*/setup.py > /dev/null 2> /dev/null || {
    echo The directory $LOCAL_SOURCES contains no pyhon packages
    echo Make sure you provide your local source directory name in local_sources.txt
    exit 1
}


IMAGE=$(printf "%s" "$(cat image.txt)")
PLONE_VERSION=$(printf "%s" "$(cat plone_version.txt)")

docker buildx build --progress=plain "$BUILD_PATH" -t $IMAGE \
    --build-arg EXTRA_PACKAGES="${EXTRA_PACKAGES}" \
    --build-arg PLONE_VERSION="${PLONE_VERSION}" \
    --build-arg PLONE_VOLTO= \
    --build-arg PIP_VERSION=${PIP_VERSION} \
    --build-arg SETUPTOOLS_VERSION=${SETUPTOOLS_VERSION} \
    --build-context "sources=$(readlink -f ${LOCAL_SOURCES})"
