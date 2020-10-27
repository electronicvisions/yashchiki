#!/bin/bash

set -euo pipefail

# set generic locale for building
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

unset LC_CTYPE
unset LC_COLLATE
unset LC_MONETARY
unset LC_NUMERIC
unset LC_TIME
unset LC_MESSAGES

echo "creating asic_recipe.def" >&2
SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
"${SOURCE_DIR}/asic_create_recipe.sh"

echo "created asic_recipe.def" >&2
cat "${WORKSPACE}/asic_recipe.def"

# build the container (using scripts from above)
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

TARGET_FOLDER="sandboxes/asic"

# Do not change: special sudo permit for jenkins user...
sudo rm -rf sandboxes/

mkdir sandboxes

# Do not change: special sudo permit for jenkins user...
sudo -E singularity build --sandbox "${TARGET_FOLDER}" asic_recipe.def
