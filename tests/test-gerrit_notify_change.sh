#!/usr/bin/env bash

set -Eeuo pipefail

# Testing the post-deployment step of deploy_container.sh standalone.

# Define everything that needs to be defined in a normal run.
export BUILD_CACHE_NAME=undefined
export DEPENDENCY_PYTHON=undefined
export VISIONARY_GCC=undefined
export BUILD_URL="https://obreitwi/testing/manual.html"

ROOT_DIR="$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")"

notify_gerrit="${ROOT_DIR}/bin/yashchiki/notify_gerrit.sh" 

bash "${notify_gerrit}" -c "testing-notify-feature" -s "${ROOT_DIR}/spack" -v 1

export CONTAINER_BUILD_TYPE=stable
bash "${notify_gerrit}" -c "testing-notify-feature" -s "${ROOT_DIR}/spack" -v 1

export CONTAINER_BUILD_TYPE=testing

bash "${notify_gerrit}" -c "testing-notify-feature" -s "${ROOT_DIR}/spack" -v 1
bash "${notify_gerrit}" -c "testing-notify-feature" -s "${ROOT_DIR}/spack" -v -1
bash "${notify_gerrit}" -s "${ROOT_DIR}/spack" -v 0
