#!/bin/bash -x

# only update build cache for stable builds
if [ "${CONTAINER_BUILD_TYPE}" != "stable" ]; then
    echo "Not updating build cache for testing builds." 1>&2
    exit 0
fi

# taken from ./deploy_container.sh -> TODO: move all variables to single file!
IMAGE_NAME=singularity_spack_temp.img
BUILD_CACHE_DIR=${HOME}/build_cache

# do not fail the build if some updates in the build-cache fail
# since the spack user cannot read home of vis_jenkins we need to mount the update script inside the container
sudo -u spack singularity exec\
    -B "${BUILD_CACHE_DIR}:/opt/build_cache:rw"\
    -B "${WORKSPACE}/misc-files/update-build-cache-in-container.sh:/update.sh"\
    "${IMAGE_NAME}" /update.sh || exit 0
