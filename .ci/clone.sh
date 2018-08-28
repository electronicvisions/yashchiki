#!/bin/bash -x

if [ -z "${GERRIT_USERNAME}" ]; then
    GERRIT_USERNAME="hudson"
fi

if [ -z "${GERRIT_PORT}" ]; then
    GERRIT_PORT=29418
fi

if [ -z "${GERRIT_HOSTNAME}" ]; then
    GERRIT_HOSTNAME="brainscales-r.kip.uni-heidelberg.de"
fi

if [ -z "${GERRIT_BASE_URL}" ]; then
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

if [ -z "${SPACK_GERRIT_CHANGE}" ] && [ -z "${SPACK_GERRIT_REFSPEC}" ]; then
    # see if the commit message contains a "Depends-On: xy" line
    # if there are several lines, concatenate with commas
    SPACK_GERRIT_CHANGE=$(git log -1 --pretty=%B \
        | awk '$1 ~ "Depends-On:" { $1 = ""; print $0 }' | tr '\n' ',' | tr -d \[:space:\])
else
    echo "SPACK_GERRIT_CHANGE or SPACK_GERRIT_REFSPEC specified, ignoring "\
         "possible 'Depends-On'-line in commit message!"
fi

# if there is a spack gerrit change specified and no refspec -> resolve!
if [ -n "${SPACK_GERRIT_CHANGE}" ] && [ -z "${SPACK_GERRIT_REFSPEC}" ]; then
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

if [ "${CONTAINER_BUILD_TYPE}" = "testing" ] && [ -n "${SPACK_GERRIT_REFSPEC}" ]; then
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
${MY_SPACK_BIN} mirror add --scope site job_mirror file://${HOME}/download_cache

# add system compiler (needed for fetching)
${MY_SPACK_BIN} compiler add --scope site /usr/bin

# Need KIP proxy to fetch all the packages (also needed in container due to pip)
export http_proxy=http://proxy.kip.uni-heidelberg.de:8080
export https_proxy=http://proxy.kip.uni-heidelberg.de:8080

# fetch "everything" (except for pip shitness)
echo "FETCHING..."
${MY_SPACK_BIN} fetch --dependencies gcc@7.2.0 || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-defaults+tensorflow+gccxml || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-analysis || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-dev-tools || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-dls+gccxml || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-simulation || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-spikey || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-wafer+gccxml || exit 1

# update download_cache
rsync -av ${PWD}/spack_${SPACK_BRANCH}/var/spack/cache/ ${HOME}/download_cache/

# remove job_mirror again (re-added in container)
${MY_SPACK_BIN} mirror rm --scope site job_mirror

# remove f***ing compiler config
rm ${PWD}/spack_${SPACK_BRANCH}/etc/spack/compilers.yaml

# create hardlinked ccache folder
if [ -d ${HOME}/ccache ]; then
    cp -rl ${HOME}/ccache .
else
    mkdir ccache/
fi
chmod -R 777 ccache/

# create hardlinked build_cache folder
if [ -d ${HOME}/build_cache ]; then
    cp -rl ${HOME}/build_cache .
else
    mkdir build_cache/
fi
chmod -R 777 build_cache/
