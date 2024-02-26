#!/bin/bash

ROOT_DIR="$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")"
SOURCE_FOLDER="${ROOT_DIR}/share/yashchiki/utils"

TARGET_FOLDER="/containers/utils"
NAME_FILTER=( "(" -name "*.py" -or -name "*.sh" ")" )

if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    find "${TARGET_FOLDER}" "${NAME_FILTER[@]}" -delete
    find "${SOURCE_FOLDER}" "${NAME_FILTER[@]}" -print0 \
        | xargs -n 1 -0 "${ROOT_DIR}/lib/yashchiki/deploy_utility_with_preamble.sh" "${TARGET_FOLDER}"
fi
