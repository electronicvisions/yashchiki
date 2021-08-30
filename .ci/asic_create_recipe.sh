#!/bin/bash

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

RECIPE_FILENAME="${WORKSPACE}/asic_recipe.def"

# create container description file
# * based on CentOS 7's docker image
# * just manually install everything we need
cat <<EOF >"${RECIPE_FILENAME}"
Bootstrap: docker
From: ${DOCKER_BASE_IMAGE}

%setup
    # bind-mount spack-folder as moving involves copying the complete download cache
    mkdir \${SINGULARITY_ROOTFS}/opt/spack
    mount --no-mtab --bind "${WORKSPACE}/spack" "\${SINGULARITY_ROOTFS}/opt/spack"
    # bind-mount ccache
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind "${HOME}/spack_ccache" "\${SINGULARITY_ROOTFS}/opt/ccache"
    # bind-mount build_cache
    mkdir -p "\${SINGULARITY_ROOTFS}${BUILD_CACHE_INSIDE}"
    # create buildcache directory if it does not exist
    [ ! -d "${BUILD_CACHE_OUTSIDE}" ] && mkdir -p "${BUILD_CACHE_OUTSIDE}"
    # mount the full build cache folder into container because some files might be symlinked to other buildcaches
    mount --no-mtab --bind "${BASE_BUILD_CACHE_OUTSIDE}" "\${SINGULARITY_ROOTFS}${BASE_BUILD_CACHE_INSIDE}"
    # bind-mount preserved packages in case the build fails
    mkdir -p "\${SINGULARITY_ROOTFS}${PRESERVED_PACKAGES_INSIDE}"
    mount --no-mtab --bind "${PRESERVED_PACKAGES_OUTSIDE}" "\${SINGULARITY_ROOTFS}${PRESERVED_PACKAGES_INSIDE}"
    # bind-mount tmp-folder
    mkdir -p "\${SINGULARITY_ROOTFS}/tmp/spack"
    mount --no-mtab --bind "${JOB_TMP_SPACK}" "\${SINGULARITY_ROOTFS}/tmp/spack"
    # copy install scripts
    mkdir "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${SOURCE_DIR}"/*.sh "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${SOURCE_DIR}"/*.awk "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${SOURCE_DIR}"/pinned "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${SOURCE_DIR}"/patches "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    mkdir -p "\${SINGULARITY_ROOTFS}/${META_DIR_INSIDE}"
    rsync -av "${META_DIR_OUTSIDE}"/* "\${SINGULARITY_ROOTFS}/${META_DIR_INSIDE}"
    # init scripts for user convenience
    mkdir -p "\${SINGULARITY_ROOTFS}/opt/init"
    rsync -av "${WORKSPACE}"/misc-files/init/*.sh "\${SINGULARITY_ROOTFS}/opt/init"

%files
    # NOTE: Due to a bug in singularity 2.6 all paths in this section _cannot_
    # be surrounded in quotes.. ergo there should be no spaces in filenames! If
    # there are, I pray for your poor soul that escaping them works..
    # --obreitwi, 17-02-19 # 23:45:51
    # provide spack command to login shells
    ${WORKSPACE}/misc-files/setup-spack.sh /etc/profile.d/setup-spack.sh
    ${WORKSPACE}/misc-files/locale.gen /etc/locale.gen
    ${WORKSPACE}/misc-files/locale.alias /etc/locale.alias
    ${WORKSPACE}/misc-files/sudoers /etc/sudoers
    ${JENKINS_ENV_FILE} ${JENKINS_ENV_FILE_INSIDE}

%post
    # Apparently, upon building the CentOS docker images it has been decided that
    # (for space-saving reasons) exactly one locale (en_US.utf8) is installed.
    # We don't care about the little extra space and user experience benefits from
    # some more locales.
    sed -i '/^override_install_langs/d' /etc/yum.conf
    yum reinstall -y glibc-common

    yum -y install libjpeg-turbo vim-minimal unzip tar rsync SDL-devel autoconf automake bc bison bzip2 chrpath compat-libtiff3 gcc gcc-c++ gdb cups-client dos2unix ed file flex freetype git glib2-devel glibc-devel ksh less libICE libSM libX11-devel libXau-devel libXdamage-devel libXext-devel libXfixes-devel libXrandr libXrender-devel libstdc++-devel lsof m4 make mailx ncurses-devel openssl-devel openssh patch perl psmisc redhat-lsb-core screen socat spax strace sysvinit-tools tcl glibc.i686 diffstat fontconfig gpm-libs libXScrnSaver libXaw libXdmcp libXfont2 libXft libXi libXmu libXpm libXt libXtst libgcc libfontenc libstdc++.i686 libtool libuuid-devel libxkbfile net-tools pax perl-libintl perl-Text-Unidecode pixman python3 python3-pip python3-setuptools qemu-guest-agent tcsh texinfo uuid-devel wget which xkeyboard-config xorg-x11-xauth xorg-x11-xkb-utils xterm xorg-x11-server-Xvfb environment-modules vim-common

    # VK introduced jq into build flow
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    yum -y install jq

    # gtest is F9's C++ test framework of choice
    yum -y install gtest-devel

    # ECM: people (YS) just need pylint, etc. (upgrade to spack if more is needed)
    wget https://repo.anaconda.com/miniconda/Miniconda3-py38_4.8.3-Linux-x86_64.sh
    bash Miniconda3-py38_4.8.3-Linux-x86_64.sh -b -p /opt/conda
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
    /opt/conda/bin/conda install -y pylint pycodestyle nose pyyaml

    # ECM: and now some abspacking
    yum -y install ccache sudo parallel

    # create a fingerprint by which we can identify the container from within
    cat /proc/sys/kernel/random/uuid > /opt/fingerprint

    ## prerequisites
    #"${SPACK_INSTALL_SCRIPTS}/install_prerequisites.sh" || exit 1
    ## cannot specify permissions in files-section
    #chmod 440 /etc/sudoers
    #chown root:root /etc/sudoers
    ## install locales
    #locale-gen
    # propagate environment variables to container recipe
    export DEPENDENCY_PYTHON="${DEPENDENCY_PYTHON}"
    export DEPENDENCY_PYTHON3="${DEPENDENCY_PYTHON3}"
    export VISIONARY_GCC="${VISIONARY_GCC}"
    export VISIONARY_GCC_VERSION="${VISIONARY_GCC_VERSION}"
    export CONTAINER_STYLE="${CONTAINER_STYLE}"
    "${SPACK_INSTALL_SCRIPTS}/complete_spack_install_routine_called_in_post_as_root.sh"
    wait
    "${SPACK_INSTALL_SCRIPTS}/install_singularity_as_root.sh" || \
    (
    sudo -Eu spack "${SPACK_INSTALL_SCRIPTS}/preserve_built_spack_packages.sh" &&
        exit 1  # propagate the error
    )

%environment
    # NOTE: We provide a MODULESHOME in all cases (otherwise a login shell is
    # required to load the module environment)
    MODULESHOME=/usr/share/Modules
    export MODULESHOME

    # CentOS 7 does not support C.UTF-8; unset everything if encountered.
    if [ "${LANG}" = "C.UTF-8" ]; then
        LANG=C
        export LANG
        unset LC_COLLATE LC_CTYPE LC_MONETARY LC_NUMERIC LC_TIME LC_MESSAGES LC_ALL
    fi

    # python now from conda...
    PATH=/opt/conda/bin:${PATH}
    # ensure conda sees a clean env
    unset PYTHONHOME
EOF

# create appenvs for all views...
# append apps for each spackview...
generate_appenv() {
local name_app="$1"
local name_view="$2"
cat <<EOF
%appenv ${name_app}
    # there can only be one app loaded at any time
    export VISIONARY_ENV=${name_view}
    SVF=/opt/spack_views/\${VISIONARY_ENV}
    export PATH=\${SVF}/bin\${PATH:+:}\${PATH}
    # there is no python in asic app for now
    #export PYTHONHOME=\${SVF}
    #export SPACK_PYTHON_BINARY=\${SVF}/bin/python
    export MANPATH=\${SVF}/man:\${SVF}/share/man\${MANPATH:+:}\${MANPATH}
    export LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LIBRARY_PATH:+:}\${LIBRARY_PATH}
    export LD_LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LD_LIBRARY_PATH:+:}\${LD_LIBRARY_PATH}
    export TCLLIBPATH=\${SVF}/lib\${TCLLIBPATH:+:}\${TCLLIBPATH}
    export CPATH=\${SVF}/include\${CPATH:+:}\${CPATH}
    export C_INCLUDE_PATH=\${SVF}/include\${C_INCLUDE_PATH:+:}\${C_INCLUDE_PATH}
    export CPLUS_INCLUDE_PATH=\${SVF}/include\${CPLUS_INCLUDE_PATH:+:}\${CPLUS_INCLUDE_PATH}
    export QUIET_CPATH=\${CPATH}
    export QUIET_C_INCLUDE_PATH=\${C_INCLUDE_PATH}
    export QUIET_CPLUS_INCLUDE_PATH=\${CPLUS_INCLUDE_PATH}
    export PKG_CONFIG_PATH=\${SVF}/lib/pkgconfig:\${SVF}/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:}\${PKG_CONFIG_PATH}
    export CMAKE_PREFIX_PATH=\${SVF}\${CMAKE_PREFIX_PATH:+:}\${CMAKE_PREFIX_PATH}
EOF
}
for view in "${spack_views[@]}"; do
    # generate two apps, one with visionary- prefix for compatability with old
    # scripts and one with stripped visionary- prefix
    (
        generate_appenv "${view}" "${view}"
        [[ "${view}" =~ ^visionary- ]] && generate_appenv "${view#visionary-}" "${view}"
    ) >> "${RECIPE_FILENAME}"

    if [ "${view}" = "visionary-simulation" ];then
cat <<EOF >>"${RECIPE_FILENAME}"
    export NEST_MODULES=visionarymodule
EOF
    fi
done
