#!/bin/bash

# prepare spack as root during container setup

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# spack stuff
# home has to exist, so we simply point ot /opt/spack
spack_create_user_cmd
chown spack:$spack_gid /opt
mkdir /opt/spack_views
chown spack:$spack_gid /opt/spack_views
mkdir -p "${SPEC_FOLDER_IN_CONTAINER}"
chown spack:$spack_gid "${SPEC_FOLDER_IN_CONTAINER}"
chown spack:$spack_gid "${BUILD_CACHE_INSIDE}"
chmod go=rwx /opt
# in the final image /opt/spack* should be owned by the spack user.
# Therefore: chown everything to the spack user except for var/cache (contains
# hardlinks to host-user-owned files)
find "/opt/spack" \
    \( -type d -wholename "/opt/spack/var/spack/cache" -prune \
    \) -o -exec chown spack:$spack_gid '{}' \;
chmod +x /opt/spack_install_scripts/*.sh
# have a convenience folder to easily execute other shells for user
# sessions independent of any app
mkdir /opt/shell
chown spack:$spack_gid /opt/shell
