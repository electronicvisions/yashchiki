#!/bin/bash

ROOT_DIR="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")")")")"
source "${ROOT_DIR}/lib/yashchiki/commons.sh"

# create container description file
# * based on CentOS 7's docker image
# * just manually install everything we need
cat <<EOF >"${YASHCHIKI_RECIPE_PATH}"
Bootstrap: docker
From: ${DOCKER_BASE_IMAGE}

%setup
    # bind-mount spack-folder as moving involves copying the complete download cache
    mkdir \${SINGULARITY_ROOTFS}/opt/spack
    mount --no-mtab --bind "${YASHCHIKI_SPACK_PATH}" "\${SINGULARITY_ROOTFS}/opt/spack"
    # bind-mount ccache
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind "${YASHCHIKI_CACHES_ROOT}/spack_ccache" "\${SINGULARITY_ROOTFS}/opt/ccache"
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
    # bind-mount spack config tmp-folder
    mkdir -p "\${SINGULARITY_ROOTFS}/tmp/spack_config"
    mount --no-mtab --bind "${YASHCHIKI_SPACK_CONFIG}" "\${SINGULARITY_ROOTFS}/tmp/spack_config"
    # copy install scripts
    mkdir "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av --chmod 0755 "${ROOT_DIR}"/share/yashchiki/styles/${CONTAINER_STYLE}/*.sh "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av --chmod 0755 "${ROOT_DIR}"/lib/yashchiki/*.sh "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${ROOT_DIR}"/lib/yashchiki/*.awk "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${ROOT_DIR}"/share/yashchiki/patches "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    mkdir -p "\${SINGULARITY_ROOTFS}/${META_DIR_INSIDE}"
    rsync -av "${META_DIR_OUTSIDE}/" "\${SINGULARITY_ROOTFS}/${META_DIR_INSIDE}"
    # init scripts for user convenience
    mkdir -p "\${SINGULARITY_ROOTFS}/opt/init"
    rsync -av "${ROOT_DIR}"/share/yashchiki/misc-files/init/*.sh "\${SINGULARITY_ROOTFS}/opt/init"

%files
    # NOTE: Due to a bug in singularity 2.6 all paths in this section _cannot_
    # be surrounded in quotes.. ergo there should be no spaces in filenames! If
    # there are, I pray for your poor soul that escaping them works..
    # --obreitwi, 17-02-19 # 23:45:51
    # provide spack command to login shells
    ${ROOT_DIR}/share/yashchiki/misc-files/setup-spack.sh /etc/profile.d/setup-spack.sh
    ${ROOT_DIR}/share/yashchiki/misc-files/locale.gen /etc/locale.gen
    ${ROOT_DIR}/share/yashchiki/misc-files/locale.alias /etc/locale.alias
    ${ROOT_DIR}/share/yashchiki/misc-files/sudoers /etc/sudoers

%post
    # ECM: drop docker image caches (often outdated)
    yum clean all

    # ECM: disable http caching
    echo "http_caching=none" >> /etc/yum.conf

    # ECM: enable strict mode to fail when packages are not found (or other installation problems appear)
    echo "skip_missing_names_on_install=0" >> /etc/yum.conf

    yum -y upgrade

    # install additional locales
    yum install -y "glibc-langpack-*"

    # EPEL is needed for fuse-sshfs and jq
    dnf -y install dnf-plugins-core  # needed for `dnf config-manager`
    dnf config-manager --set-enabled powertools  # powertools is needed by epel-release
    dnf -y install epel-release

    yum -y install \
        apr \
        apr-devel \
        apr-util \
        apr-util-devel \
        autoconf \
        automake \
        bc \
        binutils-devel \
        bison \
        bzip2 \
        chrpath \
        compat-libtiff3 \
        compat-openssl10 \
        cups-client \
        diffstat \
        dos2unix \
        ed \
        elfutils-libelf \
        environment-modules \
        expat-devel \
        file \
        flex \
        fontconfig \
        freetype \
        freetype-devel \
        gcc \
        gcc-c++ \
        gcc-gfortran \
        gdb \
        git \
        glib2-devel \
        glibc-devel \
        glibc-devel.i686 \
        glibc.i686 \
        gpm-libs \
        ksh \
        less \
        libffi-devel \
        libfontenc \
        libgcc \
        libgfortran \
        libgcrypt-devel \
        libICE \
        libjpeg-turbo \
        libmng \
        libnsl \
        libnsl.i686 \
        libpng12 \
        libpng15 \
        libSM \
        libstdc++-devel \
        libstdc++-static \
        libstdc++.i686 \
        libtool \
        libtool-ltdl-devel \
        libuuid-devel \
        libX11-devel \
        libXau-devel \
        libXaw \
        libXdamage-devel \
        libXdmcp \
        libXext-devel \
        libXfixes-devel \
        libXfont2 \
        libXft \
        libXi \
        libxkbfile \
        libxml2-devel \
        libXmu \
        libXp \
        libXpm \
        libXrandr \
        libXrender-devel \
        libXScrnSaver \
        libXt \
        libXtst \
        libyaml-devel \
        lsof \
        m4 \
        mailx \
        make \
        mesa-dri-drivers \
        mesa-libGL \
        mesa-libGLU \
        motif \
        ncurses-devel \
        net-tools \
        numactl-libs \
        openssh \
        openssl-devel \
        patch \
        patchelf \
        perl \
        perl-libintl \
        perl-Text-Unidecode \
        pixman \
        psmisc \
        pulseaudio-libs \
        pulseaudio-libs-glib2 \
        python2 \
        python2-devel \
        python39 \
        python39-devel \
        python39-pip \
        python39-setuptools \
        qemu-guest-agent \
        redhat-lsb \
        rsync \
        screen \
        SDL-devel \
        socat \
        spax \
        fuse-sshfs \
        strace \
        tar \
        tcl \
        tcsh \
        texinfo \
        unzip \
        uuid-devel \
        vim-common \
        vim-minimal \
        wget \
        which \
        xkeyboard-config \
        xorg-x11-fonts-100dpi \
        xorg-x11-fonts-75dpi \
        xorg-x11-fonts-ISO8859-1-100dpi \
        xorg-x11-fonts-ISO8859-1-75dpi \
        xorg-x11-fonts-misc \
        xorg-x11-fonts-Type1 \
        xorg-x11-server-Xvfb \
        xorg-x11-xauth \
        xorg-x11-xkb-utils \
        xterm \
        zlib \
        zlib.i686

    # VK introduced jq into build flow
    yum -y install jq

    # gtest is F9's C++ test framework of choice
    yum -y install gtest-devel

    # ECM: and now some abspacking
    yum -y install ccache sudo parallel

    # ECM: and userspace mount stuff
    yum -y install fuse3

    # ECM: save some more space
    yum clean all

    alternatives --set python /usr/bin/python3.9

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
    export YASHCHIKI_BUILD_SPACK_GCC="${YASHCHIKI_BUILD_SPACK_GCC}"
    export YASHCHIKI_SPACK_GCC="${YASHCHIKI_SPACK_GCC}"
    export YASHCHIKI_SPACK_GCC_VERSION="${YASHCHIKI_SPACK_GCC_VERSION}"
    export YASHCHIKI_JOBS="${YASHCHIKI_JOBS}"
    export YASHCHIKI_SPACK_CONFIG="/tmp/spack_config"
    export YASHCHIKI_CACHES_ROOT="${YASHCHIKI_CACHES_ROOT}"
    export YASHCHIKI_BUILD_CACHE_NAME="${YASHCHIKI_BUILD_CACHE_NAME}"
    export YASHCHIKI_BUILD_CACHE_ON_FAILURE_NAME="${YASHCHIKI_BUILD_CACHE_ON_FAILURE_NAME}"
    export YASHCHIKI_SPACK_VERBOSE="${YASHCHIKI_SPACK_VERBOSE}"
    export CONTAINER_STYLE="${CONTAINER_STYLE}"
    "${SPACK_INSTALL_SCRIPTS}/complete_spack_install_routine_called_in_post_as_root.sh"
    wait
    (
        "${SPACK_INSTALL_SCRIPTS}/install_singularity_as_root.sh" && \
        "${SPACK_INSTALL_SCRIPTS}/install_gocryptfs_as_root.sh"
    ) || \
    (
    sudo -Eu spack "${SPACK_INSTALL_SCRIPTS}/preserve_built_spack_packages.sh" &&
        exit 1  # propagate the error
    )

%environment
    # NOTE: We provide a MODULESHOME in all cases (otherwise a login shell is
    # required to load the module environment)
    MODULESHOME=/usr/share/Modules
    export MODULESHOME

    # gopath/bin (gocryptfs)
    PATH=/opt/go/gopath/bin:\${PATH}
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
    # externally provided python, i.e. PYTHONHOME is system installation
    export -n PYTHONHOME
    export PYTHONPATH=\${SVF}/lib/python3.9/site-packages:\${SVF}/lib64/python3.9/site-packages\${PYTHONPATH:+:}\${PYTHONPATH}
    export SPACK_PYTHON_BINARY=/usr/bin/python
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
    export PKG_CONFIG_PATH=\${SVF}/lib/pkgconfig:\${SVF}/lib64/pkgconfig:\${SVF}/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:}\${PKG_CONFIG_PATH}
    export CMAKE_PREFIX_PATH=\${SVF}\${CMAKE_PREFIX_PATH:+:}\${CMAKE_PREFIX_PATH}
EOF
}
for view in "${spack_views[@]}"; do
    # generate two apps, one with visionary- prefix for compatability with old
    # scripts and one with stripped visionary- prefix
    (
        generate_appenv "${view}" "${view}"
        [[ "${view}" =~ ^visionary- ]] && generate_appenv "${view#visionary-}" "${view}"
    ) >> "${YASHCHIKI_RECIPE_PATH}"

    if [ "${view}" = "visionary-asic" ];then
cat <<EOF >>"${YASHCHIKI_RECIPE_PATH}"
    export IVERILOG_VPI_MODULE_PATH=\${SVF}/lib/myhdl/share
EOF
    fi
done
