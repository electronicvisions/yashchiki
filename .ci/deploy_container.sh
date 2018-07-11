#!/bin/bash -x

echo "deploying container to /containers/jenkins"

INSTALL_DIR=/containers/jenkins
IMAGE_NAME=singularity_spack_${SPACK_BRANCH}.img
DATE=$(date --iso)

get_container_name()
{
    local local_num="$1"
    local cprefix="${CONTAINER_PREFIX}"
    local change_num="undefined"
    if [ "${cprefix}" = "gerrit" ]; then
        if [ -z "${GERRIT_CHANGE_NUMBER}" ]; then
            if [ ! -z "${GERRIT_REFSPEC}" ]; then
                # extract gerrit change number from refspec
                change_num="$(echo ${GERRIT_REFSPEC} | cut -f 4 -d / )"
            fi
        else
            change_num="${GERRIT_CHANGE_NUMBER}"
        fi
        cprefix="${CONTAINER_PREFIX}_cs_${change_num}"
    fi
    echo -n "$INSTALL_DIR/singularity_spack_${cprefix:+${cprefix}_}${SPACK_BRANCH}-${DATE}-${local_num}.img"
}

# find unused image name
num=1
while [[ -e "$(get_container_name ${num})" ]] ; do
    let num++
done

# copy to target
cp -v "${IMAGE_NAME}" "$(get_container_name ${num})"
