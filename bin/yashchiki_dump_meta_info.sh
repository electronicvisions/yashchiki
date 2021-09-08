#!/bin/bash

# Dump some meta information about yashchiki in the container to help other
# scripts.

set -Eeuo pipefail
shopt -s inherit_errexit

ROOT_DIR="$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")"
source "${ROOT_DIR}/lib/yashchiki/gerrit.sh"

mkdir -p "${YASHCHIKI_META_DIR}"

(
    if [ -n "${YASHCHIKI_INSTALL:-}" ]; then
        cd "${YASHCHIKI_INSTALL}"
        git log > "${YASHCHIKI_META_DIR}/yashchiki_git.log"
        if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
            gerrit_get_current_change_commits \
                > "${YASHCHIKI_META_DIR}/current_changes-yashchiki.dat"
        fi
    fi
)

(
    cd ${YASHCHIKI_SPACK_PATH}
    git log > "${YASHCHIKI_META_DIR}/spack_git.log"
    if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
        gerrit_get_current_change_commits \
            > "${YASHCHIKI_META_DIR}/current_changes-spack.dat"
    fi
)
