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
        visionary-dev-tools
        visionary-analysis
        visionary-analysis-without-dev
        visionary-dls
        visionary-dls-without-dev
        visionary-simulation
        visionary-simulation-without-dev
        visionary-spikey
        visionary-spikey-without-dev
        visionary-wafer
        visionary-wafer-without-dev
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
Include: ca-certificates, ccache, cpio, curl, file, fxload, g++, gawk, gcc, git-core, iproute2, iptables, iputils-ping, lbzip2, less, libc6-dev, libusb-dev, libusb-1.0-0-dev, locales, make, netbase, net-tools, patch, procps, python, ssh, strace, sudo, udev, unzip, vim-nox, xz-utils, zsh

%setup
    mv ${WORKSPACE}/spack_${SPACK_BRANCH}/ \${SINGULARITY_ROOTFS}/opt/
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind ${WORKSPACE}/ccache \${SINGULARITY_ROOTFS}/opt/ccache
    mkdir \${SINGULARITY_ROOTFS}/opt/build_cache
    mount --no-mtab --bind -o ro ${HOME}/build_cache \${SINGULARITY_ROOTFS}/opt/build_cache

%files
    ${SOURCE_DIR}/install_visionary_spack.sh install_visionary_spack.sh
    ${WORKSPACE}/path_spack_tmpdir path_spack_tmpdir
    ${WORKSPACE}/${GITLOG} ${GITLOG}
    # provide spack command to login shells
    ${WORKSPACE}/misc-files/setup-spack.sh /etc/profile.d/
    ${WORKSPACE}/misc-files/locale.gen /etc/
    ${WORKSPACE}/misc-files/sudoers /etc

%post
    # cannot specify permissions in %files section
    chmod 440 /etc/sudoers
    chown root:root /etc/sudoers
    # for premium software (e.g. Xilinx impact)
    ln -s /lib/x86_64-linux-gnu/libusb-0.1.so.4 /lib/x86_64-linux-gnu/libusb.so
    echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list
    apt-get update
    apt-get install -y singularity-container/stretch-backports
    apt-get install -y texlive-full latex-make
    # install locales
    locale-gen
    # spack stuff
    adduser spack --uid 888 --no-create-home --home /tmp/spack --disabled-password --system --shell /bin/bash
    chown spack:nogroup /opt
    mkdir /opt/spack_views
    chown spack:nogroup /opt/spack_views
    chmod go=rwx /opt
    chown -R spack:nogroup /opt/spack_${SPACK_BRANCH}
    chmod +x /install_visionary_spack.sh
    export SPACK_BRANCH=${SPACK_BRANCH}
    # symbolic link for convenience
    ln -s /opt/spack_\${SPACK_BRANCH} /opt/spack
    # have a convenience folder to easily execute other shells for user
    # sessions independent of any app
    mkdir /opt/shell
    chown spack:nogroup /opt/shell
    # propagate environment variables to container recipe
    export DEPENDENCY_PYTHON="${DEPENDENCY_PYTHON}"
    export VISIONARY_GCC="${VISIONARY_GCC}"
    export VISIONARY_GCC_VERSION="${VISIONARY_GCC_VERSION}"
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
    export PYTHONHOME=\${SVF}
    export MANPATH=\${SVF}/man:\${SVF}/share/man\${MANPATH:+:}\${MANPATH}
    export LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LIBRARY_PATH:+:}\${LIBRARY_PATH}
    export LD_LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LD_LIBRARY_PATH:+:}\${LD_LIBRARY_PATH}
    export TCLLIBPATH=\${SVF}/lib\${TCLLIBPATH:+:}\${TCLLIBPATH}
    export CPATH=\${SVF}/include\${CPATH:+:}\${CPATH}
    export C_INCLUDE_PATH=\${SVF}/include\${C_INCLUDE_PATH:+:}\${C_INCLUDE_PATH}
    export CPLUS_INCLUDE_PATH=\${SVF}/include\${CPLUS_INCLUDE_PATH:+:}\${CPLUS_INCLUDE_PATH}
    export PKG_CONFIG_PATH=\${SVF}/lib/pkgconfig:\${SVF}/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:}\${PKG_CONFIG_PATH}
    export CMAKE_PREFIX_PATH=\${SVF}\${CMAKE_PREFIX_PATH:+:}\${CMAKE_PREFIX_PATH}
EOF
done
