#!/bin/bash -x
set -euo pipefail

#
# Some early checks to make sure all needed environment variables are defined.
#
if [ "${CONTAINER_BUILD_TYPE}" != "testing" ] && \
        [ "${CONTAINER_BUILD_TYPE}" != "stable" ]; then
    echo "CONTAINER_BUILD_TYPE needs to be 'testing' or 'stable'!" >&2
    exit 1
fi

if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
    # In case of testing builds we need to include change number and patchset
    # level into the final image name. Hence we check beforehand if we have all
    # information to generate the image name.
    #
    # We need to have either:
    # * both change number AND patchset number
    # * a refspec from which we extract changeset number and patchset
    # therefore we have to fail both cases fail.
    #
    if [[ ! (( -n "${GERRIT_CHANGE_NUMBER:-}"
              && -n "${GERRIT_PATCHSET_NUMBER:-}" )
             || -n "${GERRIT_REFSPEC:-}" ) ]]; then
        echo -n "Neither GERRIT_REFSPEC nor GERRIT_CHANGE_NUMBER/" >&2
        echo -n "GERRIT_PATCHSET_NUMBER specified " >&2
        echo    "for testing build." >&2
        exit 1
    fi
fi

# source file for early validation
SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# For testing changesets, see if user supplied a custom build cache with
# `USE_CACHE_NAME=<name>`. If not, check if there is a saved build cache from a
# previous build of this changeset and use that as build cache. If the comment
# contains `NO_FAILED_CACHE` we do nothing, i.e. we use the default cache.
if [ "${CONTAINER_BUILD_TYPE}" = "testing" ] \
    && [ -n "${GERRIT_EVENT_COMMENT_TEXT:-}" ]; then

    tmpfile_comment="$(mktemp)"

    echo "${GERRIT_EVENT_COMMENT_TEXT}" | base64 -d > "${tmpfile_comment}"

    if ! grep -q "\bNO_FAILED_CACHE\b" "${tmpfile_comment}"; then
        if grep -q "\bUSE_CACHE=" "${tmpfile_comment}"; then
            # use specified cache
            BUILD_CACHE_NAME="$(sed -nE \
                -e "s:.*\<USE_CACHE_NAME=(\S*)\>.*:\1:gp"
                "${tmpfile_comment}")"
            export BUILD_CACHE_NAME
        else
            latest_failed_build_cache="$(get_latest_failed_build_cache_name)"

            # If there is no previous build cache the while loop will terminate
            # immedately and build_num be zero.
            if [ -n "${latest_failed_build_cache}" ]; then
                export BUILD_CACHE_NAME="${latest_failed_build_cache}"
            fi
        fi
    fi
    rm "${tmpfile_comment}"
fi

# store environment for usage within container
env > "${JENKINS_ENV_FILE}"
