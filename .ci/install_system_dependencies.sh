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
        "libpam0g-dev"
        "libusb-1.0-0-dev"
        "libusb-dev"
        "linux-perf"
        "lshw"
        "man-db"
        "net-tools"
        "psmisc"
        "strace"
        "texlive"
        "texlive-lang-german"
        "texlive-latex-extra"
        "tshark"
        "tsocks"
        "usbutils"
        "vim-nox"
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
if /bin/false; then
    echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list
    apt-get update | apply_prefix
    apt-get install -y singularity-container/stretch-backports | apply_prefix
fi

apt-get install -y "${system_dependencies[@]}" | apply_prefix
