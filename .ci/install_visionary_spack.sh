#!/bin/bash -x
set -euo pipefail

if [ -z "${SPACK_BRANCH}" ]; then
    echo "SPACK_BRANCH variable isn't set!"
    exit 1
fi

SPACK_TMPDIR=$(cat /path_spack_tmpdir)
# TODO: check for empty folder

export OLD_HOME=$HOME
export HOME=${SPACK_TMPDIR}/home
export TMPDIR=${SPACK_TMPDIR}/tmp
export MY_SPACK_BRANCH=${SPACK_BRANCH}
export MY_SPACK_FOLDER=/opt/spack_${SPACK_BRANCH}
export MY_SPACK_BIN=/opt/spack_${SPACK_BRANCH}/bin/spack
export CCACHE_DIR="/opt/ccache"
export BUILD_CACHE_DIR="/opt/build_cache"
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

if [ ! -d ${MY_SPACK_FOLDER} ]; then
    echo "${MY_SPACK_FOLDER} does not exist!"
    exit 1
fi

if [ ! -d ${CCACHE_DIR} ]; then
    echo "${CCACHE_DIR} does not exist!"
    exit 1
fi

if [ ! -d ${BUILD_CACHE_DIR} ]; then
    echo "${BUILD_CACHE_DIR} does not exist!"
    exit 1
fi

mkdir -p $HOME
mkdir -p $TMPDIR
chmod 1777 $TMPDIR

# pip alterrrr
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

cd $HOME

# default size of ccache is lower than typically needed for a complete
# visionary spack environment -> 25.0GiB seems reasonable :)
if [ ! -f "${CCACHE_DIR}/ccache.conf" ]; then
    echo "max_size = 25.0G" > ${CCACHE_DIR}/ccache.conf
fi

ccache -s

# activate ccache
sed -i 's/ccache: false/ccache: true/' ${MY_SPACK_FOLDER}/etc/spack/defaults/config.yaml

# add system compiler
${MY_SPACK_BIN} compiler add --scope site /usr/bin

# provide spack support for environment modules
echo "BOOTSTRAPPING"
${MY_SPACK_BIN} bootstrap -j$(nproc)

# add build_cache
${MY_SPACK_BIN} mirror add --scope site build_mirror file://${BUILD_CACHE_DIR}

# setup tempfiles
FILE_HASHES_BUILDCACHE=$(mktemp)
FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE=$(mktemp)
FILE_HASHES_SPACK=$(mktemp)
FILE_HASHES_SPACK_ALL=$(mktemp)

# extract all available package hashes from buildcache
find ${BUILD_CACHE_DIR} -name "*.spec.yaml" | sed 's/.*-\([^-]*\)\.spec\.yaml$/\1/' | sort | uniq > ${FILE_HASHES_BUILDCACHE}

function install_from_buildcache {
    echo "" > ${FILE_HASHES_SPACK_ALL}
    for package in "${spack_packages[@]}"; do
        ${MY_SPACK_BIN} spec -y ${package} | sed -n 's/.*hash:\s*\(.*\)/\1/p' >> ${FILE_HASHES_SPACK_ALL}
    done

    # make each unique
    cat ${FILE_HASHES_SPACK_ALL} | sort | uniq > ${FILE_HASHES_SPACK}

    # install if available in buildcache
    cat ${FILE_HASHES_SPACK} ${FILE_HASHES_BUILDCACHE} | sort | uniq -d > ${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}
    hashes_to_install=$(sed "s:^:/:g" < ${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE} | tr '\n' ' ')
    ${MY_SPACK_BIN} buildcache install -y -w -j$(nproc) ${hashes_to_install} || true
}

# check if it can be specialized
spack_packages=(
    "gcc@7.2.0"
)
install_from_buildcache

# upgrade to newer gcc
echo "INSTALL NEW GCC"
${MY_SPACK_BIN} install --show-log-on-error -j$(nproc) gcc@7.2.0

