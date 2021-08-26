#!/bin/bash -lx
# Install gocryptfs from source; needed for older base images such as Cent OS 7
# (ASIC container image)


set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"
GOCRYPTFS_REPO="https://github.com/rfjakob/gocryptfs.git"

# go assumed to be provided via install_singularity_as_root.sh; repeat variables
GO_INSTALL_PATH=/opt/go

# setup environment
export PATH="${GO_INSTALL_PATH}/go/bin${PATH:+:${PATH}}"
export GOPATH="${GO_INSTALL_PATH}/gopath"

# build gocryptfs
# this is a go 1.11-based install flow which probably should be adjusted for
# modern go (no need to build from source within the gopath folder anymore)
GOCRYPTFS_INSTALL_PATH="${SPACK_TMPDIR}/gocryptfs"
git clone "${GOCRYPTFS_REPO}" "${GOCRYPTFS_INSTALL_PATH}"

pushd "${GOCRYPTFS_INSTALL_PATH}"
# build and install
./build.bash
popd
