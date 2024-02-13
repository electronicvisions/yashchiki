#!/bin/bash

#
# Usage: $0 [-c <container-name>]
#           [-m <custom-message>]
#           [-r <result>]
#           [-t <result-type>]
#           [-v <verified-vote>]
#

set -euo pipefail
shopt -s inherit_errexit

if ! [ "${CONTAINER_BUILD_TYPE:-}" = "testing" ]; then
    exit 0
fi

ROOT_DIR="$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")"
source "${ROOT_DIR}/lib/yashchiki/gerrit.sh"

container_name=""
result_type=""
result=""
verified=""

while getopts ":c:m:r:s:t:v:" opts; do
    case "${opts}" in
        c)  container_name="${OPTARG}"
            ;;
        m)  custom_message="${OPTARG}"
            ;;
        r)  result="${OPTARG}"
            ;;
        t)  result_type="${OPTARG}"
            ;;
        v)  verified="${OPTARG}"
            ;;
        *)
            echo "Invalid argument: ${opts}" >&2
            return 1
            ;;
    esac
done
shift $(( OPTIND - 1 ))

if [ -z "${result}" ] && [ -n "${verified}" ]; then
    if (( verified == 1 )); then
        result="SUCCESS"
    elif ((verified == 0 )); then
        result="UNSTABLE"
    elif ((verified == -1 )); then
        result="FAILURE"
    fi
fi

message="[$(echo "${BUILD_URL}")] \
${container_name:+Change included in container: ${container_name}} \
${custom_message:-} \
${result:+${result_type:+${result_type} }Result: ${result}}"

if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
    tmpfile_commits="$(mktemp)"

    # Notify all changes involved that they got built into the current container

    # yashchiki changes
    if [ -f "${YASHCHIKI_META_DIR}/current_changes-yashchiki.dat" ]; then
        cat "${YASHCHIKI_META_DIR}/current_changes-yashchiki.dat" >> "${tmpfile_commits}"
    fi

    # spack changes
    if [ -f "${YASHCHIKI_META_DIR}/current_changes-spack.dat" ]; then
        cat "${YASHCHIKI_META_DIR}/current_changes-spack.dat" >> "${tmpfile_commits}"
    fi

    readarray -t commits < <(grep -v "^$" "${tmpfile_commits}")

    # needs to be in git repo for gerrit_notify_change to work
    cd ${YASHCHIKI_INSTALL}
    for change in "${commits[@]}"; do
        if ! gerrit_notify_change -c "${change}" \
            -v "${verified}" \
            -m "${message}" 1>&2; then
            echo "ERROR during gerrit notification regarding: ${change}" >&2
        fi
    done

    rm -v "${tmpfile_commits}" 1>&2
fi
