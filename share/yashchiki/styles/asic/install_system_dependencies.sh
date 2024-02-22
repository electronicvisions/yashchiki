#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

# VK introduced jq into build flow
yum -y install jq

# gtest is F9's C++ test framework of choice
yum -y install gtest-devel

# ECM: and now some abspacking
yum -y install ccache sudo parallel

# ECM: and userspace mount stuff
yum -y install fuse3 fuse-sshfs

# ECM: save some more space
yum clean all

alternatives --set python /usr/bin/python3.9
