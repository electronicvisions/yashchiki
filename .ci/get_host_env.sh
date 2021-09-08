#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

# Usage:
#   get_host_env.sh <variable-name>
#
# Stand-alone shell variant to the corresponding function from commons.sh to
# allow retrieval of environment information in Jenkinsfile.
#
# Get <variable-name> from the host environment dumped at the start of the
# host job.  If the host environment was not dumped at the beginning of
# the host job, the regular environment is taken.
#
# If the variable is not found, return 1.

if (( $# > 1 || $# == 0 )); then
    echo "ERROR: $0 expects exactly one argument!" >&2
    exit 1
fi

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

get_host_env "$1"
