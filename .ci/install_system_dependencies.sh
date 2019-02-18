#!/bin/bash -x

set -euo pipefail

system_dependencies=(
        "corkscrew"
        "cpio"
        "fxload"
        "iproute2"
        "iptables"
        "iputils-ping"
        "latex-make"
        "libcap2-bin"
        "libusb-1.0-0-dev"
        "libusb-dev"
        "man-db"
        "net-tools"
        "strace"
        "texlive-full"
        "tsocks"
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