#!/bin/bash
#
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
    FILE_AWK="$(mktemp)"

    # Small awk script that adjusts the first column of output to fit the
    # longest path. Also hides the seconds-since epoch column that is not
    # really human readable
    cat <<EOF >"${FILE_AWK}"
{
    \$1="";
    maxlen = ( maxlen < length(\$2) ) ? length(\$2) : maxlen;
    names[++num_elems] = \$2;
    access[num_elems] = \$3 " " \$4
}

END {
    for (i = 1; i<num_elems; ++i) {
        printf("%-" maxlen "s accessed at %s\\n", names[i], access[i])
    }
}
EOF

    # sort on seconds since epoch and then have awk present the human readable
    # format in prettified way
    get_images | xargs stat -c "%X %n %x" | sort -n | awk -f "${FILE_AWK}"
    rm "${FILE_AWK}"
}

if [ "$1" = "reset" ]; then
    access_reset
else
    echo "# " >&2
    echo "# Sorted container access times:" >&2
    echo "# " >&2
    show_accessed
fi
