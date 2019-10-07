#!/bin/bash

set -euo pipefail

export MY_SPACK_FOLDER=/opt/spack
export MY_SPACK_BIN=/opt/spack/bin/spack
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

LOCK_FOLDER_INSIDE=/opt/lock
LOCK_FOLDER_OUTSIDE=/home/vis_jenkins/lock

if [ -z "${BUILD_CACHE_NAME:-}" ]; then
    BUILD_CACHE_NAME=visionary_manual
fi

BUILD_CACHE_INSIDE="/opt/build_cache"
BUILD_CACHE_LOCK="${LOCK_FOLDER_INSIDE}/build_cache_${BUILD_CACHE_NAME}"
BUILD_CACHE_OUTSIDE="${HOME}/build_caches/${BUILD_CACHE_NAME}"

SPACK_INSTALL_SCRIPTS="/opt/spack_install_scripts"

SPEC_FOLDER_IN_CONTAINER="/opt/spack_specs"

if [ -d "${SPEC_FOLDER_IN_CONTAINER}" ]; then
    # only valid in container
    SPEC_FOLDER="${SPEC_FOLDER_IN_CONTAINER}"
else
    SPEC_FOLDER="$(mktemp -d)"
fi

############
# PACKAGES #
############

# the version of dev tools we want in our view
SPEC_VIEW_VISIONARY_DEV_TOOLS="visionary-dev-tools^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"

# All spack packages that should be fetched/installed in the container
spack_packages=(
    "${SPEC_VIEW_VISIONARY_DEV_TOOLS}"
    "visionary-nux~dev %${VISIONARY_GCC}"
    "visionary-nux %${VISIONARY_GCC}"
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
    "visionary-slurmviz^${DEPENDENCY_PYTHON} %${VISIONARY_GCC}"
    # START python 3 packages
    "visionary-dls~dev^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-dls^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-dls~dev+gccxml^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-dls+gccxml^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-dls-demos^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-exa^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-exa~dev^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "py-jupyterhub^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "py-jupyterhub-dummyauthenticator^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "py-jupyterhub-simplespawner^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    # END python 3 packages
)

# control view creation with verbosity for more debuggability
SPACK_VIEW_ARGS="--verbose"

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

# Views are put under /opt/spack_views/visionary-xy
# The app names are then just xy for smaller terminal lines.

spack_views=(\
        visionary-dev-tools
        visionary-dls
        visionary-dls-without-dev
        visionary-simulation
        visionary-simulation-without-dev
        visionary-spikey
        visionary-spikey-without-dev
        visionary-wafer
        visionary-wafer-without-dev
        visionary-exa
        visionary-exa-without-dev
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
for view in visionary-{dls,dls-py3,wafer}{,-without-dev}; do
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
            ${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d ${dependencies} symlink -i "${MY_SPACK_VIEW_PREFIX}/${viewname}" "${addition}"
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


# get hashes in buildcache
get_hashes_in_buildcache() {
    if [ -d "${BUILD_CACHE_INSIDE}" ]; then
        # Naming scheme in the build_cache is <checksum>.tar.gz -> extract from full path
        ( find "${BUILD_CACHE_INSIDE}" -name "*.tar.gz" -print0 \
            | xargs -0 -n 1 basename \
            | sed -e "s:\.tar\.gz$::g" \
	    | sort ) || /bin/true
    fi
}


get_hashes_in_spack() {
    ${MY_SPACK_BIN} find -L | awk '/^[a-z0-9]/ { print $1 }' | sort
}


compute_hashes_buildcache() {
    # extract all available package hashes from buildcache
    get_hashes_in_buildcache > "${FILE_HASHES_BUILDCACHE}"
}


# Get the name of given package name, should only be called if one does not
# depend on the specfile existing or having correct content, see
# get_specfiles().
get_specfile_name() {
    echo -n "${SPEC_FOLDER}/$(echo "$1" | sha256sum |
                              awk '{ print "spec_" $1 ".yaml" }')"
}

# Compute the concrete specfile for the given packages.
#
# Spec files are only computed once and afterwards their names are emitted via
# stdout, one per line.
#
# We want to achieve the following:
# * Compute the specfiles once and then - for the same input-spec, i.e., the
#   string that gets fed to `spack spec` - get the name of the already computed
#   specfile.
# * Do not deal with all the funny characters that appear and might appear in
#   spec-formats in the future.
# Instead of turning the intput-spec into a filename by replacing all spaces,
# slashes, tildes etc, we just take the sha256 of the input-spec. This is
# achieved via taking the sha256sum. This is NOT the hash of the spec (because
# this can only be computed once the spec is fully concretized)! It is merely a
# way to reliably know where the fully-contretized spec is stored for a given
# user-supplied input-spec.
#
# The spec files are put under ${SPEC_FOLDER}.
#
get_specfiles() {
    local specfiles=()

    for package in "${@}"; do
        # compute spec and put into temporary file derived from package name
        specfiles+=("$(get_specfile_name "${package}")")
    done

    (
    local idx=0
    for package in "${@}"; do
        if [ ! -f "${specfiles[${idx}]}" ]; then
            echo "${MY_SPACK_BIN} spec -y \"${package}\" > ${specfiles[${idx}]}"
        fi
        idx=$((idx + 1))
    done
    ) | parallel -j$(nproc) 1>/dev/null

    for f in "${specfiles[@]}"; do
        echo "${f}"
    done
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

    local specfiles=()
    local packages_to_install=("${@}")
    readarray -t specfiles < <(get_specfiles "${packages_to_install[@]}")

    # install packages from buildcache
    cat "${specfiles[@]}" | sed -n 's/.*hash:\s*\(.*\)/\1/p' > "${FILE_HASHES_SPACK_ALL}"

    # make each unique
    cat ${FILE_HASHES_SPACK_ALL} | sort | uniq > ${FILE_HASHES_SPACK}

    # install if available in buildcache
    cat "${FILE_HASHES_SPACK}" "${FILE_HASHES_BUILDCACHE}" | sort | uniq -d > "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"

    parallel -v -j $(nproc) tar Pxf "${BUILD_CACHE_INSIDE}/{}.tar.gz" \
        < "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"

    # have spack reindex its install contents to find the new packages
    ${MY_SPACK_BIN} --verbose reindex
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
