#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

get_change_name() {
    local change_num
    local patch_level

    local gerrit_change_number
    local gerrit_patchset_number
    local gerrit_refspec

    gerrit_change_number="${GERRIT_CHANGE_NUMBER}"
    gerrit_patchset_number="${GERRIT_PATCHSET_NUMBER}"
    gerrit_refspec="${GERRIT_REFSPEC}"

    if [ -z "${gerrit_change_number:-}" ]; then
        if [ -n "${gerrit_refspec:-}" ]; then
            # extract gerrit change number from refspec
            change_num="$(echo "${gerrit_refspec}" | cut -f 4 -d / )"
            patch_level="$(echo "${gerrit_refspec}" | cut -f 5 -d / )"
        fi
    else
        change_num="${gerrit_change_number}"
        patch_level="${gerrit_patchset_number}"
    fi
    echo -n "c${change_num}p${patch_level}"
}
