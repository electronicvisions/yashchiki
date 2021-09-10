#!/bin/bash

# Dump some meta information about yashchiki in the container to help other
# scripts.

set -Eeuo pipefail
shopt -s inherit_errexit

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

mkdir -p "${META_DIR_OUTSIDE}"

(
    cd "${WORKSPACE}/yashchiki"
    git log > "${META_DIR_OUTSIDE}/yashchiki_git.log"
    if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
        gerrit_get_current_change_commits \
            > "${META_DIR_OUTSIDE}/current_changes-yashchiki.dat"
    fi
)

(
    cd ${YASHCHIKI_SPACK_PATH}
    git log > "${META_DIR_OUTSIDE}/spack_git.log"
    if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
        gerrit_get_current_change_commits \
            > "${META_DIR_OUTSIDE}/current_changes-spack.dat"
    fi
)
