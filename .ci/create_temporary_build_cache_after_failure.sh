#!/bin/bash

# This script creates a temporary build cache via symlinks in
# failed/c<num>p<num>_<num>.
#
# It streamlines container deployment as every container deployment will
# restart at the last sucessfully built package.
#
# Echoes path to created cache relative to build_caches base directory.

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
# `build_num` is used to indicate if no preserved packages were found: After
# the loop, `build_num` will be one higher than the last folder with
# preserved_packages found. Hence, if no folder was found, it will still be 1
# -> setting it to 0 encodes that we found no preserved_packages that we should
# store in the failed cache.
(( build_num-- ))

preserved_packages="${PRESERVED_PACKAGES_OUTSIDE}/${change_num}_${build_num}"
failed_build_cache="${BASE_BUILD_CACHE_FAILED_OUTSIDE}/${change_num}_${build_num}"

# expects input to be \0-printed
link_into_failed_buildcache() {
    xargs -0 -r realpath "--relative-to=${failed_build_cache}" \
    | xargs -r ln -sv -t "${failed_build_cache}" >&2
}

# ensure that we have preserved packages and that these packages have not
# already been pushed to a failed build cache
if (( build_num > 0 )) && \
    [ ! -d "${BASE_BUILD_CACHE_FAILED_OUTSIDE}/${change_num}_${build_num}" ]; then

    mkdir -vp "${failed_build_cache}" >&2

    # link all newly preserved packages (relatively so links work in and
    # outside of containers)
    find "${preserved_packages}" -name "*.tar.gz" -print0 | link_into_failed_buildcache

    # link everything not present in preserved packages that is in build cache
    find "${BUILD_CACHE_OUTSIDE}" -name "*.tar.gz" -print0 | link_into_failed_buildcache

    # echo created failed buildcache
    echo "${failed_build_cache#${BASE_BUILD_CACHE_OUTSIDE}}"
else
    echo "<no preserved packages found>"
fi
