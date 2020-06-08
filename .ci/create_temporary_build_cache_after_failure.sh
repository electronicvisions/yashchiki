#!/bin/bash -x

# This script creates a temporary build cache via symlinks in
# failed/c<num>p<num>_<num>.
#
# It streamlines container deployment as every container deployment will
# restart at the last sucessfully built package.

if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
    echo "Stable container creation failed, this should not happen." >&2
    exit 1
fi

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

build_num=1
change_num="$(get_change_name)"

while [ -d "${PRESERVED_PACKAGES_OUTSIDE}/${change_num}_${build_num}" ]; do
    (( build_num++ ))
done
(( build_num-- ))

preserved_packages="${PRESERVED_PACKAGES_OUTSIDE}/${change_num}_${build_num}"
failed_build_cache="${BASE_BUILD_CACHE_FAILED_OUTSIDE}/${change_num}_${build_num}"

# expects input to be \0-printed
link_into_failed_buildcache() {
    xargs -0 -r realpath "--relative-to=${failed_build_cache}" \
    | xargs -r ln -sv -t "${failed_build_cache}"
}

# ensure that we have preserved packages and that these packages have not
# already been pushed to a failed build cache
if (( build_num > 0 )) && \
    [ ! -d "${BASE_BUILD_CACHE_FAILED_OUTSIDE}/${change_num}_${build_num}" ]; then

    mkdir -p "${failed_build_cache}"

    # link all newly preserved packages (relatively so links work in and
    # outside of containers)
    find "${preserved_packages}" -name "*.tar.gz" -print0 | link_into_failed_buildcache

    # link everything not present in preserved packages that is in build cache
    find "${BUILD_CACHE_OUTSIDE}" -name "*.tar.gz" -print0 | link_into_failed_buildcache
fi
