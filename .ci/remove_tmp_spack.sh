#!/bin/bash -x

set -euo pipefail

# Do not change: special sudo permit for jenkins user...
if [ -d "${JOB_TMP_SPACK}" ]; then
    sudo /bin/rm -rf "${JOB_TMP_SPACK}"
fi
