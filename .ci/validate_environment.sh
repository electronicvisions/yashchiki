#!/bin/bash
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
#
# Also we check if the gerrit comment message contains a spack change with
# which we should build specified via `WITH_SPACK_CHANGE=<change-id>`.
GERRIT_SPECIFIED_SPACK_CHANGE=""
GERRIT_SPECIFIED_SPACK_REFSPEC=""
if [ "${CONTAINER_BUILD_TYPE}" = "testing" ] \
    && [ -n "${GERRIT_EVENT_COMMENT_TEXT:-}" ]; then

    tmpfile_comment="$(mktemp)"

    echo "${GERRIT_EVENT_COMMENT_TEXT}" | base64 -d > "${tmpfile_comment}"

    if grep -q "\bWITH_DEBUG\b" "${tmpfile_comment}"; then
        export YASHCHIKI_DEBUG=enabled
        set_debug_output_from_env
    fi

    if ! grep -q "\bNO_FAILED_CACHE\b" "${tmpfile_comment}"; then
        if grep -q "\bUSE_CACHE_NAME=" "${tmpfile_comment}"; then
            # use specified cache
            BUILD_CACHE_NAME="$(sed -nE \
                -e "s:.*\<USE_CACHE_NAME=(\S*)\>.*:\1:gp" \
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

    if grep -q "WITH_SPACK_CHANGE" "${tmpfile_comment}"; then
        GERRIT_SPECIFIED_SPACK_CHANGE="$(sed -nE \
            -e "s:.*\<WITH_SPACK_CHANGE=(\S*)\>.*:\1:gp" \
            "${tmpfile_comment}")"

    elif grep -q "WITH_SPACK_REFSPEC" "${tmpfile_comment}"; then
        GERRIT_SPECIFIED_SPACK_REFSPEC="$(sed -nE \
            -e "s:.*\<WITH_SPACK_REFSPEC=(\S*)\>.*:\1:gp" \
            "${tmpfile_comment}")"
    fi

    rm "${tmpfile_comment}"
fi
export GERRIT_SPECIFIED_SPACK_CHANGE
export GERRIT_SPECIFIED_SPACK_REFSPEC

# store environment for usage within container
echo "# Jenkins environment set to:" >&2
env | tee "${JENKINS_ENV_FILE}"
