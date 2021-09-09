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

echo "creating ${CONTAINER_STYLE}_recipe.def" >&2
SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
"${SOURCE_DIR}/${CONTAINER_STYLE}_create_recipe.sh"

echo "created ${CONTAINER_STYLE}_recipe.def" >&2
cat "${WORKSPACE}/${CONTAINER_STYLE}_recipe.def"

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

TARGET_FOLDER="sandboxes/${CONTAINER_STYLE}"

# Do not change: special sudo permit for the host user...
sudo rm -rf sandboxes/

mkdir sandboxes

# Do not change: special sudo permit for the host user...
sudo -E singularity build --sandbox "${TARGET_FOLDER}" ${CONTAINER_STYLE}_recipe.def | tee out_singularity_build_${CONTAINER_STYLE}_recipe.txt
