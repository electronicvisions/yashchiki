#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit

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

export SPACK_VERBOSE=
# source file for early validation
SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# For testing changesets, see if user supplied a custom build cache with
# `WITH_CACHE_NAME=<name>`. If not, check if there is a saved build cache from a
# previous build of this changeset and use that as build cache. If the comment
# contains `WITHOUT_FAILED_CACHE` we do nothing, i.e. we use the default cache.
if [ "${CONTAINER_BUILD_TYPE}" = "testing" ] \
    && [ -n "${GERRIT_EVENT_COMMENT_TEXT:-}" ]; then

    tmpfile_comment="$(mktemp)"

    echo "${GERRIT_EVENT_COMMENT_TEXT}" | base64 -d > "${tmpfile_comment}"

    if grep -q "\bWITH_DEBUG\b" "${tmpfile_comment}"; then
        export YASHCHIKI_DEBUG=enabled
        set_debug_output_from_env
    else
        export YASHCHIKI_DEBUG=""
    fi

    if grep -q "\bWITH_CACHE_NAME=" "${tmpfile_comment}"; then
        # use specified cache
        BUILD_CACHE_NAME="$(sed -nE \
            -e "s:.*\<WITH_CACHE_NAME=(\S*)(\s|$).*:\1:gp" \
            "${tmpfile_comment}")"
        export BUILD_CACHE_NAME
    elif ! grep -q "\bWITHOUT_FAILED_CACHE\b" "${tmpfile_comment}"; then
        latest_failed_build_cache="$(get_latest_failed_build_cache_name)"

        # If there is no previous build cache the while loop will terminate
        # immedately and build_num be zero.
        if [ -n "${latest_failed_build_cache}" ]; then
            export BUILD_CACHE_NAME="${latest_failed_build_cache}"
        fi
    fi

    if grep -q "\bWITH_SPACK_VERBOSE\b" "${tmpfile_comment}"; then
        export SPACK_VERBOSE="enabled"
    else
        export SPACK_VERBOSE=""
    fi

    rm "${tmpfile_comment}"
fi

# store environment for usage within container
echo "# Jenkins environment set to:" >&2
env | tee "${JENKINS_ENV_FILE}"
