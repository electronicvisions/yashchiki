#!/bin/bash

# Since the filesystem hosting the containers is mounted with relatime, the
# access-time is updated only if the modification timestamp is newer than the
# access-timestamp.
#
# In order to find out which containers are still in use, it is therefore
# important to periodically reset their modification-timestamp and check if the
# access-timestamp gets updated or not.
#
# This might help in the future when to decide which containers to retire to
# slow storage media.
#
# Possible arguments:
#  reset        reset modification time on all images to track if they still
#               get accessed
#

CONTAINER_PATH="/containers"
CONTAINER_HOST="comicsans"

get_images()
{
    find ${CONTAINER_PATH} -name "*.img"
}

get_last_access_reset()
{
    get_images | xargs stat -c "%y" | sort | uniq
}

access_reset()
{
    if [ "$UID" -eq 0 ] && [ "$(hostname)" = "${CONTAINER_HOST}" ]; then
        get_images | xargs touch -cmh
        echo "Reset access counts." >&2
    else
        echo "Must be root on ${CONTAINER_HOST} to reset access counters." >&2
        exit 1
    fi
}

# print names of files that were accessed after last modification flag reset
show_accessed()
{
    get_images | xargs stat -c "%n %X %Y" | awk '($2 >= $3) { print $1 }'
}

show_accessed_detail()
{
    get_images | xargs stat -c "%n %X %Y %y" \
        | awk '($2 >= $3) { print $1 " accessed since " $4 " " $5 " " $6 }'
}


if [ "$1" = "reset" ]; then
    access_reset
else
    LAST_RESET=$(get_last_access_reset)
    if [ "$(echo "${LAST_RESET}" | wc -l)" -gt 1 ]; then
        echo "# " >&2
        echo "# Warning: Found multiple modification timestamps!" >&2
        echo "# " >&2
        show_accessed_detail
    else
        echo "# " >&2
        echo "# Containers accessed since ${LAST_RESET}:" >&2
        echo "# " >&2
        show_accessed
    fi
fi
