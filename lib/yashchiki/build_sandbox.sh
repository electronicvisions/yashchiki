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

# check if host-user-owned temp folder for spack build exists
if [ ! -d "${JOB_TMP_SPACK}" ]; then
    echo "${JOB_TMP_SPACK} should exist, aborting!" >&2
    exit 1
fi

# make job temp folder writable for all users (i.e., spack)
chmod 777 "${JOB_TMP_SPACK}"

# build the container (using scripts from above)
if [ -n "${YASHCHIKI_PROXY_HTTP:-}" ]; then
	export http_proxy=${YASHCHIKI_PROXY_HTTP}
fi
if [ -n "${YASHCHIKI_PROXY_HTTPS:-}" ]; then
	export https_proxy=${YASHCHIKI_PROXY_HTTPS}
fi

TARGET_FOLDER="${YASHCHIKI_SANDBOXES}/${CONTAINER_STYLE}"

# Do not change: special sudo permit for the host user... (with env var resolved by host user)
# When changing the env var value the sudo permit needs changing as well
sudo rm -rf ${YASHCHIKI_SANDBOXES}/

mkdir ${YASHCHIKI_SANDBOXES}

# Do not change: special sudo permit for the host user...
sudo -E singularity build --sandbox "${TARGET_FOLDER}" "${YASHCHIKI_RECIPE_PATH}" | tee out_singularity_build_${CONTAINER_STYLE}_recipe.txt
