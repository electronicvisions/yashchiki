#!/bin/bash -x
#
# Restore settings that are used during build but should be reset for the end
# user
#

set -euo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

# rebuild all modules
${MY_SPACK_BIN} module tcl refresh -y

# non-spack user/group shall be allowed to read/execute everything we installed here
chmod -R o+rX "${MY_SPACK_VIEW_PREFIX}"
# remember: var/spack/cache still contains hardlinked files owned by
# vis_jenkins-user
find "${MY_SPACK_FOLDER}" \
    \( -type d -wholename "${MY_SPACK_FOLDER}/var/spack/cache" -prune \
    \) -o -not -type l -exec chmod o+rX '{}' \;

# allow non-spack users to install new packages
# Note: modified packages can be loaded by bind-mounting the /var-subdirectory
# of a locally checked out spack-repo at /opt/spack in the container
find "${MY_SPACK_FOLDER}" -mindepth 0 -maxdepth 2 -type d -print0 | xargs -0 chmod 777

# module files need to be updated if the user installs packages (if they exist)
chmod -R 777 ${MY_SPACK_FOLDER}/share/spack/modules || /bin/true

# remove build_cache again
${MY_SPACK_BIN} mirror rm --scope site build_mirror

# disable ccache after everything has been build -> make manual spack overlay
# builds oe step less manual
sed -i '/ccache:/c\  ccache: false'\
    "${MY_SPACK_FOLDER}/etc/spack/defaults/config.yaml"

# Restore default build_jobs setting
sed -i '/build_jobs:/c\  # build_jobs: 4'\
    "${MY_SPACK_FOLDER}/etc/spack/defaults/config.yaml"
