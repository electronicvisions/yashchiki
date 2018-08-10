#!/bin/bash -x

# taken from ./deploy_container.sh -> TODO: move all variables to single file!
IMAGE_NAME=singularity_spack_${SPACK_BRANCH}.img
BUILD_CACHE_DIR=${WORKSPACE}/build_cache

# do not fail the build if some updates in the build-cache fail
singularity exec -B "${BUILD_CACHE_DIR}:/opt/build_cache:rw" "${IMAGE_NAME}" "${WORKSPACE}/misc-files/update-build-cache-in-container.sh" || exit 0
