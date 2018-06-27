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
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

if [ ! -d ${MY_SPACK_FOLDER} ]; then
    echo "${MY_SPACK_FOLDER} does not exist!"
    exit 1
fi

if [ ! -d ${CCACHE_DIR} ]; then
    echo "${CCACHE_DIR} does not exist!"
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

# upgrade to newer gcc
echo "INSTALL NEW GCC"
${MY_SPACK_BIN} install gcc@7.2.0

${MY_SPACK_BIN} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-7.2.0-*

# print stats
ccache -s

# check if it can be specialized
echo "SHOW SPEC OF META PACKAGES"
${MY_SPACK_BIN} spec -I visionary-defaults || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults+gccxml || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults+tensorflow || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults-analysis || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults-developmisc || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults-dls || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults-simulation || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults-spikey || exit 1
${MY_SPACK_BIN} spec -I visionary-defaults-wafer || exit 1

# do the work... (FIXME: we ignore fail of tensorflow for now)
echo "INSTALLING META PACKAGES"
${MY_SPACK_BIN} install visionary-defaults || exit 1
${MY_SPACK_BIN} install visionary-defaults+gccxml || exit 1
${MY_SPACK_BIN} install visionary-defaults+tensorflow

${MY_SPACK_BIN} install visionary-defaults-analysis || exit 1

${MY_SPACK_BIN} install visionary-defaults-developmisc || exit 1

${MY_SPACK_BIN} install visionary-defaults-dls || exit 1
${MY_SPACK_BIN} install visionary-defaults-dls+gccxml || exit 1

#${MY_SPACK_BIN} install visionary-defaults-nux

${MY_SPACK_BIN} install visionary-defaults-simulation || exit 1

${MY_SPACK_BIN} install visionary-defaults-spikey || exit 1

${MY_SPACK_BIN} install visionary-defaults-wafer || exit 1
${MY_SPACK_BIN} install visionary-defaults-wafer+gccxml || exit 1

${MY_SPACK_BIN} install visionary-dls-demos || exit 1

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

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-analysis visionary-defaults-analysis
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-analysis gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-developmisc visionary-defaults-developmisc
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-developmisc gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-dls visionary-defaults-dls~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-dls gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-dls gccxml

#${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-nux visionary-defaults-nux

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos visionary-dls-demos
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos gccxml

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-simulation visionary-defaults-simulation
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-simulation gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-spikey visionary-defaults-spikey
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-spikey gcc@7.2.0

${MY_SPACK_BIN} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-wafer visionary-defaults-wafer~gccxml
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-wafer gcc@7.2.0
${MY_SPACK_BIN} view -d no  hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults-wafer gccxml

umask ${OLD_UMASK}

# non-spack user/group shall be allowed to read/execute everything we installed here
chmod -R o+rX ${MY_SPACK_VIEW_PREFIX}/*
chmod -R o+rX opt

# allow non-spack users to install new packages
# Note: modified packages can be loaded by bind-mounting the /var-subdirectory
# of a locally checked out spack-repo at /opt/spack_${SPACK_BRANCH} in the container
chmod 777 ${MY_SPACK_FOLDER}/opt/spack/{*/*,*,}

# shrink image: remove downloaded packages from container
rm -rf ${MY_SPACK_FOLDER}/var/spack/cache/*
