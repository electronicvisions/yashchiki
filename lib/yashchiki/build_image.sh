#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

if [ -z "${YASHCHIKI_ENABLE_STAGE_IMAGE:-}" ]; then
    echo "Skipping stage build-base-sandbox."
    exit 0
fi

TARGET_FOLDER="${YASHCHIKI_SANDBOXES}/${CONTAINER_STYLE}"

if test -f "${YASHCHIKI_IMAGE_NAME}"; then
    echo "Image at ${YASHCHIKI_IMAGE_NAME} exists."
    exit 1
fi

/skretch/opt/apptainer/1.2.5/bin/apptainer build --fakeroot ${YASHCHIKI_IMAGE_NAME} "${TARGET_FOLDER}"
