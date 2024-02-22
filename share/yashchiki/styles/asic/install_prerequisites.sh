#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

# This file is to install all packages that are a pre-requisite for spack to be
# installed.

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
    ccache \
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
    parallel \
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
