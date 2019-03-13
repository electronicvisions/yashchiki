#!/bin/bash

set -euo pipefail

export MY_SPACK_FOLDER=/opt/spack_${SPACK_BRANCH}
export MY_SPACK_BIN=/opt/spack_${SPACK_BRANCH}/bin/spack
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

LOCK_FOLDER_INSIDE=/opt/lock
LOCK_FOLDER_OUTSIDE=/home/vis_jenkins/lock

BUILD_CACHE_INSIDE="/opt/build_cache"
BUILD_CACHE_LOCK="${LOCK_FOLDER_INSIDE}/build_cache"
BUILD_CACHE_OUTSIDE="/home/vis_jenkins/build_cache"

SPACK_INSTALL_SCRIPTS="/opt/spack_install_scripts"

############
# PACKAGES #
############

# the version of dev tools we want in our view
SPEC_VIEW_VISIONARY_DEV_TOOLS="visionary-dev-tools^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"

# All spack packages that should be fetched/installed in the container
spack_packages=(
    "visionary-defaults^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-defaults+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-defaults+tensorflow^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-defaults+gccxml+tensorflow^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-analysis~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-analysis^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "${SPEC_VIEW_VISIONARY_DEV_TOOLS}"
    "visionary-dls~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-dls^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-dls~dev+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-dls+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-nux~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-nux^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-simulation~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-simulation^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-spikey~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-spikey^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer~dev^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer~dev+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer~dev+tensorflow^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer~dev+gccxml+tensorflow^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer+gccxml^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer+tensorflow^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer+gccxml+tensorflow^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-wafer-visu %${VISIONARY_GCC}"
    "visionary-dls-demos^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "visionary-slurmviz^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    "py-jupyterhub^python@3.6.8"
    "py-jupyterhub-dummyauthenticator^python@3.6.8"
    "py-jupyterhub-simplespawner^python@3.6.8"
)

# TODO: Keep in sync with <spack-repo>/lib/spack/spack/cmd/bootstrap.py since
# there is no straight-forward way to extract bootstrap dependencies
# automatically. If bootstrap dependencies should change we will notice because
# they won't be able to be fetched inside the container because of missing
# permissions.
spack_bootstrap_dependencies=(
    "environment-modules~X"
)

#########
# VIEWS #
#########

spack_views=(\
        visionary-defaults
        visionary-dev-tools
        visionary-analysis
        visionary-analysis-without-dev
        visionary-dls
        visionary-dls-without-dev
        visionary-simulation
        visionary-simulation-without-dev
        visionary-spikey
        visionary-spikey-without-dev
        visionary-wafer
        visionary-wafer-without-dev
    )

spack_views_no_default_gcc=(
    "visionary-nux" # currenlty visionary-nux is no view, but serves as example
)

# associative array: spec to add -> view names seperated by spaces
declare -A spack_add_to_view
# associative array: spec to add -> "yes" for when dependencies should be added
#                                   "no" otherwise
declare -A spack_add_to_view_with_dependencies

# Add gccxml to those views that still depend on it
spack_add_to_view_with_dependencies["gccxml"]="no"
spack_add_to_view["gccxml"]="$(
for view in visionary-{defaults,dls,dls-demos,wafer}{,-without-dev}; do
    echo ${view}
done | tr '\n' ' '
)"

# all views get the default gcc except those in spack_views_no_default_gcc
# (defined above)
spack_add_to_view_with_dependencies["${VISIONARY_GCC}"]="no"
spack_add_to_view["${VISIONARY_GCC}"]="$(
    for viewname in "${spack_views[@]}"; do
        # check if the current view matches any view that does not get the
        # default gcc
        # Note: Currently this allow partial matches
        if printf "%s\n" "${spack_views_no_default_gcc[@]}" \
                | grep -qF "${viewname}"; then
            continue
        fi
        echo ${viewname}
    done | tr '\n' ' '
)"

# prevent readarray from being executed in pipe subshell
reset_lastpipe=0
if ! shopt -q lastpipe; then
    shopt -s lastpipe
    reset_lastpipe=1
fi

# get spack_package_names from spack_packages
printf "%s\n" "${spack_packages[@]}" | awk -F '~|+| |\\^|%' '{ print $1 }' \
    | sort | uniq | readarray -t spack_package_names

if (( reset_lastpipe )); then
    # restore defaults
    shopt -u lastpipe
