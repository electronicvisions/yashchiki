#!/bin/bash -x
#
# Prepare spack by bootstrapping and installing the visionary compiler
#
set -euo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

mkdir -p "${HOME}"
mkdir -p "${TMPDIR}"
chmod 1777 ${TMPDIR}

cd $HOME

# set system-wide max-size for ccache to a reasonably big value
if [ ! -f "${CCACHE_DIR}/ccache.conf" ]; then
    echo "max_size = 50.0G" > ${CCACHE_DIR}/ccache.conf
fi

ccache -s

# activate ccache
sed -i '/ccache:/c\  ccache: true' "${MY_SPACK_FOLDER}/etc/spack/defaults/config.yaml"

# build with all available processes
sed -i "/build_jobs:/c\  build_jobs: $(nproc)" "${MY_SPACK_FOLDER}/etc/spack/defaults/config.yaml"

# add system compiler
${MY_SPACK_BIN} compiler add --scope site /usr/bin

# provide spack support for environment modules
echo "BOOTSTRAPPING"

# add build_cache
${MY_SPACK_BIN} mirror add --scope site build_mirror file://${BUILD_CACHE_DIR}

install_from_buildcache "${spack_bootstrap_dependencies[@]}"

${MY_SPACK_BIN} bootstrap -v --no-cache

# check if it can be specialized
install_from_buildcache "${VISIONARY_GCC}"

# upgrade to newer gcc
echo "INSTALL NEW GCC"
${MY_SPACK_BIN} --debug install --no-cache --show-log-on-error "${VISIONARY_GCC}"

# add fresh compiler to spack
${MY_SPACK_BIN} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-${VISIONARY_GCC_VERSION}-*
