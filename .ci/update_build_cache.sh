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
singularity exec -B "${BUILD_CACHE_DIR}:/opt/build_cache:rw" "${IMAGE_NAME}" "${WORKSPACE}/misc-files/update-build-cache-in-container.sh" || exit 0
