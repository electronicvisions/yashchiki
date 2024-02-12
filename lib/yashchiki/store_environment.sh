#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit

# store environment for usage within container
echo "# Host environment set to:" >&2
env | tee "${YASHCHIKI_HOST_ENV_PATH}"
