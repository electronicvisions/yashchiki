#!/bin/bash
#
# This script governs the whole spack install procedure.
# It is needed because the post-install routine is executed in sh which has
# limited capabilities of preserving built spack packages in case of an error.
#

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

"${SPACK_INSTALL_SCRIPTS}/prepare_spack.sh"

trap "${SPACK_INSTALL_SCRIPTS}/preserve_built_spack_packages.sh" ERR
"${SPACK_INSTALL_SCRIPTS}/install_dependencies.sh"
"${SPACK_INSTALL_SCRIPTS}/install_spack_packages.sh"

${MY_SPACK_CMD} compiler add --scope site /usr/bin

"${SPACK_INSTALL_SCRIPTS}/restore_spack_user_settings.sh"
# remove temporary cache folder
rm -rfv /opt/spack/.spack

"${SPACK_INSTALL_SCRIPTS}/generate_modules.sh"
