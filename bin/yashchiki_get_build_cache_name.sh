#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit

ROOT_DIR="$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")"
source "${ROOT_DIR}/lib/yashchiki/get_latest_failed_build_cache.sh"

# For testing changesets, see if user supplied a custom build cache with
# `WITH_CACHE_NAME=<name>`. If not, check if there is a saved build cache from a
# previous build of this changeset and use that as build cache. If the comment
# contains `WITHOUT_FAILED_CACHE` we do nothing, i.e. we use the default cache.
if [ -n "${GERRIT_EVENT_COMMENT_TEXT:-}" ]; then

    tmpfile_comment="$(mktemp)"

    echo "${GERRIT_EVENT_COMMENT_TEXT}" | base64 -d > "${tmpfile_comment}"

    if grep -q "\bWITH_CACHE_NAME=" "${tmpfile_comment}"; then
        # use specified cache
        echo "$(sed -nE \
            -e "s:.*\<WITH_CACHE_NAME=(\S*)(\s|$).*:\1:gp" \
            "${tmpfile_comment}")"
        rm "${tmpfile_comment}"
        exit 0
    elif ! grep -q "\bWITHOUT_FAILED_CACHE\b" "${tmpfile_comment}"; then
        latest_failed_build_cache="$(get_latest_failed_build_cache_name)"

        # If there is no previous build cache the while loop will terminate
        # immedately and build_num be zero.
        if [ -n "${latest_failed_build_cache}" ]; then
            echo "${latest_failed_build_cache}"
            rm "${tmpfile_comment}"
            exit 0
        fi
    fi

    rm "${tmpfile_comment}"
fi

echo "${BUILD_CACHE_NAME}"
