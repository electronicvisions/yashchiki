#!/bin/bash

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/asic_dummy_variables.sh"
source "${SOURCE_DIR}/commons.sh"

GITLOG="git_log_yashchiki.txt"
( cd ${SOURCE_DIR} && git log > "${WORKSPACE}/${GITLOG}" )

RECIPE_FILENAME="${WORKSPACE}/asic_recipe.def"

# create container description file
# * based on CentOS 7's docker image
# * just manually install everything we need
cat <<EOF >"${RECIPE_FILENAME}"
Bootstrap: docker
From: ${DOCKER_BASE_IMAGE}

%files
    # NOTE: Due to a bug in singularity 2.6 all paths in this section _cannot_
    # be surrounded in quotes.. ergo there should be no spaces in filenames! If
    # there are, I pray for your poor soul that escaping them works..
    # --obreitwi, 17-02-19 # 23:45:51
    ${WORKSPACE}/${GITLOG} ${GITLOG}

%post
    # Apparently, upon building the CentOS docker images it has been decided that
    # (for space-saving reasons) exactly one locale (en_US.utf8) is installed.
    # We don't care about the little extra space and user experience benefits from
    # some more locales.
    sed -i '/^override_install_langs/d' /etc/yum.conf
    yum reinstall -y glibc-common

    yum -y install libjpeg-turbo vim-minimal unzip tar rsync SDL-devel autoconf automake bc bison bzip2 chrpath gcc gcc-c++ gdb cups-client dos2unix ed file flex freetype git glib2-devel glibc-devel ksh less libICE libSM libX11-devel libXau-devel libXdamage-devel libXext-devel libXfixes-devel libXrandr libXrender-devel libstdc++-devel lsof m4 make mailx ncurses-devel openssl-devel openssh patch perl psmisc redhat-lsb-core screen socat spax strace sysvinit-tools tcl glibc.i686 diffstat fontconfig gpm-libs libXScrnSaver libXaw libXdmcp libXfont2 libXft libXi libXmu libXpm libXt libXtst libgcc libfontenc libstdc++.i686 libtool libuuid-devel libxkbfile net-tools pax perl-libintl perl-Text-Unidecode pixman python3 python3-pip python3-setuptools qemu-guest-agent tcsh texinfo uuid-devel wget which xkeyboard-config xorg-x11-xauth xorg-x11-xkb-utils xterm xorg-x11-server-Xvfb environment-modules vim-common

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
