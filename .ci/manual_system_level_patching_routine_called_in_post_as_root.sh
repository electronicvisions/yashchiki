#!/bin/bash -x
#
# This script governs the whole spack install procedure.
# It is needed because the post-install routine is executed in sh which has
# limited capabilities of preserving built spack packages in case of an error.
#

set -euo pipefail

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

for pn in "${SPACK_INSTALL_SCRIPTS}/patches/*.patch"; do
    patch -p 1 < ${pn}
done
