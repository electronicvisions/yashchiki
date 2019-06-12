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


# we store all hashes currently installed that are not already in the buildcache
get_hashes_to_store() {
    comm -13 <(get_hashes_in_buildcache) <(get_hashes_in_spack)
}

exec {lock_fd}>"${BUILD_CACHE_LOCK}"
echo "Obtaining build_cache lock."
flock ${lock_fd}

get_hashes_to_store \
    | parallel --eta -j$(nproc) \
        tar Pcfz "${BUILD_CACHE_INSIDE}/{}.tar.gz" \"\$\(spack location -i /{}\)\"

# verify integrity
find "${BUILD_CACHE_INSIDE}" -name "*.tar.gz" -print0 \
    | parallel -0 -j$(nproc) "tar Ptf '{}' 1>/dev/null"

echo "Releasing build cache lock."
flock -u ${lock_fd}
