#!/bin/bash -x

if [ -z "${SPACK_BRANCH}" ]; then
    echo "SPACK_BRANCH not set?!?"
    exit 1
fi

if [ -z "${MY_GERRIT_BASE_URL}" ]; then
    export MY_GERRIT_BASE_URL="ssh://hudson@brainscales-r.kip.uni-heidelberg.de:29418/"
fi

# clone spack installation ouside and copy into the container
MY_GERRIT_URL="${MY_GERRIT_BASE_URL}/spack"
rm -rf spack_${SPACK_BRANCH}
git clone ${MY_GERRIT_URL} -b ${SPACK_BRANCH} spack_${SPACK_BRANCH}

# TODO: also watch for spack changes...
if [ -n "${SPACK_GERRIT_REFSPEC}" ]; then
    echo "SPACK_GERRIT_REFSPEC was specified: ${SPACK_GERRIT_REFSPEC} -> checking out"
    cd spack_${SPACK_BRANCH}
    git fetch  ${MY_GERRIT_URL} ${SPACK_GERRIT_REFSPEC} && git checkout FETCH_HEAD
    cd ..
fi

# set download mirror stuff to prefill outside of container
export MY_SPACK_BIN=$PWD/spack_${SPACK_BRANCH}/bin/spack
${MY_SPACK_BIN} mirror rm --scope site global
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
${MY_SPACK_BIN} fetch --dependencies visionary-defaults-analysis || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-defaults-developmisc || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-defaults-dls+gccxml || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-defaults-simulation || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-defaults-spikey || exit 1
${MY_SPACK_BIN} fetch --dependencies visionary-defaults-wafer+gccxml || exit 1

# update download_cache
rsync -rv ${PWD}/spack_${SPACK_BRANCH}/var/spack/cache/ ${HOME}/download_cache/

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
