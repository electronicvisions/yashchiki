#!/bin/bash
#
# Check which temporary build caches/preserved packages there are and list all
# for which the corresponding change is merged/abandoned.
#
# If "clean" is specified we also remove all preserved_packages from stable
# containers older than ${DELETE_STABLE_AFTER_N_DAYS} days.
#
# If 'clean' is given as command, remove them.
# If 'status' is specifed, list all changesets along with their status in
# gerrit.

set -Eeuo pipefail

RUN_ON_HOST="conviz"
BUILD_CACHE_PATH="/home/vis_jenkins/build_caches"

DELETE_STABLE_AFTER_N_DAYS=90

if [ "$(hostname)" != "${RUN_ON_HOST}" ]; then
    echo "ERROR: Needs to be executed on ${RUN_ON_HOST}" >&2
    exit 1
fi

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/gerrit.sh"

get_preserved_packages()
{
    find ${BUILD_CACHE_PATH}/preserved_packages -maxdepth 1 -type d -name "c*p*_*"
}

get_failed_build_caches()
{
    find ${BUILD_CACHE_PATH}/failed -maxdepth 1 -type d -name "c*p*_*"
}

get_old_stable_preserved_packages()
{
    find ${BUILD_CACHE_PATH}/preserved_packages -maxdepth 1 -type d -name "stable_*" -ctime +${DELETE_STABLE_AFTER_N_DAYS}
}

get_merged_or_abandoned_changesets()
{
    ( get_preserved_packages; get_failed_build_caches ) | to_changesets \
        | filter_merged_or_abandoned_changesets
}

get_folders_to_clean()
{
    readarray -t folders < <(get_preserved_packages; get_failed_build_caches)
    readarray -t changes < <(printf '%s\n' "${folders[@]}" | to_changesets | filter_merged_or_abandoned_changesets)

    local pattern=""
    for cs in "${changes[@]}"; do
        if [ -z "${pattern}" ]; then
            pattern="\\(c${cs}p"
        else
            pattern="${pattern}\\|/c${cs}p"
        fi
    done
    # only print something if we have at least one mergeable cs
    if [ -n "${pattern}" ]; then
        pattern="${pattern}\\)"

        printf '%s\n' "${folders[@]}" | grep "${pattern}"
    fi
}


if (( $# > 0 )) && [ "$1" = "clean" ]; then
    if [ "$UID" -eq 0 ] && [ "$(hostname)" = "${RUN_ON_HOST}" ]; then
        tmp="$(mktemp)"
        get_folders_to_clean | xargs --no-run-if-empty rm -rv | tee "${tmp}"
        if (( $(wc -l < "${tmp}" ) > 0 )); then
            echo "# Cleaned $(wc -l < "${tmp}") files belonging to merged (or abandoned) changesets." >&2
        fi
        get_old_stable_preserved_packages | xargs --no-run-if-empty rm -rv | tee "${tmp}"
        if (( $(wc -l < "${tmp}" ) > 0 )); then
            echo "# Cleaned $(wc -l < "${tmp}") files belonging to old preserved packages \
(older than ${DELETE_STABLE_AFTER_N_DAYS} days) from stable container builds." >&2
        fi
        rm "${tmp}"
    else
        echo -n "Must be root on ${RUN_ON_HOST} to clean testing build remnants for " >&2
        echo "merged (or abandoned) changesets!" >&2
        exit 1
    fi
elif (( $# > 0 )) && [ "$1" = "status" ]; then
    echo "# Displaying status of all CS for which there are preserved packages or failed build caches: " >&2
    (get_preserved_packages ; get_failed_build_caches) | to_changesets | get_status_for_changesets
else
    echo "#" >&2
    echo "# The following folders belong to merged (or abandoned) changesets:" >&2
    echo -n "# Run $0 with 'clean' argument as root on " >&2
    echo "${RUN_ON_HOST} to remove them." >&2
    echo "# Run '$0 status' to see the status of all changesets." >&2
    echo "#" >&2
    get_merged_or_abandoned_changesets
fi
