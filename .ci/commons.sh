#!/bin/bash

set -euo pipefail

JENKINS_ENV_FILE_INSIDE="/tmp/spack/jenkins.env"
if [ -n "${WORKSPACE:-}" ]; then
    # we are not in container
    JENKINS_ENV_FILE="${WORKSPACE}/jenkins.env"
else
    JENKINS_ENV_FILE="${JENKINS_ENV_FILE_INSIDE}"
fi

# Usage:
#   get_jenkins_env <variable-name>
#
# Get <variable-name> from the jenkins environment dumped at the start of the
# jenkins job.  If the jenkins environment was not dumped at the beginning of
# the jenkins job, the regular environment is taken.
#
# If the variable is not found, return 1.
get_jenkins_env() {
    # match on variable name at the beginning of line and then delete everyting
    # up to and including the first equal sign
    {
        if [ -f "${JENKINS_ENV_FILE}" ]; then
            cat ${JENKINS_ENV_FILE}
        else
            env
        fi
    } | grep "^$*=" | sed -e "s:[^=]*=::" \
    || ( echo "Variable not found in environment: $*" >&2; return 1 )
}

export MY_SPACK_FOLDER=/opt/spack
export MY_SPACK_BIN=/opt/spack/bin/spack
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

export LOCK_FILENAME=lock

BUILD_CACHE_NAME="$(get_jenkins_env BUILD_CACHE_NAME)"
if [ -z "${BUILD_CACHE_NAME:-}" ]; then
    BUILD_CACHE_NAME=visionary_manual
fi
export BUILD_CACHE_NAME

# NOTE: build caches contain relavite symlinks to preserved_packages, so the
# relation that build_caches and preserved_packages are in the same folder
# should be maintained inside the container!
# --obreitwi, 17-06-20 12:53:20

BASE_BUILD_CACHE_OUTSIDE="$(get_jenkins_env HOME)/build_caches"
BASE_BUILD_CACHE_FAILED_OUTSIDE="$(get_jenkins_env HOME)/build_caches/failed"
BUILD_CACHE_OUTSIDE="${BASE_BUILD_CACHE_OUTSIDE}/${BUILD_CACHE_NAME}"
export BASE_BUILD_CACHE_OUTSIDE
export BASE_BUILD_CACHE_FAILED_OUTSIDE
export BUILD_CACHE_OUTSIDE

BASE_BUILD_CACHE_INSIDE="/opt/build_cache"
BUILD_CACHE_INSIDE="${BASE_BUILD_CACHE_INSIDE}/${BUILD_CACHE_NAME}"
BUILD_CACHE_LOCK="${BUILD_CACHE_INSIDE}/${LOCK_FILENAME}"
export BASE_BUILD_CACHE_INSIDE
export BUILD_CACHE_INSIDE
export BUILD_CACHE_LOCK

SOURCE_CACHE_DIR="$(get_jenkins_env HOME)/download_cache"
export SOURCE_CACHE_DIR

PRESERVED_PACKAGES_INSIDE="/opt/preserved_packages"
PRESERVED_PACKAGES_OUTSIDE="$(get_jenkins_env HOME)/preserved_packages"
export PRESERVED_PACKAGES_INSIDE
export PRESERVED_PACKAGES_OUTSIDE

COMMONS_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
export COMMONS_DIR

SPACK_INSTALL_SCRIPTS="/opt/spack_install_scripts"
export SPACK_INSTALL_SCRIPTS

SPEC_FOLDER_IN_CONTAINER="/opt/spack_specs"
export SPEC_FOLDER_IN_CONTAINER

if [ -d "${SPEC_FOLDER_IN_CONTAINER}" ]; then
    # only valid in container
    SPEC_FOLDER="${SPEC_FOLDER_IN_CONTAINER}"
else
    SPEC_FOLDER="$(mktemp -d)"
fi
export SPEC_FOLDER

###############
# BOOKKEEPING #
###############

# bash only supports a single function for the exit trap, so we store all functions to execute in an array an iterate over it
if [[ ! -v _yashchiki_exit_fns[@] ]]; then
    _yashchiki_exit_fns=()

    _yashchiki_exit_trap() {
        for fn in "${_yashchiki_exit_fns[@]}"; do
            eval "${fn}"
        done
    }

    trap _yashchiki_exit_trap EXIT

    add_cleanup_step() {
        for fn in "$@"; do
            _yashchiki_exit_fns+=("${fn}")
        done
    }
fi

############
# PACKAGES #
############

