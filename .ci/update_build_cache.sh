#!/bin/bash -x

set -euo pipefail

# only update build cache for stable builds
if [ "${CONTAINER_BUILD_TYPE}" != "stable" ]; then
    echo "Not updating build cache for testing builds." 1>&2
    exit 0
fi

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# taken from ./deploy_container.sh -> TODO: move all variables to single file!
IMAGE_NAME=singularity_spack_temp.img

# do not fail the build if some updates in the build-cache fail
#
# since the spack user cannot read home of vis_jenkins we need to mount the
# update script inside the container
set +e
# Arugments needed once we switch to singularity3: --writable-tmpfs
sudo -Eu spack singularity exec\
    -B "${BUILD_CACHE_OUTSIDE}:${BUILD_CACHE_INSIDE}:rw"\
    -B "${LOCK_FOLDER_OUTSIDE}:${LOCK_FOLDER_INSIDE}"\
    "${IMAGE_NAME}" \
    /opt/spack_install_scripts/update_build_cache_in_container.sh || exit 0
