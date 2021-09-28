#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

# This file is to install all packages that are a pre-requisite for spack to be
# installed.

prerequisites=(
    "ca-certificates"
    "ccache"
    "curl"
    "file"
    "g++"
    "gawk"
    "gcc"
    "git"
    "lbzip2"
    "less"
    "libc6-dev"
    "locales"
    "make"
    "netbase"
    "parallel"
    "patch"
    "patchelf"
    "procps"
    "python3"
    "python3-yaml"
    "python-is-python3"
    "rsync"
    "ssh"
    "sudo"
    "udev"
    "unzip"
    "xz-utils"
)

apt-get update
apt-get install -o DPkg::Options::=--force-confold -y "${prerequisites[@]}"
