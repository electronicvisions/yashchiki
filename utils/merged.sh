#!/bin/bash
#
# Check which containers in /containers/testing can be deleted because the
# corresponding changeset is merged.
#
# Possible arguments:
#  status       list all changesets along with their status
#  clean        delete all images belonging to already merged changesets
#

set -Eeuo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/gerrit.sh"

CONTAINER_HOST="comicsans"
CONTAINER_PATH="/containers/testing"

get_images()
{
    find ${CONTAINER_PATH} -name "*.img"
}

get_changesets()
{
    get_images | to_changesets
}

get_changesets_with_status()
{
    get_changesets | get_status_for_changesets
}

get_merged_or_abandoned_images()
{
    local pattern=""
    for cs in $(get_changesets | filter_merged_or_abandoned_changesets); do
        if [ -z "${pattern}" ]; then
            pattern="\\(c${cs}p"
        else
            pattern="${pattern}\\|c${cs}p"
        fi
    done
    # only print something if we have at least one mergeable cs
    if [ -n "${pattern}" ]; then
        pattern="${pattern}\\)"

        get_images | grep "${pattern}"
    fi
}


if (( $# > 0 )) && [ "$1" = "clean" ]; then
    if [ "$UID" -eq 0 ] && [ "$(hostname)" = "${CONTAINER_HOST}" ]; then
        tmp=$(mktemp)
        get_merged_or_abandoned_images | xargs rm -v > "${tmp}"
        cat "${tmp}" >&2
        echo "# Cleaned $(wc -l < "${tmp}") images belonging to merged (or abandoned) changesets." >&2
        rm "${tmp}"
    else
        echo -n "Must be root on ${CONTAINER_HOST} to clean images for " >&2
        echo "merged (or abandoned) changesets!" >&2
        exit 1
    fi
elif (( $# > 0 )) && [ "$1" = "status" ]; then
    echo "# Displaying status of all CS for which there is at least one testing image present:" >&2
    get_changesets_with_status
else
    echo "#" >&2
    echo "# The following images correspond to merged (or abandoned) changesets:" >&2
    echo -n "# Run $0 with 'clean' argument as root on " >&2
    echo "${CONTAINER_HOST} to remove them." >&2
    echo "# Run '$0 status' to see the status of all changesets." >&2
    echo "#" >&2

    get_merged_or_abandoned_images
fi
