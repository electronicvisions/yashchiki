#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Get gerrit username
gerrit_username() {
    echo "${GERRIT_USERNAME:-hudson}"
}

# Read the current gerrit config from `.gitreview` into global variables:
# * gerrit_branch
# * gerrit_remote
# * gerrit_host
# * gerrit_port
# * gerrit_project
#
# Unfortunately, since we cannot return values from function, they have to be
# global variables.
gerrit_read_config() {
    local git_dir
    git_dir="$(git rev-parse --show-toplevel)"
    # remote branch
    gerrit_branch="$(grep "^defaultbranch=" "${git_dir}/.gitreview" | cut -d = -f 2)"
    gerrit_remote="$(grep "^defaultremote=" "${git_dir}/.gitreview" | cut -d = -f 2)"
    gerrit_host="$(grep "^host=" "${git_dir}/.gitreview" | cut -d = -f 2)"
    gerrit_port="$(grep "^port=" "${git_dir}/.gitreview" | cut -d = -f 2)"
    gerrit_project="$(grep "^project=" "${git_dir}/.gitreview" | cut -d = -f 2)"
}

# Ensure that the gerrit remote is properly set up in the current git directory.
gerrit_ensure_setup() {
    gerrit_read_config

    if ! git remote | grep -q "${gerrit_remote}"; then
        # ensure git review is set up
        git remote add "${gerrit_remote}" "ssh://$(gerrit_username)@${gerrit_host}:${gerrit_port}/${gerrit_project}"
    fi
    git fetch "${gerrit_remote}" "${gerrit_branch}"
}

gerrit_filter_current_change_commits() {
    awk '$1 ~ /^commit$/ { commit=$2 }; $1 ~ /^Change-Id:/ { print commit }'
}

# Get the current stack of changesets in the current git repo as commit ids.
gerrit_get_current_change_commits() {
    gerrit_ensure_setup

    # only provide change-ids that are actually present in gerrit
    comm -1 -2 \
        <(git log "${gerrit_remote}/${gerrit_branch}..HEAD" \
            | gerrit_filter_current_change_commits | sort) \
        <(git ls-remote "${gerrit_remote}" | awk '$2 ~ /^refs\/changes/ { print $1 }' | sort)
}

# Convenience method to print the ssh command necessary to connect to gerrit.
#
# Note: Make sure the gerrit config was read prior to calling this!
gerrit_cmd_ssh() {
    echo -n "ssh -p ${gerrit_port} $(gerrit_username)@${gerrit_host} gerrit"
}

# Post comment on the given change-id
#
# Gerrit host/post will be read from current git repository.
#
# Args:
#   -c <change>
#   -m <message>
gerrit_notify_change() {
    local change=""
    local message=""
    local verified=""
    local opts OPTIND OPTARG
    while getopts ":c:m:v:" opts; do
        case "${opts}" in
            c)  change="${OPTARG}"
                ;;
            m)  message="${OPTARG}"
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

    if [ -z "${change}" ]; then
        echo "ERROR: No change to post to given!" >&2
        return 1
    fi
    if [ -z "${message}" ]; then
        echo "ERROR: No message given!" >&2
        return 1
    fi

    gerrit_read_config
    $(gerrit_cmd_ssh) review --message "\"${message}\"" \
        "$([ -n "${verified}" ] && echo --verified "${verified}")" \
        "${change}"
}
