#!/bin/bash -x
#
# Some early checks to make sure all needed environment variables are defined.
#
if [ -z "${SPACK_BRANCH}" ]; then
    echo "SPACK_BRANCH not set!" >&2
    exit 1
fi

if [ "${CONTAINER_BUILD_TYPE}" != "testing" ] && \
        [ "${CONTAINER_BUILD_TYPE}" != "stable" ]; then
    echo "CONTAINER_BUILD_TYPE needs to be 'testing' or 'stable'!" >&2
    exit 1
fi

if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
    if [[ -z "${GERRIT_CHANGE_NUMBER}" &&
        ( -z "${GERRIT_REFSPEC}" || -z "${GERRIT_PATCHSET_NUMBER}" )
        ]]; then
        echo -n "Neither GERRIT_REFSPEC nor GERRIT_CHANGE_NUMBER/GERRIT_PATCHSET_NUMBER specified " >&2
        echo    "for testing build." >&2
        exit 1
    fi
fi
