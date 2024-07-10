#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

usage() { echo "Usage: ${0} -c <container>" 1>&2; exit 1; }

while getopts ":c:" opts; do
    case "${opts}" in
        c)
            IMAGE_NAME="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${IMAGE_NAME:-}" ]; then
    usage
fi

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# do not fail the build if some updates in the build-cache fail
#
# since the spack user cannot read home of the host user we need to mount the
# update script inside the container
set +e
# Arugments needed once we switch to singularity3: --writable-tmpfs
sudo -E singularity exec\
    -B "${BUILD_CACHE_OUTSIDE}:${BUILD_CACHE_INSIDE}:rw"\
    "${IMAGE_NAME}" \
    sudo -Eu spack /opt/spack_install_scripts/update_build_cache_in_container.sh -j ${YASHCHIKI_JOBS} -q || exit 0
