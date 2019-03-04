#!/bin/bash -x

set -euo pipefail

# NOTE: Do not allow more than one build per executor!
# Do not change: special sudo permit for jenkins user...
sudo /bin/rm -rf "/tmp/${NODE_NAME}/"
