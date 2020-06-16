#!/usr/bin/env bash

echo "Setting undefined required environment variables to 'undefined'." >&2

export BUILD_CACHE_NAME="${BUILD_CACHE_NAME:-undefined}"
export DEPENDENCY_PYTHON3="${DEPENDENCY_PYTHON3:-undefined}"
export DEPENDENCY_PYTHON="${DEPENDENCY_PYTHON:-undefined}"
export VISIONARY_GCC="${VISIONARY_GCC:-undefined}"
