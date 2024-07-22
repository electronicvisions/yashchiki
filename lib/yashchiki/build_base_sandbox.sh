#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

if [ -z "${YASHCHIKI_ENABLE_STAGE_BUILD_BASE_IMAGE:-}" ]; then
    echo "Skipping stage build-base-image."
    exit 0
fi

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

apptainer build --fakeroot --force ${YASHCHIKI_BASEIMAGE_NAME} $1
