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

# Do not change: special sudo permit for the host user...
sudo -E singularity build --sandbox "${TARGET_FOLDER}" "${YASHCHIKI_RECIPE_PATH}" | tee out_singularity_build_recipe.txt
