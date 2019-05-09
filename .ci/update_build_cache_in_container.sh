#!/bin/bash -x
#
# General plan of action:
#
# Create a hard-linked copy, update that copy and only copy new additions back.
# This ensure minimum locking time.
#

set -euo pipefail

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

source /opt/spack/share/spack/setup-env.sh
export SPACK_SHELL="bash"

# we need the temporary folder to reside in the same filesystem as the original
# build cache in order to use hard links
BUILD_CACHE_TEMP="$(mktemp -d "${BUILD_CACHE_INSIDE}/tmp-XXXXXXXXXX")"

rm_build_cache_temp() {
    rm -rfv "${BUILD_CACHE_TEMP}"
}
trap rm_build_cache_temp EXIT

exec {lock_fd}>"${BUILD_CACHE_LOCK}"
if [ -d "${BUILD_CACHE_INSIDE}/build_cache" ]; then
echo "Obtaining build_cache lock."
flock ${lock_fd}
echo "Lock obtained, making hardlinked copy."
rsync -av --link-dest="${BUILD_CACHE_INSIDE}/build_cache" "${BUILD_CACHE_INSIDE}/build_cache/" "${BUILD_CACHE_TEMP}/build_cache"
flock -u ${lock_fd}
fi

# we store all hashes currently installed
hashes_to_store="$(spack find -L | awk '/^[a-z0-9]/ { print "/"$1; }' | tr '\n' ' ')"
# TODO: verify that buildcache -j reads from default config, if not -> add
spack --verbose buildcache create --only package -d "${BUILD_CACHE_TEMP}" -j$(nproc) ${hashes_to_store}

echo "Obtaining build_cache lock."
flock ${lock_fd}
echo "Lock obtained, syncing copies."
rsync -av --link-dest="${BUILD_CACHE_TEMP}/build_cache" "${BUILD_CACHE_TEMP}/build_cache/" "${BUILD_CACHE_INSIDE}/build_cache"
flock -u ${lock_fd}
