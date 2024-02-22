#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

ROOT_DIR="$(dirname "$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")")"
SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"

#####################
# SETUP ENVIRONMENT #
#####################

set_debug_output_from_env() {
    # Enable debug if YASHCHIKI_DEBUG is NOT (-n) empty string
    if [ -n "${YASHCHIKI_DEBUG:-}" ]; then
        set -x
    else
        set +x
    fi
}
set_debug_output_from_env

export MY_SPACK_FOLDER=/opt/spack
export MY_SPACK_BIN=/opt/spack/bin/spack
export MY_SPACK_CMD="${MY_SPACK_BIN} --config-scope ${YASHCHIKI_SPACK_CONFIG}"
export MY_SPACK_VIEW_PREFIX="/opt/spack_views"

# NOTE: build caches contain relavite symlinks to preserved_packages, so the
# relation that build_caches and preserved_packages are in the same folder
# should be maintained inside the container!
# --obreitwi, 17-06-20 12:53:20

BASE_BUILD_CACHE_OUTSIDE="${YASHCHIKI_CACHES_ROOT}/build_caches"
BASE_BUILD_CACHE_FAILED_OUTSIDE="${YASHCHIKI_CACHES_ROOT}/build_caches/failed"
BUILD_CACHE_OUTSIDE="${BASE_BUILD_CACHE_OUTSIDE}/${YASHCHIKI_BUILD_CACHE_NAME}"
export BASE_BUILD_CACHE_OUTSIDE
export BASE_BUILD_CACHE_FAILED_OUTSIDE
export BUILD_CACHE_OUTSIDE

BASE_BUILD_CACHE_INSIDE="/opt/build_cache"
BUILD_CACHE_INSIDE="${BASE_BUILD_CACHE_INSIDE}/${YASHCHIKI_BUILD_CACHE_NAME}"
export BASE_BUILD_CACHE_INSIDE
export BUILD_CACHE_INSIDE

SOURCE_CACHE_DIR="${YASHCHIKI_CACHES_ROOT}/download_cache"
export SOURCE_CACHE_DIR

PRESERVED_PACKAGES_INSIDE="/opt/preserved_packages"
PRESERVED_PACKAGES_OUTSIDE="${YASHCHIKI_CACHES_ROOT}/preserved_packages"
export PRESERVED_PACKAGES_INSIDE
export PRESERVED_PACKAGES_OUTSIDE

META_DIR_INSIDE="/opt/meta"
META_DIR_OUTSIDE="${YASHCHIKI_META_DIR:-}"
export META_DIR_INSIDE
export META_DIR_OUTSIDE

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
        for fn in "${_yashchiki_exit_fns[@]+"${_yashchiki_exit_fns[@]}"}"; do
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

# used in VIEWS section below but needs to be defined before sourcing
# associative array: spec to add -> view names seperated by spaces
declare -A spack_add_to_view
# associative array: spec to add -> "yes" for when dependencies should be added
#                                   "no" otherwise
declare -A spack_add_to_view_with_dependencies

if test -f "${ROOT_DIR}/share/yashchiki/styles/${CONTAINER_STYLE}/spack_collection.sh"; then
    # outside of container
    source "${ROOT_DIR}/share/yashchiki/styles/${CONTAINER_STYLE}/spack_collection.sh"
else
    # inside of container
    source "${SOURCE_DIR}/spack_collection.sh"
fi

# Control verbosity etc of commands
SPACK_ARGS_INSTALL=()
SPACK_ARGS_REINDEX=()
SPACK_ARGS_VIEW=()

if [ -n "${YASHCHIKI_SPACK_VERBOSE:-}" ]; then
    SPACK_ARGS_INSTALL+=("--verbose")
    SPACK_ARGS_VIEW+=("--verbose")
    SPACK_ARGS_REINDEX+=("--verbose")
fi

# Dependencies needed by yashchiki
yashchiki_dependencies=(
    "environment-modules~X"  # needed for module generation
)

