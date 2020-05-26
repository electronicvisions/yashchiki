#!/bin/bash -x

set -euo pipefail

# NOTE: stdout of this script is parsed within the Jenkinsfile.
#       Think twice before adding any output!

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

INSTALL_DIR="/containers/${CONTAINER_BUILD_TYPE}"
FALLBACK_DIR="${HOME}/container_mount_full"
IMAGE_NAME="singularity_spack_temp.img"
DATE=$(date --iso)

get_container_name()
{
    local local_num="$1"
    if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
        echo -n "${INSTALL_DIR}/$(get_change_name)_${DATE}_${local_num}.img"
    else
        echo -n "${INSTALL_DIR}/${DATE}_${local_num}.img"
    fi
}

# find unused image name
num=1
while [[ -e "$(get_container_name ${num})" ]] ; do
    (( num++ ))
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

    # Announce new container in "Building & Deployment" channel
    # Since the output of this script is used in other parts, we have to hide curl's output
    export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
    export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

    curl -i -X POST -H 'Content-Type: application/json' \
        -d "{\"text\": \"@channel New stable container built: \`${CONTAINER_NAME}\`\"}" \
        https://chat.bioai.eu/hooks/iuhwp9k3h38c3d98uhwh5fxe9h &>/dev/null

    # extract dna
    container_basename="$(basename ${CONTAINER_NAME})"
    container_basename="${container_basename%%.*}"

    /container/utils/extract_dna.sh -c "${CONTAINER_NAME}" -d "/containers/dna/${container_basename}"
fi

# delete temporary image
rm "${IMAGE_NAME}"
