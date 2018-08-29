#!/bin/bash -x

SOURCE_FOLDER="stats"

TARGET_FOLDER="/containers/stats"
NAME_FILTER="*.sh"


if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    find "${TARGET_FOLDER}" -name "${NAME_FILTER}" -delete
    find "${SOURCE_FOLDER}" -name "${NAME_FILTER}" -print0 \
        | xargs -0 cp -vt "${TARGET_FOLDER}"
fi

