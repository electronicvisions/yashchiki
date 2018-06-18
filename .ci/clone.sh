#!/bin/bash -x

if [ -z "${SPACK_BRANCH}" ]; then
    echo "SPACK_BRANCH not set?!?"
    exit 1
fi

export MY_GERRIT_BASE_URL="ssh://hudson@brainscales-r.kip.uni-heidelberg.de:29418/"

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
