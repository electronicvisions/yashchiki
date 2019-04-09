#!/bin/bash -x

set -euo pipefail

# This file is to install all packages needed from apt that are not required by
# spack in order to bootstrap itself.

system_dependencies=(
        "corkscrew"
        "cpio"
        "fxload"
        "iproute2"
        "iptables"
        "iputils-ping"
        "latex-make"
        "latexmk"
        "libcap2-bin"
        "libusb-1.0-0-dev"
        "libusb-dev"
        "linux-perf"
        "lshw"
        "man-db"
        "net-tools"
        "strace"
        "texlive"
        "texlive-lang-german"
        "texlive-latex-extra"
        "tsocks"
        "usbutils"
        "vim-nox"
        "xz-utils"
        "zsh"
    )
# for premium software (e.g. Xilinx impact)
ln -s /lib/x86_64-linux-gnu/libusb-0.1.so.4 /lib/x86_64-linux-gnu/libusb.so

# install singularity
# (temporarily disabled because we rely on unmerged features)
if /bin/false; then
    echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list
    apt-get update
    apt-get install -y singularity-container/stretch-backports
fi

apt-get install -y "${system_dependencies[@]}"
