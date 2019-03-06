#!/bin/bash -x

set -euo pipefail

if (( $(find sandboxes -mindepth 1 -maxdepth 1 | wc -l) > 1 )); then
    echo "More than one sandbox found, this should never happen!" >&2
    exit 1
fi

TARGET_FOLDER="$(find sandboxes -mindepth 1 -maxdepth 1)"

# create image file
IMAGE_NAME=singularity_spack_temp.img
sudo singularity build ${IMAGE_NAME} "${TARGET_FOLDER}"
sudo chown -R vis_jenkins singularity_spack_*.img
