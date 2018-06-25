#!/bin/bash -x

# Do not change: special sudo permit for jenkins user...
for tempfolder in /tmp/spack/tmp.*; do
    sudo rm -rf ${tempfolder} || exit 0
done
