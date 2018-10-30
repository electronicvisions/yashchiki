#!/bin/bash -x

SOURCE_FOLDER="utils"

TARGET_FOLDER="/containers/utils"
NAME_FILTER="*.sh"

if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    find "${TARGET_FOLDER}" -name "${NAME_FILTER}" -delete
    find "${SOURCE_FOLDER}" -name "${NAME_FILTER}" -print0 \
        | xargs -n 1 -0 "$(git rev-parse --show-toplevel)/.ci/deploy_utility_with_preamble.sh" "${TARGET_FOLDER}"
fi
