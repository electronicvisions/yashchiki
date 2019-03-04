#!/bin/bash -x

# prepare spack as root during container setup

set -euo pipefail

# spack stuff
# home has to exist, so we simply point ot /opt/spack
adduser spack --uid 888 --no-create-home --home /opt/spack --disabled-password --system --shell /bin/bash
chown spack:nogroup /opt
mkdir /opt/spack_views
chown spack:nogroup /opt/spack_views
chmod go=rwx /opt
# in the final image /opt/spack* should be owned by the spack user.
# Therefore: chown everything to the spack user except for var/cache (contains
# hardlinks to vis_jenkins-owned files)
find "/opt/spack_${SPACK_BRANCH}" \
    \( -type d -wholename "/opt/spack_${SPACK_BRANCH}/var/spack/cache" -prune \
    \) -o -exec chown spack:nogroup '{}' \;
chmod +x /opt/spack_install_scripts/*.sh
# symbolic link for convenience
ln -s "/opt/spack_${SPACK_BRANCH}" /opt/spack
# have a convenience folder to easily execute other shells for user
# sessions independent of any app
mkdir /opt/shell
chown spack:nogroup /opt/shell
