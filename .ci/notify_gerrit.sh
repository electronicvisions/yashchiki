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

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/dummy_variables.sh"
source "${SOURCE_DIR}/commons.sh"

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

message="[$(get_jenkins_env BUILD_URL)] \
${container_name:+Change included in container: ${container_name}} \
${custom_message:-} \
${result:+${result_type:+${result_type} }Result: ${result}}"

if [ "${CONTAINER_BUILD_TYPE}" = "testing" ]; then
    tmpfile_commits="$(mktemp)"

    # Notify all changes involved that they got built into the current container

    # yashchiki changes
    meta_dir="$(get_var_in_out META_DIR)"
    if [ -f "${meta_dir}/current_changes-yashchiki.dat" ]; then
        cat "${meta_dir}/current_changes-yashchiki.dat" >> "${tmpfile_commits}"
    fi

    # spack changes
    if [ -f "${meta_dir}/current_changes-spack.dat" ]; then
        cat "${meta_dir}/current_changes-spack.dat" >> "${tmpfile_commits}"
    fi

    readarray -t commits < <(grep -v "^$" "${tmpfile_commits}")

    # if we are in a singularity container we need to go to the spack
    # repository so the gerrit notifier can extract gerrit settings all
    if [ -n "${SINGULARITY_CONTAINER:-}" ]; then
        pushd "${MY_SPACK_FOLDER}" &>/dev/null || exit 1
    fi

    # needs to be in git repo for gerrit_notify_change to work
    cd ${WORKSPACE}/yashchiki
    for change in "${commits[@]}"; do
        if ! gerrit_notify_change -c "${change}" \
            -v "${verified}" \
            -m "${message}" 1>&2; then
            echo "ERROR during gerrit notification regarding: ${change}" >&2
        fi
    done

    if [ -n "${SINGULARITY_CONTAINER:-}" ]; then
        popd &>/dev/null || exit 1
    fi

    rm -v "${tmpfile_commits}" 1>&2
fi
