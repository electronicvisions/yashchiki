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
#  archive      print commands to move containers into archive
#  reset        reset modification time on all images to track if they still
#               get accessed
#  show         show access times of containers (default)
#

CONTAINER_PATH="/containers"
CONTAINER_HOST="comicsans"
CONTAINER_ARCHIVE="/ley/data/containers/archive"

get_images()
{
    find ${CONTAINER_PATH} \
        \( -type d \( -name public -o -name manual \) -prune -false \) \
        -o -type f -name "*.img"
}

get_last_access_reset()
{
    get_images | xargs stat -c "%x" | sort | uniq
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

show_by_access()
{
    # Align given string by fist column, sorted by access.
    #
    # $1: string to be passed to awk script describing contents of first colum
    # $2: prefix to be put between aligned first colum and access time
    #
    FIRST_COLUMN="${1}"
    if (( "$#" > 1 )); then
        PREFIX_ACCESS=${2}
    else
        PREFIX_ACCESS=" last accessed at "
    fi
    FILE_AWK="$(mktemp)"

    # Small awk script that adjusts the first column of output to fit the
    # longest path. Also hides the seconds-since epoch column that is not
    # really human readable
    cat <<EOF >"${FILE_AWK}"
{
    \$1="";
    first_column=${FIRST_COLUMN};
    maxlen = ( maxlen < length(first_column) ) ? length(first_column) : maxlen;
    lines[++num_elems] = first_column;
    access[num_elems] = \$3 " " \$4
}

END {
    for (i = 1; i<=num_elems; ++i) {
        printf("%-" maxlen "s${PREFIX_ACCESS}%s\\n", lines[i], access[i])
    }
}
EOF

    # sort on seconds since epoch and then have awk present the human readable
    # format in prettified way
    get_images | xargs stat -c "%X %n %x" | sort -n | awk -f "${FILE_AWK}"
    rm "${FILE_AWK}"
}

# print names of files that were accessed after last modification flag reset
show_accessed()
{
    if [ -t 1 ]; then
        # helper text when outputting to terminal
        echo "# " >&2
        echo "# Sorted container access times:" >&2
        echo "# " >&2
    fi
    show_by_access "\$2"
}

show_archive_cmds()
{
    if [ -t 1 ]; then
        # helper text when outputting to terminal
        echo "# " >&2
        echo "# Use as user vis_jenkins: bash <($0 archive | head -n \${NUMBER_OF_CONTAINERS_TO_ARCHIVE})" >&2
        echo "# " >&2
    fi
    show_by_access "\"mv -v \" \$2" " ${CONTAINER_ARCHIVE}  # last accessed at "
}

case "$1" in
"reset")
    access_reset
;;
"archive")
    show_archive_cmds
;;
"show")
    show_accessed
;;
"")
    show_accessed
;;
*)
    echo "# Unrecognized command: $1"
    echo "# Valid commands: archive, reset, show (default)"
esac
