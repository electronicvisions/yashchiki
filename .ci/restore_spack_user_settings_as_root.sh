#!/bin/bash
#
# Restore settings that are used during build but should be reset for the end
# user
#

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"

# shrink image: remove download cache (owned by host-user)
rm -rf "${MY_SPACK_FOLDER}"/var/spack/cache/*
chown spack:$spack_gid "${MY_SPACK_FOLDER}"/var/spack/cache
