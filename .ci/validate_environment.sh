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

if [ "${DEPENDENCY_PYTHON}" != "${SINGULARITYENV_DEPENDENCY_PYTHON}" ]; then
    echo "${DEPENDENCY_PYTHON} will not be successfully set in singularity!" >&2
    echo "\$DEPENDENCY_PYTHON = ${DEPENDENCY_PYTHON}" >&2
    echo "\$SINGULARITYENV_DEPENDENCY_PYTHON = ${SINGULARITYENV_DEPENDENCY_PYTHON}" >&2
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
    if [[ ! (( -n "${GERRIT_CHANGE_NUMBER}"
              && -n "${GERRIT_PATCHSET_NUMBER}" )
             || -n "${GERRIT_REFSPEC}" ) ]]; then
        echo -n "Neither GERRIT_REFSPEC nor GERRIT_CHANGE_NUMBER/" >&2
        echo -n "GERRIT_PATCHSET_NUMBER specified " >&2
        echo    "for testing build." >&2
        exit 1
    fi
fi
