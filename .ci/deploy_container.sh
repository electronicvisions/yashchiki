#!/bin/bash -x

set -euo pipefail

echo "deploying container to /containers"

INSTALL_DIR="/containers/${CONTAINER_BUILD_TYPE}"
IMAGE_NAME="singularity_spack_temp.img"
DATE=$(date --iso)

get_container_name()
{
    local local_num="$1"
    if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
        local change_num
        local patch_level
        if [ -z "${GERRIT_CHANGE_NUMBER}" ]; then
            if [ ! -z "${GERRIT_REFSPEC}" ]; then
                # extract gerrit change number from refspec
                change_num="$(echo ${GERRIT_REFSPEC} | cut -f 4 -d / )"
                patch_level="$(echo ${GERRIT_REFSPEC} | cut -f 5 -d / )"
            fi
        else
            change_num="${GERRIT_CHANGE_NUMBER}"
            patch_level="${GERRIT_PATCHSET_NUMBER}"
        fi
        echo -n "${INSTALL_DIR}/c${change_num}p${patch_level}_${local_num}.img"
    else
        echo -n "${INSTALL_DIR}/${DATE}_${local_num}.img"
    fi
}

# find unused image name
num=1
while [[ -e "$(get_container_name ${num})" ]] ; do
    let num++
done

CONTAINER_NAME="$(get_container_name ${num})"

# copy to target
cp -v "${IMAGE_NAME}" ${CONTAINER_NAME}

if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    echo "Linking latest.."
    ln -sfv "./$(basename ${CONTAINER_NAME})" /containers/stable/latest
fi
