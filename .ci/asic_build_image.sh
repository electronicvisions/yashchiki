#!/bin/bash -x

set -euo pipefail

if (( $(find sandboxes -mindepth 1 -maxdepth 1 | wc -l) > 1 )); then
    echo "More than one sandbox found, this should never happen!" >&2
    exit 1
fi

TARGET_FOLDER="$(find sandboxes -mindepth 1 -maxdepth 1)"

# create image file
IMAGE_NAME=singularity_asic_temp.img

sudo singularity build ${IMAGE_NAME} "${TARGET_FOLDER}"

sudo chown -R vis_jenkins singularity_asic_*.img

if [[ "${CONTAINER_BUILD_TYPE}" =~ "^stable$" ]]; then
    # allow spack user to execute image
    chmod +rx singularity_asic_*.img
fi
