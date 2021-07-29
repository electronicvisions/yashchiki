#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

if (( $(find sandboxes -mindepth 1 -maxdepth 1 | wc -l) > 1 )); then
    echo "More than one sandbox found, this should never happen!" >&2
    exit 1
fi

TARGET_FOLDER="$(find sandboxes -mindepth 1 -maxdepth 1)"

# create image file
IMAGE_NAME=singularity_spack_temp.img

# We want the spack folder to be available inside the container image
# -> it needs to be bind mounted to the sandbox folder
sudo mount --bind "${PWD}/spack" "${TARGET_FOLDER}/opt/spack"

sudo singularity build ${IMAGE_NAME} "${TARGET_FOLDER}"

# umount spack folder afterwards
sudo umount "${TARGET_FOLDER}/opt/spack"

sudo chown -R vis_jenkins singularity_spack_*.img

if [[ "${CONTAINER_BUILD_TYPE}" =~ "^stable$" ]]; then
    # allow spack user to execute image
    chmod +rx singularity_spack_*.img
fi
