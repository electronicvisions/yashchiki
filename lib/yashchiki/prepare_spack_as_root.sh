#!/bin/bash

# prepare spack as root during container setup

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# spack stuff
mkdir /opt/spack_views
mkdir -p "${SPEC_FOLDER_IN_CONTAINER}"
chmod go=rwx /opt
chmod +x /opt/spack_install_scripts/*.sh
# have a convenience folder to easily execute other shells for user
# sessions independent of any app
mkdir /opt/shell
