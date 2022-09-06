#!/bin/bash

SOURCE_FOLDER="yashchiki/utils"

TARGET_FOLDER="/containers/utils"
NAME_FILTER=( "(" -name "*.py" -or -name "*.sh" ")" )

if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    find "${TARGET_FOLDER}" "${NAME_FILTER[@]}" -delete
    find "${SOURCE_FOLDER}" "${NAME_FILTER[@]}" -print0 \
        | xargs -n 1 -0 "${PWD}/yashchiki/.ci/deploy_utility_with_preamble.sh" "${TARGET_FOLDER}"
fi
