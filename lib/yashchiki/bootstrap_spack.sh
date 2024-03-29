#!/bin/bash
#
# Prepare spack by bootstrapping and installing the compiler via spack
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

# provide spack support for environment modules
echo "BOOTSTRAPPING"

# add build_cache
${MY_SPACK_CMD} mirror add --scope site build_mirror file://${BUILD_CACHE_DIR}

install_from_buildcache "${spack_bootstrap_dependencies[@]}"

# We install all packages needed by boostrap here
for bootstrap_spec in "${spack_bootstrap_dependencies[@]}"; do
    ${MY_SPACK_CMD} "${SPACK_ARGS_INSTALL[@]+"${SPACK_ARGS_INSTALL[@]}"}" install --no-cache --show-log-on-error "${bootstrap_spec}"
done

num_packages_pre_boostrap="$(${MY_SPACK_CMD} find 2>&1 | head -n 1 | awk '/installed packages/ { print $2 }')"


num_packages_post_boostrap="$(${MY_SPACK_CMD} find 2>&1 | head -n 1 | awk '/installed packages/ { print $2 }')"

if (( num_packages_pre_boostrap < num_packages_post_boostrap )); then
cat <<EOF | tr '\n' ' ' >&2
ERROR: spack bootstrap command did install some packages on its own, this
should not happen, aborting..!
EOF
echo ""
    exit 1
fi

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

    # remove system compilers from spack to avoid conflicting concretization
    echo "$(${MY_SPACK_CMD} compiler list)"
    for system_compiler in ${system_compilers}; do
        ${MY_SPACK_CMD} compiler rm --scope site "${system_compiler}"
    done

    # add fresh compiler to spack
    ${MY_SPACK_CMD} compiler add --scope site ${MY_SPACK_FOLDER}/opt/spack/linux-*/*/gcc-${YASHCHIKI_SPACK_GCC_VERSION}-*
fi