#########
# VIEWS #
#########

# Views are put under /opt/spack_views/visionary-xy
# The app names are then just xy for smaller terminal lines.

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
    local opts OPTIND OPTARG
    num_jobs="${YASHCHIKI_JOBS}"
    while getopts ":j:" opts
    do
        case $opt in
            j) num_jobs="${OPTARG}" ;;
            *) echo -e "Invalid option to parallel_cmds(): $OPTARG\n" >&2; exit 1 ;;
        esac
    done
    shift $(( OPTIND - 1 ))

    grep -v "^\(#\|[[:space:]]*$\)" "${@}" | parallel -r -j "${num_jobs}"
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
                echo "${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[*]+"${SPACK_ARGS_VIEW[*]}"} view -d ${dependencies} symlink -i \"${MY_SPACK_VIEW_PREFIX}/${viewname}\" \"${addition}\""
            done
        } | parallel_cmds
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
            | xargs -r -0 -n 1 basename \
            | sed -e "s:\.tar\.gz$::g" \
	    | sort >"${resultsfile}") || /bin/true
    fi
    echo "DEBUG: Found $(wc -l <"${resultsfile}") hashes in buildcache: ${buildcache_dir}" >&2
    cat "${resultsfile}"
    rm "${resultsfile}"
}


get_hashes_in_spack() {
    # we only return hashes that are actually IN spack, i.e., that reside under /opt/spack/opt/spack
    ${MY_SPACK_CMD} find --no-groups -Lp | awk '$3 ~ /^\/opt\/spack\/opt\/spack\// { print $1 }' | sort
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
            echo "${MY_SPACK_CMD} spec -y \"${package}\" > ${specfiles[${idx}]}"
        fi
        idx=$((idx + 1))
    done
    ) | parallel -r -j${YASHCHIKI_JOBS} 1>/dev/null

    # TODO: DELME
    for sf in "${specfiles[@]}"; do
        if grep broadwell "${sf}" >/dev/null; then
            {
                echo "Error: Found target broadwell in specfile. This is incompatible with our AMTHost machines, aborting:"
                head -n 10 "${sf}"
            } >&2
            exit 1
        fi
    done

    for f in "${specfiles[@]}"; do
        echo "${f}"
    done
}

# Usage: install_from_buildcache PACKAGE...
#
# Install the given set of packages from yashchiki's buildcache.
install_from_buildcache() {
    local install_failed=0
    (
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

    # get all top-level directories that have to be created so that each tar process only creates its own directory
    local toplevel_dirs
    mapfile -t toplevel_dirs < <(parallel -j "${YASHCHIKI_JOBS}" \
        "bash -c 'tar Ptf ${BUILD_CACHE_INSIDE}/{}.tar.gz | head -n 1'" < "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}" \
        | xargs -r dirname | sort | uniq )

    # ensure all toplevel directories exist
    for dir in "${toplevel_dirs[@]+"${toplevel_dirs[@]}"}"; do
        [ ! -d "${dir}" ] && mkdir -p "${dir}"
    done

    parallel -v -j ${YASHCHIKI_JOBS} tar Pxf "${BUILD_CACHE_INSIDE}/{}.tar.gz" \
        < "${FILE_HASHES_TO_INSTALL_FROM_BUILDCACHE}"

    # have spack reindex its install contents to find the new packages
    ${MY_SPACK_CMD} "${SPACK_ARGS_REINDEX[@]+"${SPACK_ARGS_REINDEX[@]}"}" reindex
}

#############
# UTILITIES #
#############

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
  idx = match(\$2, /(\\+|~|$)/);
  printf("%s%%%s%s /%s\\n", substr(\$2, 0, idx-1), compiler, substr(\$2, idx), \$1)
}
EOF
  ${MY_SPACK_CMD} find -vL "$@" | awk -f "${FILE_AWK}"| sort -V | cut -d ' ' -f 2 | tail -n 1
  rm "${FILE_AWK}"
}
