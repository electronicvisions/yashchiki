#!/bin/bash
#
# Install dependencies needed during the spack install
# process and the container creation.
#
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

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

# add system compiler
${MY_SPACK_CMD} compiler add --scope site /usr/bin

# add build_cache
${MY_SPACK_CMD} mirror add --scope site build_mirror file://${BUILD_CACHE_DIR}

if [ ${YASHCHIKI_BUILD_SPACK_GCC} -eq 1 ]; then
    # check if it can be specialized
    spec_compiler="${YASHCHIKI_SPACK_GCC}"
    install_from_buildcache "${spec_compiler}"

    # remember system compiler versions (to be removed later)
    system_compilers="$(${MY_SPACK_CMD} compiler list --scope site | grep \@)"

    # upgrade to newer gcc
    echo "INSTALL NEW GCC"
    set -x
    ${MY_SPACK_CMD} "${SPACK_ARGS_INSTALL[@]}" install --no-cache --show-log-on-error "${spec_compiler}"

    # add fresh compiler to spack
    ${MY_SPACK_CMD} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-${YASHCHIKI_SPACK_GCC_VERSION}-*
fi

echo "INSTALL YASHCHIKI DEPENDENCIES"

install_from_buildcache "${yashchiki_dependencies[@]}"

# We install all packages needed by yashchiki here
for dep_spec in "${yashchiki_dependencies[@]}"; do
    ${MY_SPACK_CMD} "${SPACK_ARGS_INSTALL[@]+"${SPACK_ARGS_INSTALL[@]}"}" install --no-cache --show-log-on-error "${dep_spec}"
done
