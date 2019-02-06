#!/bin/bash -x

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

GITLOG="git_log_yashchiki.txt"
( cd ${SOURCE_DIR} && git log > "${WORKSPACE}/${GITLOG}" )

RECIPE_FILENAME="${WORKSPACE}/visionary_recipe.def"

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
Include: ca-certificates, ccache, curl, file, g++, gawk, gcc, git-core, lbzip2, less, libc6-dev, locales, make, netbase, patch, procps, python, ssh, sudo, udev, unzip, xz-utils

%setup
    mv ${WORKSPACE}/spack_${SPACK_BRANCH}/ \${SINGULARITY_ROOTFS}/opt/
    # bind-mount ccache
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind ${HOME}/spack_ccache \${SINGULARITY_ROOTFS}/opt/ccache
    # bind-mount build_cache
    mkdir \${SINGULARITY_ROOTFS}/opt/build_cache
    mount --no-mtab --bind -o ro ${HOME}/build_cache \${SINGULARITY_ROOTFS}/opt/build_cache
    # bind-mount tmp-folder
    mkdir -p "\${SINGULARITY_ROOTFS}/tmp/spack"
    mount --no-mtab --bind "${JOB_TMP_SPACK}" "\${SINGULARITY_ROOTFS}/tmp/spack"
    # lockfiles folder
    mkdir \${SINGULARITY_ROOTFS}/opt/lock
    mount --no-mtab --bind ${HOME}/lock \${SINGULARITY_ROOTFS}/opt/lock
    # copy install scripts
    mkdir \${SINGULARITY_ROOTFS}/opt/spack_install_scripts
    rsync -av ${SOURCE_DIR}/*.sh \${SINGULARITY_ROOTFS}/opt/spack_install_scripts/

%files
    ${WORKSPACE}/${GITLOG} ${GITLOG}
    # provide spack command to login shells
    ${WORKSPACE}/misc-files/setup-spack.sh /etc/profile.d/
    ${WORKSPACE}/misc-files/locale.gen /etc/
    ${WORKSPACE}/misc-files/sudoers /etc

%post
    # cannot specify permissions in %files section
    chmod 440 /etc/sudoers
    chown root:root /etc/sudoers
    # install locales
    locale-gen
    # propagate environment variables to container recipe
    export DEPENDENCY_PYTHON="${DEPENDENCY_PYTHON}"
    export VISIONARY_GCC="${VISIONARY_GCC}"
    export VISIONARY_GCC_VERSION="${VISIONARY_GCC_VERSION}"
    export SPACK_BRANCH=${SPACK_BRANCH}
    /opt/spack_install_scripts/install_system_dependencies.sh
    /opt/spack_install_scripts/prepare_spack_as_root.sh
    sudo -Eu spack /opt/spack_install_scripts/bootstrap_spack.sh
    sudo -Eu spack /opt/spack_install_scripts/install_visionary_spack.sh
    sudo -Eu spack /opt/spack_install_scripts/restore_spack_user_settings.sh
EOF

# create appenvs for all views...
for view in "${spack_views[@]}"; do

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