# Usage: get_pinned_deps <name>
#
# Note: This pinning is used only to help the concretizer make suitable picks.
# The actual incompatabilities should still be expressed in the spack packages.
#
# The real reason for this machinery is the fact that the concretizer, despite
# specifying which version of the package is compatible with python 2 and 3, is
# unable to determine the last version still compatible with python 2
#
# Arguments:
#   <name> has to correspond to a list of pinned dependencies residing under
#   <yashchiki-root>/container-build-files/pinned/<name>.list
#   The file should contain a list of spec constraints (one spec per line).
#   Lines starting with and everything followed by # will be considered
#   comments and removed.
get_pinned_deps() {
    local depsname="${1}"
    local filename="${COMMONS_DIR}/pinned/${depsname}.list"

    if [ ! -f "${filename}" ]; then
        echo "ERROR: No dependencies for ${depsname} found at ${filename}!" >&2
        exit 1
    fi
    # The grep call removes lines starting with # as well as blank lines. sed
    # then removes trailing comments. Afterwards we insert a tilde (^) in front
    # of every line (i.e., dependency) and join all lines by replacing the
    # newline character with spaces.
    grep -v "\(^#\|^\s*$\)" "${filename}" | sed -e "s:#.*$::" \
        | sed -e "s:^:\^:" | tr '\n' ' '
}

# the version of dev tools we want in our view
SPEC_VIEW_VISIONARY_DEV_TOOLS="visionary-dev-tools ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"

# All spack packages that should be fetched/installed in the container
spack_packages=(
    "${SPEC_VIEW_VISIONARY_DEV_TOOLS}"
    "visionary-simulation~dev ^${DEPENDENCY_PYTHON} $(get_pinned_deps simulation) %${VISIONARY_GCC}"
    "visionary-simulation ^${DEPENDENCY_PYTHON} $(get_pinned_deps simulation) %${VISIONARY_GCC}"
    "visionary-spikey~dev ^${DEPENDENCY_PYTHON} $(get_pinned_deps spikey_wout_dev) %${VISIONARY_GCC}"
    "visionary-spikey ^${DEPENDENCY_PYTHON} $(get_pinned_deps spikey_w_dev) %${VISIONARY_GCC}"
    "visionary-wafer~dev ^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer ^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer ~dev+gccxml^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer ~dev+tensorflow^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer ~dev+gccxml+tensorflow^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer+gccxml ^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer+tensorflow ^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer+gccxml +tensorflow^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer) %${VISIONARY_GCC}"
    "visionary-wafer-visu ^${DEPENDENCY_PYTHON} $(get_pinned_deps wafer-visu) %${VISIONARY_GCC}"
    # START python 3 packages
    "visionary-slurmviz ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-dls~dev ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "visionary-dls ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "py-jupyterhub ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "py-jupyterhub-dummyauthenticator ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    "py-jupyterhub-simplespawner ^${DEPENDENCY_PYTHON3} %${VISIONARY_GCC}"
    # END python 3 packages
)

# WIP fix to allow all software to run on AMTHosts, more permanent solution is
# forthcoming.
# Note: We insert target directly after the package name and variants (i.e.,
# the first space) in order to deal with concretization errors that sometimes
# occur if target is specified too far back in the string.
# --obreitwi, 21-10-19 14:33:45
PINNED_TARGET="sandybridge"
spack_packages=( "${spack_packages[@]/ / target=${PINNED_TARGET} }" )

# control view creation with verbosity for more debuggability
SPACK_VIEW_ARGS="--verbose"

# TODO: Keep in sync with <spack-repo>/lib/spack/spack/cmd/bootstrap.py since
# there is no straight-forward way to extract bootstrap dependencies
# automatically. If bootstrap dependencies should change we will notice because
# they won't be able to be fetched inside the container because of missing
# permissions.
spack_bootstrap_dependencies=(
    "environment-modules~X target=x86_64"
)

#########
# VIEWS #
#########

# Views are put under /opt/spack_views/visionary-xy
# The app names are then just xy for smaller terminal lines.

spack_views=(\
        visionary-dev-tools
        visionary-dls-core
        visionary-dls
        visionary-dls-nodev
        visionary-simulation
        visionary-simulation-nodev
        visionary-spikey
        visionary-spikey-nodev
        visionary-wafer
        visionary-wafer-nodev
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
for view in visionary-wafer{,-nodev}; do
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

if (( reset_lastpipe )); then
    # restore defaults
    shopt -u lastpipe
fi

##############################
# HELPER FUNCTIONS FOR VIEWS #
##############################

# Execute commands in given FILEs in parallel subshells.
#
# Usage:
#   parallel_cmds [options] [FILE..]
#
# Please note that these lines cannot share state because each is executed
# essentially in parallel in its own subshell.
#
# If FILE is omitted, commands are read from stdin.
#
# Options:
#   -j <num>    Number of parallel jobs [default: all available]
#
parallel_cmds() {
    local num_jobs
    num_jobs="$(nproc)"
    while getopts ":j:" opt
    do
        case $opt in
            j) num_jobs="${OPTARG}" ;;
            *) echo -e "Invalid option to parallel_cmds(): $OPTARG\n" >&2; exit 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    grep -v "^\(#\|[[:space:]]*$\)" "${@}" | parallel -j "${num_jobs}"
}

