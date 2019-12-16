#!/bin/bash -lx
# Install nested singularity (needs to be done AFTER modulefiles are
# regenerated!)

set -euo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"
SINGULARITY_REPO="https://github.com/electronicvisions/singularity.git"
SINGULARITY_BRANCH="bugfix/express_delivery_for_sschmitt"  # temporary branch with hotfixes for sschmitt

GO_INSTALL_PATH=/opt/go
GO_VERSION=1.11.5
OS=linux
ARCH=amd64

# --------- 8< ---------- 8< -------- 8< ---------
source /opt/spack/share/spack/setup-env.sh
export SPACK_SHELL=bash

TMP_MODULES=$(mktemp)
rm_tmp_modules() {
    rm -v "${TMP_MODULES}"
}
add_cleanup_step rm_tmp_modules
{
    echo "source /opt/init/modules.sh"
    spack module tcl loads -r "$(get_latest_hash "${VISIONARY_GCC}")"
} | tee "${TMP_MODULES}"
source "${TMP_MODULES}"
# --------- 8< ---------- 8< -------- 8< ---------

# don't use spack, build against debian
apt-get install -y libssl-dev uuid-dev

if [ ! -d "${GO_INSTALL_PATH}" ]; then
    mkdir -p "${GO_INSTALL_PATH}"
fi

# get and install go
pushd "${SPACK_TMPDIR}"
GO_TAR="go${GO_VERSION}.${OS}-${ARCH}.tar.gz"
curl -OLJ "https://dl.google.com/go/${GO_TAR}"
remove_tar() {
    rm -v "${SPACK_TMPDIR}/${GO_TAR}"
}
add_cleanup_step remove_tar
tar -C "${GO_INSTALL_PATH}" -xzf "${GO_TAR}"
popd

# setup environment
export PATH="${GO_INSTALL_PATH}/go/bin${PATH:+:${PATH}}"
export GOPATH="${GO_INSTALL_PATH}/gopath"
if [ ! -d "${GOPATH}}" ]; then
    mkdir -p "${GOPATH}"
fi

# build singularity
# golang is a bit finicky about where things are placed. Here is the correct way to build Singularity from source.
SINGULARITY_INSTALL_PATH="${GOPATH}/src/github.com/sylabs/singularity"
mkdir -p "${SINGULARITY_INSTALL_PATH}/../"
git clone -b "${SINGULARITY_BRANCH}" \
             "${SINGULARITY_REPO}" \
             "${SINGULARITY_INSTALL_PATH}"

pushd "${SINGULARITY_INSTALL_PATH}"
./mconfig -b "${SPACK_TMPDIR}/singularity-builddir" \
    --prefix=/usr/local \
    --localstatedir=/var/lib \
    --sysconfdir=/etc

pushd "${SPACK_TMPDIR}/singularity-builddir"
make && make install
popd

popd
