#!/bin/bash -x

set -euo pipefail

# NOTE: stdout of this script is parsed within the Jenkinsfile.
#       Think twice before adding any output!


INSTALL_DIR="/containers/${CONTAINER_BUILD_TYPE}"
FALLBACK_DIR="${HOME}/container_mount_full"
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
# this must be the only output for Jenkins to pick up the container path
# in order to trigger the downstream software builds in the correct container
echo $CONTAINER_NAME

# copy to target
cp "${IMAGE_NAME}" "${CONTAINER_NAME}" || (
    echo "Error: Copy failed because the mount point is full, saving container image to fallback location.." >&2
    cp -v "${IMAGE_NAME}" "${FALLBACK_DIR}/$(basename "${CONTAINER_NAME}")" >&2
    exit 1
)

if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    ln -sf "./$(basename ${CONTAINER_NAME})" /containers/stable/latest
fi

# delete temporary image
rm "${IMAGE_NAME}"