populate_views() {
    # Since each package may add to overlapping sets of views, we perform each
    # addition on its own to be on the safe side.
    # Due to the fact that we simply ignore file duplicates if several spack
    # packages get linked into the same view and the random order of execution
    # in a parallel context, builds might become unstable otherwise.
    for addition in "${!spack_add_to_view[@]}"; do
        local dependencies="${spack_add_to_view_with_dependencies["${addition}"]}"
        {
            for viewname in ${spack_add_to_view["${addition}"]}; do
                echo "${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d ${dependencies} symlink -i \"${MY_SPACK_VIEW_PREFIX}/${viewname}\" \"${addition}\""
            done
        } | parallel_cmds
    done
}



#################################
# HELPER FUNCTIONS NEEDED BELOW #
#################################

# Usage:
#       lock_file [-e] [-w <sec>] <file>
#
# Lock the given file, the file will be unlocked once the process exits. Make
# sure to only use it in subshells to automatically unlock afterwards.
#
# Args:
#   -e          Lock exculsively (otherwise shared)
#   -w <secs>   How long to wait for lock until retrying. [default: 10]
#
lock_file() {
    local OPTIND
    local opt
    local args_flock=()
    local exclusive=0
    local info_exclusive=""
    local wait_secs=10

    while getopts ":ew:" opt
    do
        case $opt in
            e) exclusive=1 ;;
            w) wait_secs="${OPTARG}" ;;
            *) echo -e "Invalid option to lock_file(): $OPTARG\n" >&2; exit 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    local fd_lock
    local filename_lock="$1"
    # ensure that we can always access lockfile 
    if [ ! -f "${filename_lock}" ]; then
        touch "${filename_lock}"
        chmod 777 "${filename_lock}"
    fi
    exec {fd_lock}>"${filename_lock}"

    if (( exclusive == 1 )); then
        args_flock+=( "-e" )
        info_exclusive="(exclusively) "
    else
        args_flock+=( "-s" )
        info_exclusive="(shared) "
    fi

    while /bin/true; do
        echo "Obtaining build_cache lock ${info_exclusive}from ${filename_lock}." 1>&2
        flock ${args_flock[*]} -w "${wait_secs}" ${fd_lock} && break \
            || echo "Could not lock ${filename_lock}, retrying in ${wait_secs} seconds.." 1>&2
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
add_cleanup_step remove_tmp_files


# get hashes in buildcache [<build_cache-directory>]
# <buildcache-directory> defaults to ${BUILD_CACHE_INSIDE} if not supplied.
get_hashes_in_buildcache() {
    local buildcache_dir
    buildcache_dir="${1:-${BUILD_CACHE_INSIDE}}"

    local resultsfile
    resultsfile=$(mktemp)

    if [ -d "${buildcache_dir}" ]; then
        # Naming scheme in the build_cache is <checksum>.tar.gz -> extract from full path
        ( find "${buildcache_dir}" -name "*.tar.gz" -mindepth 1 -maxdepth 1 -print0 \
            | xargs -0 -n 1 basename \
            | sed -e "s:\.tar\.gz$::g" \
	    | sort >"${resultsfile}") || /bin/true
    fi
    echo "DEBUG: Found $(wc -l <"${resultsfile}") hashes in buildcache: ${buildcache_dir}" >&2
    cat "${resultsfile}"
    rm "${resultsfile}"
}


get_hashes_in_spack() {
    ${MY_SPACK_BIN} find -L | awk '/^[a-z0-9]/ { print $1 }' | sort
}


compute_hashes_buildcache() {
    # extract all available package hashes from buildcache
    get_hashes_in_buildcache >"${FILE_HASHES_BUILDCACHE}"
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

    # TODO: DELME
    for sf in "${specfiles[@]}"; do
        if grep broadwell "${sf}" >/dev/null; then
            {
                echo "Found target broadwell in specfile, aborting:"
                head -n 10 "${sf}"
            } >&2
            exit 1
        fi
    done

    for f in "${specfiles[@]}"; do
        echo "${f}"
    done
}

install_from_buildcache() {
    local install_failed=0
    # don't forget to unlock builcache in case of error, but then propagate
    (
        lock_file "${BUILD_CACHE_LOCK}"
        _install_from_buildcache "${@}"
    ) || install_failed=1

    if (( install_failed == 1 )); then
        echo "Error during builcache install!" >&2
        exit 1
    fi
}

