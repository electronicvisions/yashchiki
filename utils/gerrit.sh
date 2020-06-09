#!/bin/bash
#
# Include script defining functions useful to check the status of gerrit
# changesets.

if [ -z "${GERRIT_USERNAME:-}" ]; then
    GERRIT_USERNAME=$(git config gitreview.username || echo "$USER")
fi

if [ -z "${GERRIT_PORT:-}" ]; then
    GERRIT_PORT=29418
fi

if [ -z "${GERRIT_HOSTNAME:-}" ]; then
    GERRIT_HOSTNAME="brainscales-r.kip.uni-heidelberg.de"
fi

# Extract change number from folders adhering to yashchiki naming scheme
to_changesets() {
    xargs --no-run-if-empty -n 1 basename | sed "s/c\\(.*\\)p.*/\\1/g" | sort | uniq
}

# Read changes from stdin and print their status
get_status_for_changesets()
{
    readarray -t changes

    for cs in "${changes[@]}"; do
        ssh -p ${GERRIT_PORT} \
            "${GERRIT_USERNAME}@${GERRIT_HOSTNAME}" gerrit query \
            --current-patch-set "${cs}" | \
        awk "\$1 ~ \"status:\" { print \"CS:\", \"${cs}\", \"status:\", \$2 }"
    done
}

# Read changes from stdin and filter those that are not merged or abandoned 
filter_merged_or_abandoned_changesets()
{
    readarray -t changes

    for cs in "${changes[@]}"; do
        ssh -p ${GERRIT_PORT} \
            "${GERRIT_USERNAME}@${GERRIT_HOSTNAME}" gerrit query \
            --current-patch-set "${cs}" | \
        awk "\$1 ~ \"status:\" && (\$2 ~ \"MERGED\" || \$2 ~ \"ABANDONED\") { print ${cs} }"
    done
}
