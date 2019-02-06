#!/bin/bash -x

set -euo pipefail

# set generic locale for building
export LANG=C
export LC_ALL=C

echo "creating visionary-recipe.def"
SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
"${SOURCE_DIR}/create_visionary_recipe.sh"

# create some jenkins-owned temp folder for spack build
if [ ! -d "${JOB_TMP_SPACK}" ]; then
    echo "${JOB_TMP_SPACK} should exist, aborting!" >&2
    exit 1
fi

# make job temp folder writable for all users (i.e., spack)
chmod 777 "${JOB_TMP_SPACK}"

# build the container (using scripts from above)
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

TARGET_FOLDER="sandboxes/stretch_spack_${SPACK_BRANCH}"

# Do not change: special sudo permit for jenkins user...
sudo rm -rf sandboxes/

mkdir sandboxes

# Do not change: special sudo permit for jenkins user...
sudo -E singularity build --sandbox "${TARGET_FOLDER}" visionary_recipe.def

# create image file
IMAGE_NAME=singularity_spack_temp.img
sudo singularity build ${IMAGE_NAME} "${TARGET_FOLDER}"
sudo chown -R vis_jenkins singularity_spack_*.img
