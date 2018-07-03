#!/bin/bash -x

# Do not change: special sudo permit for jenkins user...
for tempfolder in /tmp/spack/tmp.*; do
    if [ -d ${tempfolder} ]; then
        sudo /bin/rm -rf ${tempfolder} || exit 0
    fi
done
