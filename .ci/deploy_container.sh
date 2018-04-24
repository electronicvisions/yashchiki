#!/bin/bash -x

echo "deploying container to /containers/jenkins"

INSTALL_DIR=/containers/jenkins
IMAGE_NAME=singularity_spack_${SPACK_BRANCH}.img
DATE=$(date --iso)

# find unused image name
num=1
while [[ -e "$INSTALL_DIR/singularity_spack_${SPACK_BRANCH}-${DATE}-${num}.img" ]] ; do
    let num++
done

# copy to target
cp -v ${IMAGE_NAME} "$INSTALL_DIR/singularity_spack_${SPACK_BRANCH}-${DATE}-${num}.img"
