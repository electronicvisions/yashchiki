#!/bin/bash
#
# Restore settings that are used during build but should be reset for the end
# user
#

set -euo pipefail
shopt -s inherit_errexit

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"

# shrink image: remove download cache (owned by vis_jenkins)
rm -rf "${MY_SPACK_FOLDER}"/var/spack/cache/*
chown spack:nogroup "${MY_SPACK_FOLDER}"/var/spack/cache
