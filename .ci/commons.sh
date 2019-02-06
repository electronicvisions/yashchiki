#!/bin/bash

set -euo pipefail

export MY_SPACK_FOLDER=/opt/spack_${SPACK_BRANCH}
export MY_SPACK_BIN=/opt/spack_${SPACK_BRANCH}/bin/spack
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

LOCK_BUILD_CACHE=/opt/lock/build_cache

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
    find ${BUILD_CACHE_DIR} -name "*.spec.yaml" | sed 's/.*-\([^-]*\)\.spec\.yaml$/\1/' | sort | uniq > "${FILE_HASHES_BUILDCACHE}"
}

install_from_buildcache() {
    # obtain shared lock around buildcache
    exec {lock_fd}>"${LOCK_BUILD_CACHE}"
    flock -sn "${lock_fd}" || { echo "ERROR: flock() failed." >&2; exit 1; }
    _install_from_buildcache "${@}"
    flock -u "${lock_fd}"
}

_install_from_buildcache() {
    # only extract the hashes present in buildcache on first invocation
    if [ "$(cat "${FILE_HASHES_BUILDCACHE}" | wc -l)" -eq 0 ]; then
        compute_hashes_buildcache
    fi

    # install packages from buildcache
    packages_to_install=("${@}")

    echo "" > ${FILE_HASHES_SPACK_ALL}
    for package in "${packages_to_install[@]}"; do
        ${MY_SPACK_BIN} spec -y ${package} | sed -n 's/.*hash:\s*\(.*\)/\1/p' >> ${FILE_HASHES_SPACK_ALL}
    done

    # make each unique
    cat ${FILE_HASHES_SPACK_ALL} | sort | uniq > ${FILE_HASHES_SPACK}

    # install if available in buildcache
    cat ${FILE_HASHES_SPACK} ${FILE_HASHES_BUILDCACHE} | sort | uniq -d > ${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}
    hashes_to_install=$(sed "s:^:/:g" < ${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE} | tr '\n' ' ')
    # TODO verify that -j reads from default config, if not -> add
    ${MY_SPACK_BIN} buildcache install -y -w -j$(nproc) ${hashes_to_install} || true
}
