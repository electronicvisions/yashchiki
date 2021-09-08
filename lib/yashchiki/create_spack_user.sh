#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# we need the spack user outside of the container, create it here if it is not present already
if [ id spack &>/dev/null ]; then
	sudo useradd spack --uid 888 --no-create-home --system --shell /bin/bash
fi
