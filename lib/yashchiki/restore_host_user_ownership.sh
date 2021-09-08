#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

if [ -d "${YASHCHIKI_SPACK_PATH}" ]; then
	sudo chown -R $(id -un):$(id -gn) "${YASHCHIKI_SPACK_PATH}"
fi

if [ -d "${JOB_TMP_SPACK}" ]; then
	sudo chown -R $(id -un):$(id -gn) "${JOB_TMP_SPACK}"
fi
