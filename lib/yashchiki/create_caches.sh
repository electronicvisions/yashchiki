#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

if [ ! -d "${YASHCHIKI_CACHES_ROOT}" ]; then
    mkdir -p "${YASHCHIKI_CACHES_ROOT}"
fi

if [ ! -d "${YASHCHIKI_CACHES_ROOT}/build_caches" ]; then
    mkdir -p "${YASHCHIKI_CACHES_ROOT}/build_caches"
fi

if [ ! -d "${YASHCHIKI_CACHES_ROOT}/download_cache" ]; then
    mkdir -p "${YASHCHIKI_CACHES_ROOT}/download_cache"
fi

if [ ! -d "${YASHCHIKI_CACHES_ROOT}/spack_ccache" ]; then
    mkdir -p "${YASHCHIKI_CACHES_ROOT}/spack_ccache"
fi

if [ ! -d "${YASHCHIKI_CACHES_ROOT}/preserved_packages" ]; then
    mkdir -p "${YASHCHIKI_CACHES_ROOT}/preserved_packages"
fi
