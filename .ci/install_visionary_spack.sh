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
    $VISIONARY_GCC
)
install_from_buildcache

# upgrade to newer gcc
echo "INSTALL NEW GCC"
${MY_SPACK_BIN} install --show-log-on-error -j$(nproc) ${VISIONARY_GCC}

# add fresh compiler to spack
${MY_SPACK_BIN} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-${VISIONARY_GCC_VERSION}-*

# the version of dev tools we want in our view
SPEC_VIEW_VISIONARY_DEV_TOOLS="visionary-dev-tools^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"

# check if it can be specialized
spack_packages=(
    "visionary-defaults^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-defaults+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-analysis~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-analysis^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "${SPEC_VIEW_VISIONARY_DEV_TOOLS}"
    "visionary-dls~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-dls^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-dls~dev+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-dls+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-nux~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-nux^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-simulation~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-simulation^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-spikey~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-spikey^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer~dev+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer-visu %${VISIONARY_GCC}"
    "visionary-dls-demos^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-slurmviz^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
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
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis visionary-analysis+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis-without-dev visionary-analysis~dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis-without-dev ${VISIONARY_GCC}

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls visionary-dls+dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls gccxml
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev visionary-dls~dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos visionary-dls-demos
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey visionary-spikey+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey-without-dev visionary-spikey~dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey-without-dev ${VISIONARY_GCC}

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer visionary-wafer+dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer gccxml
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev visionary-wafer~dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev ${VISIONARY_GCC}
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation "visionary-simulation+dev %${VISIONARY_GCC}"
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation-without-dev "visionary-simulation~dev %${VISIONARY_GCC}"

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-slurmviz "visionary-slurmviz %${VISIONARY_GCC}"

# ensure that only one version of visionary-dev-tools is installed as view even
# if several are installed due to different contstraints in other packages
hash_visionary_dev_tools="$(${MY_SPACK_BIN} spec -L ${SPEC_VIEW_VISIONARY_DEV_TOOLS} | awk ' $2 ~ /^visionary-dev-tools/ { print $1 }')"
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dev-tools "/${hash_visionary_dev_tools}"

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
