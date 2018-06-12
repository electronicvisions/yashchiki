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

RECIPE_FILENAME="${WORKSPACE}/visionary_recipe.def"

# create container description file
# * based on Debian stretch (minimal) + a few extra packages (e.g. git, python, ...)
# * bind mount spack's fetch-cache and ccache into the container -> speed up stuff
# * copy spack installation script into container
# * create "spack" user in the container and run spack installation script as spack user
#   (-> installs to /opt/spack_SPACK_BRANCH, and creates views)
# * provide "apps" which set environment variables to appropriate views
cat <<EOF >${RECIPE_FILENAME}
bootstrap: debootstrap
MirrorURL: http://httpredir.debian.org/debian
OSVersion: stretch
Include: git-core, curl, ca-certificates, python, procps, gcc, g++, file, make, patch, libc6-dev, xz-utils, lbzip2, sudo, ssh, unzip, libusb-1.0-0-dev, ccache, vim-nox, less

%environment
    export LANG=C
    export LC_ALL=C

%setup
    mv ${WORKSPACE}/spack_${SPACK_BRANCH}/ \${SINGULARITY_ROOTFS}/opt/
    mkdir \${SINGULARITY_ROOTFS}/opt/download_cache
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind ${WORKSPACE}/download_cache \${SINGULARITY_ROOTFS}/opt/download_cache
    mount --no-mtab --bind ${WORKSPACE}/ccache \${SINGULARITY_ROOTFS}/opt/ccache

%files
    ${SOURCE_DIR}/install_visionary_spack.sh install_visionary_spack.sh
    ${WORKSPACE}/path_spack_tmpdir path_spack_tmpdir

%post
    adduser spack --no-create-home --disabled-password --system --shell /bin/bash
    chown spack:nogroup /opt
    chmod go=rwx /opt
    chown -R spack:nogroup /opt/spack_${SPACK_BRANCH}
    chmod +x /install_visionary_spack.sh
    export SPACK_BRANCH=${SPACK_BRANCH}
    sudo -Eu spack /install_visionary_spack.sh
EOF

# create appenvs for all views...
for view in visionary-defaults visionary-defaults-testing visionary-defaults-analysis visionary-defaults-developmisc visionary-defaults-dls visionary-defaults-simulation visionary-defaults-spikey visionary-defaults-wafer; do

    # append apps for each spackview...
cat <<EOF >>${RECIPE_FILENAME}

%appenv ${view}
    export VISIONARY_ENV=${view}\${VISIONARY_ENV:+:}\${VISIONARY_ENV}
    SVF=/opt/spack_${SPACK_BRANCH}/spackview_\${VISIONARY_ENV}
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
