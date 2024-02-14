#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

TARGET_FOLDER="${YASHCHIKI_SANDBOXES}/${CONTAINER_STYLE}"

# We want the spack folder to be available inside the container image
# -> it needs to be bind mounted to the sandbox folder
sudo mount --bind "${YASHCHIKI_SPACK_PATH}" "${TARGET_FOLDER}/opt/spack"

if test -f "${YASHCHIKI_IMAGE_NAME}"; then
    echo "Image at ${YASHCHIKI_IMAGE_NAME} exists."
    exit 1
fi

# TODO: singularity 3.1 produces SIF w/o setuid flags on files, using a newer
# singularity for the image build
#sudo singularity build ${YASHCHIKI_IMAGE_NAME} "${TARGET_FOLDER}"
sudo /usr/local/singularity/sif_builder/bin/singularity build ${YASHCHIKI_IMAGE_NAME} "${TARGET_FOLDER}"

# umount spack folder afterwards
sudo umount "${TARGET_FOLDER}/opt/spack"

sudo chown -R $(id -un) ${YASHCHIKI_IMAGE_NAME}
