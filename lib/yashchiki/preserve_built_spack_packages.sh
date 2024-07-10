#!/bin/bash

# This script tries to save all successfully built spack packages to fallback
# location in case of a builderror.
# An administrator can then decide to (temporarily) add them to the buildcache.
#
# This is useful in situations in which, after several hours, one spack package
# fails to build but all packages built up to that point might be perfectly
# fine.
#
# Packages should be added to the buildcache preliminary (e.g., via symlinks)
# until it has been established that they have indeed been built correctly.
#
# Additionally, a temporary build cache is created under
# failed/c<num>p<num>_<num> that contains a union of the current build cache
# and all successfully built packages via symlinks (see
# lib/yashchiki/create_temporary_build_cache_after_failure.sh).

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

# find empty directory to dump into
build_num=1
while /bin/true; do
    target_folder="${PRESERVED_PACKAGES_INSIDE}/${YASHCHIKI_BUILD_CACHE_ON_FAILURE_NAME}_${build_num}"

    if [ ! -d "${target_folder}" ]; then
        break
    else
        (( build_num++ ))
    fi
done

mkdir -p "${target_folder}"

"${sourcedir}/update_build_cache_in_container.sh" -d "${target_folder}" -q -j ${YASHCHIKI_JOBS} || /bin/true  # do not fail!

# preserve the specs that were concretized
pushd "${SPEC_FOLDER_IN_CONTAINER}"
XZ_DEFAULTS="-T0" tar cfJ "${target_folder}/spack_specs.tar.xz" . || /bin/true
popd

# dump the temp folder to the preserved packages folder to help diagnostics
XZ_DEFAULTS="-T0" tar cfJ "${target_folder}/tmp_spack.tar.xz" "${SPACK_TMPDIR}" || /bin/true
