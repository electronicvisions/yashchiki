#!/bin/bash -x

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
    yum -y install vim-minimal unzip tar rsync SDL-devel autoconf automake bc bison bzip2 chrpath gcc gcc-c++ gdb cups-client dos2unix ed file flex freetype git glib2-devel glibc-devel ksh less libICE libSM libX11-devel libXau-devel libXdamage-devel libXext-devel libXfixes-devel libXrandr libXrender-devel libstdc++-devel lsof m4 make mailx ncurses-devel openssl-devel openssh patch perl psmisc redhat-lsb-core screen socat spax strace sysvinit-tools tcl glibc.i686 diffstat fontconfig gpm-libs libXScrnSaver libXaw libXdmcp libXfont2 libXft libXi libXmu libXpm libXt libXtst libgcc libfontenc libstdc++.i686 libtool libuuid-devel libxkbfile net-tools pax perl-libintl perl-Text-Unidecode pixman python3 python3-pip python3-setuptools qemu-guest-agent tcsh texinfo uuid-devel wget which xkeyboard-config xorg-x11-xauth xorg-x11-xkb-utils xterm xorg-x11-server-Xvfb
EOF