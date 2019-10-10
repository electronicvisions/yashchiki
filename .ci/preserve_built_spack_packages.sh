#!/bin/bash -x

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

set -euo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

# find empty directory to dump into
build_num=1
while /bin/true; do
    target_folder="${PRESERVED_PACKAGES_INSIDE}/$(get_compact_name)_${build_num}"

    if [ ! -d "${target_folder}" ]; then
        break
    else
        (( build_num++ ))
    fi
done

mkdir -p "${target_folder}"

"${sourcedir}/update_build_cache_in_container.sh" -d "${target_folder}" -q
