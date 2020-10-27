#!/bin/bash

set -euo pipefail

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

if [ -z "${GERRIT_USERNAME:-}" ]; then
    GERRIT_USERNAME="hudson"
fi

if [ -z "${GERRIT_PORT:-}" ]; then
    GERRIT_PORT=29418
fi

if [ -z "${GERRIT_HOSTNAME:-}" ]; then
    GERRIT_HOSTNAME="brainscales-r.kip.uni-heidelberg.de"
fi

if [ -z "${GERRIT_BASE_URL:-}" ]; then
    export GERRIT_BASE_URL="ssh://${GERRIT_USERNAME}@${GERRIT_HOSTNAME}:${GERRIT_PORT}"
fi

# clone spack installation ouside and copy into the container
MY_GERRIT_URL="${GERRIT_BASE_URL}/spack"
rm -rf spack
git clone ${MY_GERRIT_URL} -b visionary spack

# Checkout specific spack change in case we have a testing build.
#
# Please note that stable builds should ALWAYS build stable!
#
# order of importance:
# 1. jenkins-specified SPACK_GERRIT_REFSPEC
# 2. jenkins-specified SPACK_GERRIT_CHANGE
# 3. triggered gerrit comment contains WITH_SPACK_CHANGE
# 4. triggered gerrit comment contains WITH_SPACK_REFSPEC
# 5. commit-specified Depends-On
#
# If multiple are specified, take the first variable defined according the
# order above.

if [ -z "${SPACK_GERRIT_CHANGE:-}" ] && [ -z "${SPACK_GERRIT_REFSPEC:-}" ]; then
    GERRIT_SPECIFIED_SPACK_CHANGE="$(get_jenkins_env GERRIT_SPECIFIED_SPACK_CHANGE)"
    GERRIT_SPECIFIED_SPACK_REFSPEC="$(get_jenkins_env GERRIT_SPECIFIED_SPACK_REFSPEC)"

    if [ -n "${GERRIT_SPECIFIED_SPACK_CHANGE}" ]; then
        SPACK_GERRIT_CHANGE="${GERRIT_SPECIFIED_SPACK_CHANGE}"
    elif [ -n "${GERRIT_SPECIFIED_SPACK_REFSPEC}" ]; then
        SPACK_GERRIT_REFSPEC="${GERRIT_SPECIFIED_SPACK_REFSPEC}"
    else
        # see if the commit message contains a "Depends-On: xy" line
        # if there are several lines, concatenate with commas
        SPACK_GERRIT_CHANGE=$(git log -1 --pretty=%B \
            | awk '$1 ~ "Depends-On:" { $1 = ""; print $0 }' | tr '\n' ',' | tr -d \[:space:\])
    fi
else
    echo "SPACK_GERRIT_CHANGE or SPACK_GERRIT_REFSPEC specified, ignoring "\
         "possible 'WITH_SPACK_CHANGE' in gerrit commit message or "\
         "'Depends-On'-line in commit message!" >&2
fi


# If there is a spack gerrit change specified and no refspec -> resolve!
if [ -n "${SPACK_GERRIT_CHANGE:-}" ] && [ -z "${SPACK_GERRIT_REFSPEC:-}" ]; then
    # convert spack change id to latest patchset
    pushd "spack"

    ref_stable="$(git rev-parse HEAD)"

    gerrit_query=$(mktemp)

    for change in ${SPACK_GERRIT_CHANGE//,/ }; do
        ssh -p ${GERRIT_PORT} \
               ${GERRIT_USERNAME}@${GERRIT_HOSTNAME} gerrit query \
               --current-patch-set ${change} > ${gerrit_query}

        # check that the change corresponds to a spack change and extract
        # refspec
        SPACK_GERRIT_REFSPEC="$(awk '
            $1 ~ "project:" && $2 ~ "spack" { project_found=1 }
            $1 ~ "ref:" && project_found { print $2 }' "${gerrit_query}" )"

        # break as soon as we have the change for the spack repo
        if [ -n "${SPACK_GERRIT_REFSPEC}" ]; then

            change_status="$(awk '$1 ~ "status:" { print $2 }' "${gerrit_query}")"
            # in case we have a stable build, just make sure that the change we
            # depend on has been merged, if not -> fail early!
            if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
                if [ "${change_status}" != "MERGED" ]; then
                    echo "This change depends on unmerged spack changeset! Aborting.." >&2
                    rm "${gerrit_query}"
                    exit 1
                fi
            else
                if [ "${change_status}" = "MERGED" ]; then
                    echo "This change depends on an already merged spack changeset! Ignoring.." >&2
                    unset SPACK_GERRIT_REFSPEC
                fi
            fi

            # if SPACK_GERRIT_REFSPEC is still set, then we found a valid
            # changeset to checkout -> break
            # else -> continue searching
            #
            # We want to support two workflows:
            # * specify one changeset that represents a stack of changes in the
            #   spack repo to be checked out
            # * specify several independent spack changesets that are to be
            #   cherry-picked on top of each other
            #
            # Therefore, we check out the first unmerged refspec we encounter
            # and cherry pick all further changes.
            if [ -n "${SPACK_GERRIT_REFSPEC}" ]; then

                if [ "${CONTAINER_BUILD_TYPE}" != "stable" ]; then
                    git fetch ${MY_GERRIT_URL} "${SPACK_GERRIT_REFSPEC}"

                    if [[ "${ref_stable}" == "$(git rev-parse HEAD)" ]]; then
                        echo "SPACK_GERRIT_REFSPEC was specified for the first"\
                            "time: ${SPACK_GERRIT_REFSPEC} -> check out" >&2

                        git checkout FETCH_HEAD
                    else
                        echo "SPACK_GERRIT_REFSPEC was specified again:"\
                            "${SPACK_GERRIT_REFSPEC} -> cherry-pick" >&2

                        git cherry-pick FETCH_HEAD
                    fi
                else
                    echo "yashchiki HEAD contains 'Depends-On:' but we are building stable -> ignoring!" >&2
                fi

                # prevent SPACK_GERRIT_REFSPEC from getting checked out again below
                unset SPACK_GERRIT_REFSPEC
            fi
        fi
    done

    rm "${gerrit_query}"

    popd
fi

# if SPACK_GERRIT_REFSPEC was specified on its own (i.e., in bld_gerrit-yashchiki-spack-manual), check it out now!
if [ "${CONTAINER_BUILD_TYPE}" != "stable" ] && [ -n "${SPACK_GERRIT_REFSPEC:-}" ]; then
    echo "SPACK_GERRIT_REFSPEC was specified: ${SPACK_GERRIT_REFSPEC} -> checking out"
    pushd "spack"
    git fetch  ${MY_GERRIT_URL} "${SPACK_GERRIT_REFSPEC}" && git checkout FETCH_HEAD
    popd
fi

