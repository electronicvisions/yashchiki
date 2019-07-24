#!/bin/bash -x

set -euo pipefail

# This file is to install all packages needed from apt that are not required by
# spack in order to bootstrap itself.

system_dependencies=(
        "arping"
        "bash-completion"
        "corkscrew"
        "cpio"
        "fish"
        "fxload"
        "htop"
        "iproute2"
        "iptables"
        "iputils-ping"
        "libc6-dbg"
        "libcap2-bin"
        "libpam0g-dev"
        "libudev-dev"
        "libusb-1.0-0-dev"
        "libusb-dev"
        "lshw"
        "man-db"
        "ncurses-term"
        "net-tools"
        "psmisc"
        "strace"
        "tshark"
        "tsocks"
        "usbutils"
        "vim-nox"
        "xauth"
        "xz-utils"
        "zsh"
    )
# for premium software (e.g. Xilinx impact)
ln -s /lib/x86_64-linux-gnu/libusb-0.1.so.4 /lib/x86_64-linux-gnu/libusb.so

# usually debconf poses questions regarding configuraiton for the user to
# answer during install, but we install headless -> we need to tell debian to
# look up our pre-determined answers via the noninteractive
export DEBIAN_FRONTEND=noninteractive

# Make the following selections for debconf:
# * install tshark with setuid binaries (needed to capture raw network traffic)
debconf-set-selections <<EOF
wireshark-common wireshark-common/install-setuid boolean true
EOF

apply_prefix() {
    sed -e "s:^:[SYSTEM-APT] :g"
}

# install singularity
# (temporarily disabled because we rely on unmerged features)
# (also disabled due to missing package in buster)
if /bin/false; then
    echo "deb http://ftp.debian.org/debian buster-backports main" >> /etc/apt/sources.list
    apt-get update | apply_prefix
    apt-get install -y singularity-container/buster-backports | apply_prefix
fi

apt-get install -y "${system_dependencies[@]}" | apply_prefix
