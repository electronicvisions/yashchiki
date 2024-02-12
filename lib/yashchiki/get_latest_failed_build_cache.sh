#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

ROOT_DIR="$(dirname "$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")")"
source ${ROOT_DIR}/lib/yashchiki/get_change_name.sh

get_latest_failed_build_cache_name() {
    local full_change_num
    local possible_build_caches
    local latest_patch_level
    local latest_build_num

    full_change_num="$(get_change_name)"
    change_num="${full_change_num%%p*}"
    possible_build_caches="$(mktemp)"

    find "${YASHCHIKI_CACHES_ROOT}/build_caches/failed" -mindepth 1 -maxdepth 1 -type d -name "${change_num}*" -print0 \
        | xargs -r -n 1 -r -0 basename > "${possible_build_caches}"

    if (( $(wc -l <"${possible_build_caches}") == 0 )); then
        rm "${possible_build_caches}"
        return 0
    fi

    latest_patch_level="$(cat "${possible_build_caches}" \
        | cut -d p -f 2 | cut -d _ -f 1 | sort -rg | head -n 1)"

    latest_build_num="$(grep "p${latest_patch_level}_" "${possible_build_caches}" \
        | cut -d _ -f 2 | sort -rg | head -n 1)"

    echo -n "failed/${change_num}p${latest_patch_level}_${latest_build_num}"

    rm "${possible_build_caches}"
}
