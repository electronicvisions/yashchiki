#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# set generic locale for building
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

unset LC_CTYPE
unset LC_COLLATE
unset LC_MONETARY
unset LC_NUMERIC
unset LC_TIME
unset LC_MESSAGES

TARGET_FOLDER="${YASHCHIKI_SANDBOXES}/${CONTAINER_STYLE}"

mkdir -p ${YASHCHIKI_SANDBOXES}

apptainer build \
    --bind ${YASHCHIKI_CACHES_ROOT}/download_cache:/opt/spack/var/spack/cache \
    --bind ${YASHCHIKI_CACHES_ROOT}/spack_ccache:/opt/ccache \
    --bind ${YASHCHIKI_CACHES_ROOT}/build_caches:/opt/build_cache \
    --bind ${YASHCHIKI_CACHES_ROOT}/preserved_packages:/opt/preserved_packages \
    --bind ${JOB_TMP_SPACK}:/tmp/spack \
    --bind ${YASHCHIKI_SPACK_CONFIG}:/tmp/spack_config \
    --fakeroot --sandbox "${TARGET_FOLDER}" "${YASHCHIKI_RECIPE_PATH}" | tee out_singularity_build_recipe.txt