_install_from_buildcache() {
    # only extract the hashes present in buildcache on first invocation
    if (( "$(wc -l <"${FILE_HASHES_BUILDCACHE}")" == 0 )); then
        compute_hashes_buildcache
    fi

    local specfiles=()
    local packages_to_install=("${@}")
    readarray -t specfiles < <(get_specfiles "${packages_to_install[@]}")

    # check again that specfiles are not empty - otherwise a concretization failed
    echo "DEBUG: Checking specfiles for ${packages_to_install[*]}" >&2
    for spec in "${specfiles[@]}"; do
        if (( $(wc -l <"${spec}") == 0 )); then
            echo "One of the following specs failed to concretize: " \
                 "${packages_to_install[@]}" >&2
            exit 1
        fi
    done

    # install packages from buildcache
    cat "${specfiles[@]}" | sed -n 's/.*hash:\s*\(.*\)/\1/p' > "${FILE_HASHES_SPACK_ALL}"

    # make each unique
    cat "${FILE_HASHES_SPACK_ALL}" | sort | uniq > "${FILE_HASHES_SPACK}"

    # install if available in buildcache
    cat "${FILE_HASHES_SPACK}" "${FILE_HASHES_BUILDCACHE}" | sort | uniq -d > "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"

    parallel -v -j $(nproc) tar Pxf "${BUILD_CACHE_INSIDE}/{}.tar.gz" \
        < "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"

    # have spack reindex its install contents to find the new packages
    ${MY_SPACK_BIN} --verbose reindex
}

get_latest_failed_build_cache_name() {
    local full_change_num
    local possible_build_caches
    local latest_patch_level
    local latest_build_num

    full_change_num="$(get_change_name)"
    change_num="${full_change_num%%p*}"
    possible_build_caches="$(mktemp)"

    find "${BASE_BUILD_CACHE_FAILED_OUTSIDE}" -mindepth 1 -maxdepth 1 -type d -name "${change_num}*" -print0 \
        | xargs -n 1 -r -0 basename > "${possible_build_caches}"

    if (( $(wc -l <"${possible_build_caches}") == 0 )); then
        return 0
    fi

    latest_patch_level="$(cat "${possible_build_caches}" \
        | cut -d p -f 2 | cut -d _ -f 1 | sort -rg | head -n 1)"

    latest_build_num="$(grep "p${latest_patch_level}_" "${possible_build_caches}" \
        | cut -d _ -f 2 | sort -rg | head -n 1)"

    echo -n "c${change_num}p${latest_patch_level}_${latest_build_num}"

    rm "${possible_build_caches}"
}


#############
# UTILITIES #
#############

get_change_name() {
    local change_num
    local patch_level

    local gerrit_change_number
    local gerrit_patchset_number
    local gerrit_refspec

    gerrit_change_number="$(get_jenkins_env GERRIT_CHANGE_NUMBER)"
    gerrit_patchset_number="$(get_jenkins_env GERRIT_PATCHSET_NUMBER)"
    gerrit_refspec="$(get_jenkins_env GERRIT_REFSPEC)"

    if [ -z "${gerrit_change_number:-}" ]; then
        if [ -n "${gerrit_refspec:-}" ]; then
            # extract gerrit change number from refspec
            change_num="$(echo "${gerrit_refspec}" | cut -f 4 -d / )"
            patch_level="$(echo "${gerrit_refspec}" | cut -f 5 -d / )"
        fi
    else
        change_num="${gerrit_change_number}"
        patch_level="${gerrit_patchset_number}"
    fi
    echo -n "c${change_num}p${patch_level}"
}

# copied from slurmviz-commons.sh
get_latest_hash() {
  # Usage: get_latest_hash <pkg-name>
  #
  # Get the latest hash of a given package in the spack installation. This
  # takes into account compiler version, so if a package is available by two
  # compiler versions, the newer one is taken.
  FILE_AWK=$(mktemp)
  cat >"${FILE_AWK}" <<EOF
/^--/ {
  # \`spack find\` sorts installed specs by compiler, these lines start with
  # two dashes and we can hence identify the compiler name in the fourth field.
  compiler=\$4
}

/^[a-z0-9]/ {
  # insert compiler name into spec name at appropriate position (i.e., prior to
  # specifying any variants)
  # \$1 is the hash, \$2 is the spec
  idx = match(\$2, /(\\+|\\~|$)/);
  printf("%s%%%s%s /%s\\n", substr(\$2, 0, idx-1), compiler, substr(\$2, idx), \$1)
}
EOF
  ${MY_SPACK_BIN} find -vL "$@" | awk -f "${FILE_AWK}"| sort -V | cut -d ' ' -f 2 | tail -n 1
  rm "${FILE_AWK}"
}
