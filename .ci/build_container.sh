#!/bin/bash -x

# set generic locale for building
export LANG=C
export LC_ALL=C

echo "creating visionary-recipe.def"
SOURCE_DIR=$(dirname "$0")
${SOURCE_DIR}/create_visionary_recipe.sh || exit 1

# create some jenkins-owned temp folder for spack build
mkdir /tmp/spack || true

# remove temporary stuff from previous runs
mktemp -d -p /tmp/spack/ > path_spack_tmpdir
SPACK_TMPDIR=$(cat path_spack_tmpdir)

if [ -z "${SPACK_TMPDIR}" ]; then
    echo "SPACK_TMPDIR not set?!?"
    exit 1
fi

# provide permissions
chmod 1777 ${SPACK_TMPDIR}

# build the container (using scripts from above)
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

TARGET_FOLDER="sandboxes/stretch_spack_${SPACK_BRANCH}"

# Do not change: special sudo permit for jenkins user...
sudo rm -rf sandboxes/ || exit 1

mkdir sandboxes || exit 1

# Do not change: special sudo permit for jenkins user...
sudo -E singularity build --sandbox ${TARGET_FOLDER} visionary_recipe.def || exit 1

# create image file
IMAGE_NAME=singularity_spack_${SPACK_BRANCH}.img
sudo singularity build ${IMAGE_NAME} ${TARGET_FOLDER}
sudo chown -R vis_jenkins singularity_spack_*.img

# after building we can delete our spack tmp folder
sudo rm -rf ${SPACK_TMPDIR}/ || exit 1

# update global ccache (via diffs) and delete files not present anymore to
# prevent cache from growing endlessly
rsync -av --delete ${PWD}/ccache/ ${HOME}/ccache/
