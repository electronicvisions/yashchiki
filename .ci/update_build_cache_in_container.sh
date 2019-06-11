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

exec {lock_fd}>"${BUILD_CACHE_LOCK}"
echo "Obtaining build_cache lock."
flock ${lock_fd}

# get hashes in buildcache
hashes_in_buildcache() {
    if [ -d "${BUILD_CACHE_INSIDE}/build_cache" ]; then
        spack mirror add buildcache "${BUILD_CACHE_INSIDE}" >/dev/null
        spack buildcache list -L | awk '/^[a-z0-9]/ { print "/" $1 }' | sort
        spack mirror remove buildcache >/dev/null
    fi
}

hashes_in_spack() {
    spack find -L | awk '/^[a-z0-9]/ { print "/" $1 }' | sort
}

# we store all hashes currently installed that are not already in the buildcache
hashes_to_store="$(comm -13 <(hashes_in_buildcache) <(hashes_in_spack) | tr '\n' ' ')"
# TODO: verify that buildcache -j reads from default config, if not -> add
# -a: allows root string to still be present in RPATH - this is okay since we
# always install from/to /opt/spack in the container.
spack --verbose buildcache create -a --unsigned --force --only package \
    -d "${BUILD_CACHE_INSIDE}" -j$(nproc) \
    ${hashes_to_store}

echo "Releasing build cache lock."
flock -u ${lock_fd}
