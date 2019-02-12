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
rm -rf spack_${SPACK_BRANCH}
git clone ${MY_GERRIT_URL} -b ${SPACK_BRANCH} spack_${SPACK_BRANCH}


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
         "possible 'Depends-On'-line in commit message!"
fi

# if there is a spack gerrit change specified and no refspec -> resolve!
if [ -n "${SPACK_GERRIT_CHANGE:-}" ] && [ -z "${SPACK_GERRIT_REFSPEC:-}" ]; then
    # convert spack change id to latest patchset
    pushd "spack_${SPACK_BRANCH}"

    gerrit_query=$(mktemp)

    for change in ${SPACK_GERRIT_CHANGE//,/ }; do
        ssh -p ${GERRIT_PORT} \
               ${GERRIT_USERNAME}@${GERRIT_HOSTNAME} gerrit query \
               --current-patch-set ${change} > ${gerrit_query}

        SPACK_GERRIT_REFSPEC=$(grep "^[[:space:]]*ref:" ${gerrit_query} \
            | cut -d : -f 2 | tr -d \[:space:\])

        # break as soon as we have the change for the spack repo
        if [ -n "${SPACK_GERRIT_REFSPEC}" ]; then
            # in case we have a stable build, just make sure that the change we
            # depend on has been merged, if not -> fail early!
            if [ "${CONTAINER_BUILD_TYPE}" = "stable" ]; then
                if [ "$(awk '$1 ~ "status:" { print $2 }' "${gerrit_query}")" != "MERGED" ]; then
                    echo "This change depends on unmerged spack changeset! Aborting.." >&2
                    rm "${gerrit_query}"
                    exit 1
                fi
            fi
            break
        fi
    done

    rm "${gerrit_query}"

    popd
fi

if [ "${CONTAINER_BUILD_TYPE}" = "testing" ] && [ -n "${SPACK_GERRIT_REFSPEC:-}" ]; then
    echo "SPACK_GERRIT_REFSPEC was specified: ${SPACK_GERRIT_REFSPEC} -> checking out"
    pushd "spack_${SPACK_BRANCH}"
    git fetch  ${MY_GERRIT_URL} ${SPACK_GERRIT_REFSPEC} && git checkout FETCH_HEAD
    popd
fi

# hard-link download cache into spack folder to avoid duplication
mkdir -p ${PWD}/spack_${SPACK_BRANCH}/var/spack/cache/
cp -vrl $HOME/download_cache/* ${PWD}/spack_${SPACK_BRANCH}/var/spack/cache/

# set download mirror stuff to prefill outside of container
export MY_SPACK_BIN=$PWD/spack_${SPACK_BRANCH}/bin/spack
${MY_SPACK_BIN} mirror rm --scope site global
# TODO: delme (download cache is handled manually)
${MY_SPACK_BIN} mirror add --scope site job_mirror "file://${HOME}/download_cache"

# add system compiler (needed for fetching)
${MY_SPACK_BIN} compiler add --scope site /usr/bin

# Need KIP proxy to fetch all the packages (also needed in container due to pip)
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

# fetch "everything" (except for pip shitness)
echo "FETCHING..."

tmpfiles_fetch=()
tmpfiles_err=()
rm_tmp_to_fetch() {
    rm -v "${tmpfiles_fetch[@]}"
    rm -v "${tmpfiles_err[@]}"
}
trap rm_tmp_to_fetch EXIT

# concretize all spack packages in parallel -> fetch once!
packages_to_concretize=( "${VISIONARY_GCC}" "${spack_packages[@]}" )
for package in "${packages_to_concretize[@]}"; do
    # pause if we have sufficient concretizing jobs
    set +x # do not clobber build log so much
    while (( $(jobs | wc -l) >= $(nproc) )); do
        sleep 1
    done
    set -x
    tmp="$(mktemp)"
    tmp_err="$(mktemp)"
    tmpfiles_fetch+=("${tmp}")
    tmpfiles_err+=("${tmp_err}")
    # we need to strip the compiler spec from the package description because
    # the compiler is not yet known to spack
    # awk transforms the list of dependencies to a list of specs, skipping the
    # header in the beginning
    (${MY_SPACK_BIN} spec "${package//%*[![:space:]]/}" \
        | awk 'header_line >= 2 { gsub(/^\s*\^/, ""); print } /^-/ { header_line+=1 }' \
        1>"${tmp}" 2>"${tmp_err}" ) &
done
# wait for all spawned jobs to complete
wait

# verify that all concretizations were successful
if (($(cat "${tmpfiles_err[@]}" | wc -l) > 0)); then
    echo "ERROR: Encountered the following during concretizations:" >&2
    cat "${tmpfiles_err[@]}" >&2
    exit 1
fi

# prevent readarray from being executed in pipe subshell
reset_lastpipe=0
if ! shopt -q lastpipe; then
    shopt -s lastpipe
    reset_lastpipe=1
fi

# make sure we fetch everything once and only take name and variants of each
# package (everything up to compiler spec)
sort "${tmpfiles_fetch[@]}" | uniq | awk -F '%' '{ print $1 }' | readarray -t packages_to_fetch

if (( reset_lastpipe )); then
    # restore defaults
    shopt -u lastpipe
fi

for package in "${packages_to_fetch[@]}"; do
    # pause if we have sufficient concretizing jobs
    set +x # do not clobber build log so much
    while (( $(jobs | wc -l) >= $(nproc) )); do
        sleep 1
    done
    set -x
    ${MY_SPACK_BIN} fetch "${package}" &
done
# wait for all spawned jobs to complete
wait

# update download_cache
rsync -av "${PWD}/spack_${SPACK_BRANCH}/var/spack/cache/" "${HOME}/download_cache/"

# remove job_mirror again (re-added in container)
${MY_SPACK_BIN} mirror rm --scope site job_mirror

# remove f***ing compiler config
rm ${PWD}/spack_${SPACK_BRANCH}/etc/spack/compilers.yaml