# add fresh compiler to spack
${MY_SPACK_BIN} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-7.2.0-*

# check if it can be specialized
spack_packages=(
    "visionary-defaults^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-defaults+gccxml^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-analysis~dev^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-analysis^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-dev-tools^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-dls~dev^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-dls^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-dls~dev+gccxml^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-dls+gccxml^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-nux~dev^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-nux^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-simulation~dev^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-simulation^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-spikey~dev^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-spikey^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-wafer~dev^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-wafer^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-wafer~dev+gccxml^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-wafer+gccxml^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-wafer-visu %gcc@7.2.0"
    "visionary-dls-demos^${DEPENDENCY_PYTHON} %gcc@7.2.0"
    "visionary-slurmviz^${DEPENDENCY_PYTHON} %gcc@7.2.0"
)
# tensorflow fails
install_from_buildcache

echo "INSTALLING PACKAGES"
for package in "${spack_packages[@]}"; do
    ${MY_SPACK_BIN} install --show-log-on-error -j$(nproc) ${package}
done

# create the filesystem views (exposed via singularity --app option)
echo "CREATING VIEWS OF META PACKAGES"
cd ${MY_SPACK_FOLDER}

# make views writable for non-spack users in container
OLD_UMASK=$(umask)
umask 000

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults visionary-defaults~tensorflow~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis visionary-analysis+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis gcc@7.2.0
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis-without-dev visionary-analysis~dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis-without-dev gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls visionary-dls+dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls gccxml
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev visionary-dls~dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos visionary-dls-demos
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey visionary-spikey+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey gcc@7.2.0
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey-without-dev visionary-spikey~dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey-without-dev gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer visionary-wafer+dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer gccxml
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev visionary-wafer~dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation "visionary-simulation+dev %gcc@7.2.0"
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation-without-dev "visionary-simulation~dev %gcc@7.2.0"

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dev-tools "visionary-dev-tools %gcc@7.2.0"

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-slurmviz "visionary-slurmviz %gcc@7.2.0"

umask ${OLD_UMASK}

# rebuild all modules
${MY_SPACK_BIN} module refresh -y

# non-spack user/group shall be allowed to read/execute everything we installed here
chmod -R o+rX ${MY_SPACK_VIEW_PREFIX}/*
chmod -R o+rX opt

# allow non-spack users to install new packages
# Note: modified packages can be loaded by bind-mounting the /var-subdirectory
# of a locally checked out spack-repo at /opt/spack_${SPACK_BRANCH} in the container
chmod 777 ${MY_SPACK_FOLDER}/opt/spack/{*/*,*,}

# shrink image: remove downloaded packages from container and usesless links in the stage area
rm -rf ${MY_SPACK_FOLDER}/var/spack/{cache,stage}/*

# set permissions for local users to install files
# this includes any lockfiles that might have been left over
# TODO: revisit this strategy again once https://github.com/spack/spack/pull/8014 is implemented!
#       the user could simply stack the container-repo ontop of a locally mounted one
chmod -R 777 ${MY_SPACK_FOLDER}/var/spack/{cache,stage}
# locks and indices have to be writable for local user when trying to install
chmod -R 777 ${MY_SPACK_FOLDER}/opt/spack/.spack-db
# module files also need to be updated if the user installs packages
chmod -R 777 ${MY_SPACK_FOLDER}/share/spack/modules

# Have convience symlinks for shells for user sessions so that they can be
# executed via:
# $ singularity shell -s /opt/shell/${SHELL} /containers/stable/latest
# which is independent of any app. Especially, this allows custom loading of
# modules within the container.
ln -s "$(${MY_SPACK_BIN} location -i zsh)/bin/zsh" /opt/shell/zsh

# remove tempfiles
rm ${FILE_HASHES_BUILDCACHE}
rm ${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}
rm ${FILE_HASHES_SPACK}
rm ${FILE_HASHES_SPACK_ALL}
