#!/bin/bash -x

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
# 3. commit-specified  Depends-On
#
# If multiple are specified, take the first variable defined according the
# order above.

if [ -z "${SPACK_GERRIT_CHANGE:-}" ] && [ -z "${SPACK_GERRIT_REFSPEC:-}" ]; then
    # see if the commit message contains a "Depends-On: xy" line
    # if there are several lines, concatenate with commas
    SPACK_GERRIT_CHANGE=$(git log -1 --pretty=%B \
        | awk '$1 ~ "Depends-On:" { $1 = ""; print $0 }' | tr '\n' ',' | tr -d \[:space:\])
else
    echo "SPACK_GERRIT_CHANGE or SPACK_GERRIT_REFSPEC specified, ignoring "\
         "possible 'Depends-On'-line in commit message!" >&2
fi


# if there is a spack gerrit change specified and no refspec -> resolve!
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

                unset SPACK_GERRIT_REFSPEC
            fi
        fi
    done

    rm "${gerrit_query}"

    popd
fi

# hard-link download cache into spack folder to avoid duplication
mkdir -p ${PWD}/spack/var/spack/cache/
cp -vrl $HOME/download_cache/* ${PWD}/spack/var/spack/cache/

# set download mirror stuff to prefill outside of container
export MY_SPACK_FOLDER="$PWD/spack"
export MY_SPACK_BIN="${MY_SPACK_FOLDER}/bin/spack"
${MY_SPACK_BIN} mirror rm --scope site global

# add system compiler (needed for fetching)
${MY_SPACK_BIN} compiler add --scope site /usr/bin

# Need KIP proxy to fetch all the packages (also needed in container due to pip)
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

# fetch "everything" (except for pip shitness)
echo "FETCHING..."

# concretize all spack packages in parallel
packages_to_fetch=(
    "${VISIONARY_GCC}"
    "${spack_bootstrap_dependencies[@]}"
    "${spack_packages[@]}"
)
# verify that all concretizations were successful

# first entry is just a statefile to indicate fetching failed (as opposed to
# some warnings that are also printed to stderr during fetching)
tmpfiles_fetch_err=("$(mktemp)")

rm_tmp_fetch_err() {
    rm -v "${tmpfiles_fetch_err[@]}"
}
trap rm_tmp_fetch_err EXIT

num_jobs_fetch="$(nproc)"

fetch_spack_package() {
    set -euo pipefail

    # fetch (and therefore concretize) the given spack packages in a temporary
    # spack instance and hardlink download cache back to main spack
    if (( $# == 0 )); then
        echo "NO PACKAGE TO FETCH!" >&2
        return 1
    fi
    local tmp_spack_folder
    local tmp_spack_bin

    tmp_spack_folder="$(mktemp -d)/spack"
    tmp_spack_bin="${tmp_spack_folder}/bin/spack"

    # hardlink whole spack folder (will also link cache)
    # as of now spack folder contains symlinks of the form:
    # _spack_root -> ../../..
    # -> they have to be preserved
    cp -rlH "${MY_SPACK_FOLDER}" "${tmp_spack_folder}" || return 1

    # perfom the concretization and the fetching into the given subfolder
    ${tmp_spack_bin} --verbose fetch -D "${@}" || return 1

    # hardlink the locally downloaded cache back into the main spack folder
    cp -ruln "${tmp_spack_folder}/var/spack/cache" "${MY_SPACK_FOLDER}/var/spack/" || return 1

    rm -rf "${tmp_spack_folder}" || return 1
}

for package in "${packages_to_fetch[@]}"; do
    echo "Fetching ${package}.."
    # pause if we have sufficient concretizing jobs
    set +x  # do not clobber build log so much
    while (( $(jobs | wc -l) >= num_jobs_fetch )); do
        # call jobs because otherwise we will not exit the loop
        jobs &>/dev/null
        sleep 1
    done
    set -x
    tmp_err="$(mktemp)"
    tmpfiles_fetch_err+=("${tmp_err}")
    # we need to strip the compiler spec starting with '%' from the spec string
    # because the compiler is not yet known
    ( set -x; \
        ( fetch_spack_package "${package%%%*}" ) 2>"${tmp_err}" \
        || ( echo "FETCH FAILED" >> "${tmpfiles_fetch_err[0]}" )) &
done
# wait for all spawned jobs to complete
wait

# verify that all fetches were successful
if (( $(cat "${tmpfiles_fetch_err[@]}" | wc -l) > 0 )); then
    {
        if (( $(wc -l <"${tmpfiles_fetch_err[0]}") > 0)); then
            echo -n "ERROR: "
        else
            echo -n "WARN: "
        fi
        echo "Encountered the following during concretizations prior to fetching:"
        cat "${tmpfiles_fetch_err[@]}"
    } | tee errors_concretization.log
    if (( $(wc -l <"${tmpfiles_fetch_err[0]}") > 0)); then
        exit 1
    fi
fi


# update download_cache
rsync -av "${PWD}/spack/var/spack/cache/" "${HOME}/download_cache/"


# remove f***ing compiler config
rm ${PWD}/spack/etc/spack/compilers.yaml
