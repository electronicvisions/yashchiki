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

# store environment for usage within container
env > "${JENKINS_ENV_FILE}"
