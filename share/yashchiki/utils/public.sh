#!/bin/bash
set -Eeuo pipefail

# Usage: ./show_public_containers.sh [show|expose|clean]
#
# When executed with "show" (default), print a list of all containers that are
# safe to expose to the public.
#
# When executed with "expose", create symlinks for all public containers in
# ${CONTAINER_PUBLIC}.
#
# When executed with "clean", remove all symlinks in ${CONTAINER_PUBLIC}.

CONTAINER_PATH="/containers/stable"
CONTAINER_PUBLIC="/containers/public"

# if these packages are present in container -> do not expose!
BLACKLISTED_PACKAGES=(
    "xilinx-ise"
)


check_container() {
    # Usage: check_container <file>
    # Check if container is safe for public access.
    #
    # Return code of zero: safe for public access
    # Return code of non-zero: NOT safe for public access

    local container
    container="$1"

    # NOTE: Since we are tracking regular container usage via access time
    # modification,  we want to preserve access timestamps. In order to do so
    # we reset the modfication timestamp to the distant past (because access
    # timestamps only get updated when modification > access) and then restore
    # the old setting afterwards.

    local old_atime
    local old_mtime
    old_atime="$(stat -c %x "${container}")"
    old_mtime="$(stat -c %y "${container}")"

    local check_result
    check_container_inner "${container}"
    check_result=$?

    # restore old stats
    touch -m -d "${old_mtime}" "${container}"
    touch -a -d "${old_atime}" "${container}"

    return ${check_result}
}


check_container_inner() {
    # Usage: check_container_inner <file>

    # Performs the actual checks on the container.

    # Return code of zero: safe for public access
    # Return code of non-zero: NOT safe for public access
    local container
    container="$1"

    # ASIC containers are not safe to publish
    if [[ "$(basename "${container}")" =~ ^asic_ ]]; then
        return 1
    fi

    # check that there are no blacklisted packages in the container
    if /skretch/opt/apptainer/1.2.5/bin/apptainer shell "${container}" -l \
        -c "spack find | grep -q \"$(get_grep_pattern_blacklisted)\"" \
        &>/dev/null; then
        # do NOT use container if blacklisted package present
        return 1
    fi

    return 0
}

get_grep_pattern_blacklisted() {
    {
        echo "^\("
        echo "${BLACKLISTED_PACKAGES[@]}" | sed -e 's: :\\|:g'
        echo "\)"
    } | tr -d "\n"
}


show() {
    for image in $(find ${CONTAINER_PATH} -type f); do
        check_container "${image}" && echo "${image}"
    done
}


expose() {
    for image in $(show); do
        ln -sfv "${image}" "${CONTAINER_PUBLIC}"
    done

    # add latest symlink to latest container by name
    local latest
    latest=$(ls -1 ${CONTAINER_PUBLIC} | grep "\.img$" | grep -v "latest\.img" | tail -n 1)
    ln -sfv "${latest}" "${CONTAINER_PUBLIC}/latest.img"
}


clean() {
    find "${CONTAINER_PUBLIC}" -type l -delete
}


if (( $# > 0 )); then
    for cmd in "$@"; do
        case "${cmd}" in
        "show")
            show
        ;;
        "expose")
            expose
        ;;
        "clean")
            clean
        ;;
        "")
            show
        ;;
        *)
            echo "# Unrecognized command: $1"
            echo "# Valid commands: show (default), expose, clean"
            exit 1
        esac
    done
else
    show
fi