fi

##############################
# HELPER FUNCTIONS FOR VIEWS #
##############################

populate_views() {
    for addition in "${!spack_add_to_view[@]}"; do
        local dependencies="${spack_add_to_view_with_dependencies["${addition}"]}"
        for viewname in ${spack_add_to_view["${addition}"]}; do
            ${MY_SPACK_BIN} view -d ${dependencies} hardlink -i "${MY_SPACK_VIEW_PREFIX}/${viewname}" "${addition}"
        done
    done
}

###################################
# HELPER FUNCTIONS FOR BUILDCACHE #
###################################

# setup tempfiles
FILE_HASHES_BUILDCACHE=$(mktemp)
FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE=$(mktemp)
FILE_HASHES_SPACK=$(mktemp)
FILE_HASHES_SPACK_ALL=$(mktemp)

remove_tmp_files() {
    # remove tempfiles
    rm "${FILE_HASHES_BUILDCACHE}"
    rm "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"
    rm "${FILE_HASHES_SPACK}"
    rm "${FILE_HASHES_SPACK_ALL}"
}
trap remove_tmp_files EXIT

compute_hashes_buildcache() {
    # extract all available package hashes from buildcache
    find "${BUILD_CACHE_DIR}" -name "*.spec.yaml" | sed 's/.*-\([^-]*\)\.spec\.yaml$/\1/' | sort | uniq > "${FILE_HASHES_BUILDCACHE}"
}

install_from_buildcache() {
    # obtain shared lock around buildcache
    exec {lock_fd}>"${BUILD_CACHE_LOCK}"
    echo "Locking buildcache (shared).." >&2
    flock -s "${lock_fd}"
    echo "Locked buildcache (shared)." >&2
    _install_from_buildcache "${@}"
    echo "Unlocking buildcache (shared).." >&2
    flock -u "${lock_fd}"
    echo "Unlocked buildcache (shared)." >&2
}

_install_from_buildcache() {
    # only extract the hashes present in buildcache on first invocation
    if [ "$(wc -l < "${FILE_HASHES_BUILDCACHE}")" -eq 0 ]; then
        compute_hashes_buildcache
    fi

    # install packages from buildcache
    packages_to_install=("${@}")

    (
    for package in "${packages_to_install[@]}"; do
        echo "${MY_SPACK_BIN} spec -y ${package} | sed -n 's/.*hash:\s*\(.*\)/\1/p'"
    done
    ) | parallel > "${FILE_HASHES_SPACK_ALL}"

    # make each unique
    cat ${FILE_HASHES_SPACK_ALL} | sort | uniq > ${FILE_HASHES_SPACK}

    # install if available in buildcache
    cat "${FILE_HASHES_SPACK}" "${FILE_HASHES_BUILDCACHE}" | sort | uniq -d > "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"
    hashes_to_install=$(sed "s:^:/:g" < "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}" | tr '\n' ' ')
    # TODO verify that -j reads from default config, if not -> add
    # HOTFIX: halve the number of buildcache worker to circumvent oom-killer
    # Problem (in odd cases round up!)
    ${MY_SPACK_BIN} buildcache install -y -w -j$(( $(nproc) / 2 + $(nproc) % 2 )) ${hashes_to_install} || true
}

#############
# UTILITIES #
#############

# copied from slurmviz-commons.sh
get_latest_version() {
  # Usage: get_latest_version <pkg-name>
  #
  # Get the latest version of a given package in the spack installation. This
  # takes into account compiler version, so if a package is available by two
  # compiler versions, the newer one is taken.
  FILE_AWK=$(mktemp)
  cat >"${FILE_AWK}" <<EOF
/^--/ {
  # \`spack find\` sorts installed specs by compiler, these lines start with
  # two dashes and we can hence identify the compiler name in the fourth field.
  compiler=\$4
}

/^[a-zA-Z]/ {
  # insert compiler name into spec name at appropriate position (i.e., prior to
  # specifying any variants)
  idx = match(\$1, /(\\+|\\~|$)/);
  printf("%s%%%s%s\\n", substr(\$1, 0, idx-1), compiler, substr(\$1, idx))
}
EOF

  ${MY_SPACK_BIN} find -v "$1" | awk -f "${FILE_AWK}"| sort -V | tail -n 1
  rm "${FILE_AWK}"
}
