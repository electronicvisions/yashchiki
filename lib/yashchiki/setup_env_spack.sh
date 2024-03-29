#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# inside the container the tmpdir is mounted to /tmp/spack
export SPACK_TMPDIR="/tmp/spack"

export OLD_HOME=$HOME
export HOME=${SPACK_TMPDIR}/home
export TMPDIR=${SPACK_TMPDIR}/tmp
export CCACHE_DIR="/opt/ccache"
export BUILD_CACHE_DIR="/opt/build_cache"

if [ ! -d "${MY_SPACK_FOLDER}" ]; then
    echo "${MY_SPACK_FOLDER} does not exist!"
    exit 1
fi

if [ ! -d "${CCACHE_DIR}" ]; then
    echo "${CCACHE_DIR} does not exist!"
    exit 1
fi

if [ ! -d "${BUILD_CACHE_DIR}" ]; then
    echo "${BUILD_CACHE_DIR} does not exist!"
    exit 1
fi

if [ ! -d "${TMPDIR}" ]; then
    mkdir -p "${TMPDIR}"
fi
