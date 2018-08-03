#!/bin/bash -x

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
${MY_SPACK_BIN} bootstrap

# add build_cache
${MY_SPACK_BIN} mirror add --scope site build_mirror file://${BUILD_CACHE_DIR}

# extract all available package hashes from buildcache
find ${BUILD_CACHE_DIR} -name "*.spec.yaml" | sed 's/.*-\([^-]*\)\.spec\.yaml$/\1/' | sort | uniq > package_hashes_in_buildcache_uniq

function install_from_buildcache {
    echo "" > spack_packages_hashes
    for package in "${spack_packages[@]}"; do
        ${MY_SPACK_BIN} spec -y ${package} | tee tmp_file
        cat tmp_file | sed -n 's/.*hash:\s*\(.*\)/\1/p' >> spack_packages_hashes
    done

    # make each unique
    cat spack_packages_hashes | sort | uniq > spack_packages_hashes_uniq

    # install if available in buildcache
    for available_package in $(cat spack_packages_hashes_uniq package_hashes_in_buildcache_uniq | sort | uniq -d); do
        ${MY_SPACK_BIN} buildcache install -y /${available_package} || true
    done
}

# check if it can be specialized
spack_packages=(
    "gcc@7.2.0"
)
install_from_buildcache

# upgrade to newer gcc
echo "INSTALL NEW GCC"
${MY_SPACK_BIN} install gcc@7.2.0

# add fresh compiler to spack
${MY_SPACK_BIN} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-7.2.0-*

# check if it can be specialized
spack_packages=(
    "visionary-defaults %gcc@7.2.0"
    "visionary-defaults+gccxml %gcc@7.2.0"
    "visionary-defaults+tensorflow %gcc@7.2.0"
    "visionary-defaults-analysis+dev %gcc@7.2.0"
    "visionary-defaults-dev-tools %gcc@7.2.0"
    "visionary-defaults-dls+dev %gcc@7.2.0"
    "visionary-defaults-dls+dev+gccxml %gcc@7.2.0"
    "visionary-defaults-simulation+dev %gcc@7.2.0"
    "visionary-defaults-spikey+dev %gcc@7.2.0"
    "visionary-defaults-wafer+dev %gcc@7.2.0"
    "visionary-defaults-wafer+dev+gccxml %gcc@7.2.0"
    "visionary-dls-demos %gcc@7.2.0"
)
# tensorflow fails
# visionary-defaults-nux
install_from_buildcache

echo "INSTALLING PACKAGES"
for package in "${spack_packages[@]}"; do
    ${MY_SPACK_BIN} install ${package} || ( echo "FAILED TO INSTALL: ${package}" | tee -a ${MY_SPACK_FOLDER}/install_failed.log )
done

# create the filesystem views (exposed via singularity --app option)
echo "CREATING VIEWS OF META PACKAGES"
cd ${MY_SPACK_FOLDER}

# make views writable for non-spack users in container
OLD_UMASK=$(umask)
umask 000

# hack to allow "tensorflow" to fail build -> FIXME!
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults visionary-defaults~tensorflow~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults gccxml
${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults tensorflow

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-analysis visionary-defaults-analysis+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-analysis gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-dls visionary-defaults-dls+dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-dls gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-dls gccxml

#${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-nux visionary-defaults-nux

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos visionary-dls-demos
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-simulation visionary-defaults-simulation+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-simulation gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-spikey visionary-defaults-spikey+dev
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-spikey gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-wafer visionary-defaults-wafer+dev~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-wafer gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-wafer gccxml

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
