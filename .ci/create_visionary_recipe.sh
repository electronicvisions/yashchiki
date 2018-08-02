#!/bin/bash -x

if [ -z "${SPACK_BRANCH}" ]; then
    echo "SPACK_BRANCH variable isn't set!"
    exit 1
fi

if [ -z "${WORKSPACE}" ]; then
    echo "WORKSPACE variable isn't set!"
    exit 1
fi

SOURCE_DIR=$(dirname "$0")

GITLOG="git_log_yashchiki.txt"
( cd ${SOURCE_DIR} && git log > "${WORKSPACE}/${GITLOG}" )

RECIPE_FILENAME="${WORKSPACE}/visionary_recipe.def"

views=( visionary-defaults
        visionary-defaults-analysis
        visionary-defaults-developmisc
        visionary-defaults-dls
        visionary-defaults-simulation
        visionary-defaults-spikey
        visionary-defaults-wafer
        )

# create container description file
# * based on Debian stretch (minimal) + a few extra packages (e.g. git, python, ...)
# * bind mount spack's fetch-cache and ccache into the container -> speed up stuff
# * bind mount spack's buildcache into the container -> speed up stuff
# * copy spack installation script into container
# * create "spack" user in the container and run spack installation script as spack user
#   (-> installs to /opt/spack_SPACK_BRANCH, and creates views)
# * provide "apps" which set environment variables to appropriate views
cat <<EOF >${RECIPE_FILENAME}
bootstrap: debootstrap
MirrorURL: http://httpredir.debian.org/debian
OSVersion: stretch
Include: ca-certificates, ccache, curl, file, g++, gcc, git-core, iproute2, lbzip2, less, libc6-dev, libusb-1.0-0-dev, make, patch, procps, python, ssh, sudo, unzip, vim-nox, xz-utils

%environment
    export LANG=C
    export LC_ALL=C

%setup
    mv ${WORKSPACE}/spack_${SPACK_BRANCH}/ \${SINGULARITY_ROOTFS}/opt/
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind ${WORKSPACE}/ccache \${SINGULARITY_ROOTFS}/opt/ccache
    mkdir \${SINGULARITY_ROOTFS}/opt/build_cache
    mount --no-mtab --bind ${WORKSPACE}/build_cache \${SINGULARITY_ROOTFS}/opt/build_cache

%files
    ${SOURCE_DIR}/install_visionary_spack.sh install_visionary_spack.sh
    ${WORKSPACE}/path_spack_tmpdir path_spack_tmpdir
    ${WORKSPACE}/${GITLOG} ${GITLOG}
    # provide spack command to login shells
    ${WORKSPACE}/misc-files/setup-spack.sh /etc/profile.d/

%post
    adduser spack --no-create-home --home /tmp/spack --disabled-password --system --shell /bin/bash
    chown spack:nogroup /opt
    mkdir /opt/spack_views
    chown spack:nogroup /opt/spack_views
    chmod go=rwx /opt
    chown -R spack:nogroup /opt/spack_${SPACK_BRANCH}
    chmod +x /install_visionary_spack.sh
    export SPACK_BRANCH=${SPACK_BRANCH}
    # symbolic link for convenience
    ln -s /opt/spack_\${SPACK_BRANCH} /opt/spack
    sudo -Eu spack /install_visionary_spack.sh
EOF

# create appenvs for all views...
for view in "${views[@]}"; do

    # append apps for each spackview...
cat <<EOF >>${RECIPE_FILENAME}

%appenv ${view}
    # there can only be one app loaded at any time
    export VISIONARY_ENV=${view}
    SVF=/opt/spack_views/\${VISIONARY_ENV}
    export PATH=\${SVF}/bin\${PATH:+:}\${PATH}
    export PYTHONPATH=\${SVF}/lib/python2.7/site-packages\${PYTHONPATH:+:}\${PYTHONPATH}
    export PYTHONUSERBASE=\${SVF}\${PYTHONUSERBASE:+:}\${PYTHONUSERBASE}
    export MANPATH=\${SVF}/man:\${SVF}/share/man\${MANPATH:+:}\${MANPATH}
    export LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LIBRARY_PATH:+:}\${LIBRARY_PATH}
    export LD_LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LD_LIBRARY_PATH:+:}\${LD_LIBRARY_PATH}
    export TCLLIBPATH=\${SVF}/lib\${TCLLIBPATH:+:}\${TCLLIBPATH}
    export CPATH=\${SVF}/include:/usr/include\${CPATH:+:}\${CPATH}
    export C_INCLUDE_PATH=\${SVF}/include\${C_INCLUDE_PATH:+:}\${C_INCLUDE_PATH}
    export CPLUS_INCLUDE_PATH=\${SVF}/include\${CPLUS_INCLUDE_PATH:+:}\${CPLUS_INCLUDE_PATH}
    export PKG_CONFIG_PATH=\${SVF}/lib/pkgconfig:\${SVF}/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:}\${PKG_CONFIG_PATH}
    export CMAKE_PREFIX_PATH=\${SVF}\${CMAKE_PREFIX_PATH:+:}\${CMAKE_PREFIX_PATH}
EOF
done
