#!/bin/bash
#
# Check which containers in /containers/testing can be deleted because the
# corresponding changeset is merged.
#
# Possible arguments:
#  clean        delete all images belonging to already merged changesets
#

set -euo pipefail

CONTAINER_PATH="/containers/testing"
CONTAINER_HOST="comicsans"

if [ -z "${GERRIT_USERNAME:-}" ]; then
    GERRIT_USERNAME=$(git config gitreview.username || echo "$USER")
fi

if [ -z "${GERRIT_PORT:-}" ]; then
    GERRIT_PORT=29418
fi

if [ -z "${GERRIT_HOSTNAME:-}" ]; then
    GERRIT_HOSTNAME="brainscales-r.kip.uni-heidelberg.de"
fi

get_images()
{
    find ${CONTAINER_PATH} -name "*.img"
}

get_changesets()
{
    get_images | xargs -n 1 basename | sed "s/c\\(.*\\)p.*/\\1/g" | sort | uniq
}

get_merged_or_abandoned_changesets()
{
    for cs in $(get_changesets); do
        ssh -p ${GERRIT_PORT} \
            "${GERRIT_USERNAME}@${GERRIT_HOSTNAME}" gerrit query \
            --current-patch-set "${cs}" | \
        awk "\$1 ~ \"status:\" && (\$2 ~ \"MERGED\" || \$2 ~ \"ABANDONED\") { print ${cs} }"
    done
}

get_merged_or_abandoned_images()
{
    local pattern=""
    for cs in $(get_merged_or_abandoned_changesets); do
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
else
    echo "#" >&2
    echo "# The following images correspond to merged (or abandoned) changesets:" >&2
    echo -n "# Run $0 with 'clean' argument as root on " >&2
    echo "${CONTAINER_HOST} to remove them." >&2
    echo "#" >&2

    get_merged_or_abandoned_images
fi

