#!/bin/bash
#
# This utility dumps all built spack packages of a container compressed into a
# folder.
#

__script_name="${0}"
__script_version="0.1.0"

set -euo pipefail

usage() {
cat >&2 <<EOF
Dump all built spack packages of a container compressed into a folder.

Usage:
    ${__script_name} -c <container> -d <target dir> [-b <build cache>]

Options:
    -h                Display this message.
    -b <build cache>  Path to build cache. Packages already present in the
                      buildcache will not be dumped.
    -c <container>    Path to container which to dump.
    -d <destination>  Directory into which to dump the packages.
    -j <num_jobs>     Number of parallel jobs to use
    -v                Display script version.
EOF
}

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------

num_jobs=1

while getopts ":hvb:c:d:j:" opt
do
  case $opt in

    h )  usage; exit 0   ;;

    v )  echo "${__script_name} ${__script_version}"; exit 0   ;;

    b )  buildcache="${OPTARG}" ;;

    c )  container="${OPTARG}" ;;

    d )  destination="${OPTARG}" ;;

    j )  num_jobs="${OPTARG}" ;;

    * )  echo -e "\n  Option does not exist : $OPTARG\n"
          usage; exit 1   ;;

  esac
done
shift $(( OPTIND - 1 ))


if [ -z "${container:-}" ]; then
    printf "Error: -c not specified!\n" >&2
    usage
    exit 1
fi

if [ -z "${destination:-}" ]; then
    printf "Error: -d not specified!\n" >&2
    usage
    exit 1
fi

if [ ! -d "${destination}" ]; then
    echo "INFO: ${destination} does not exist, creating.." >&2
    mkdir -p "${destination}"
fi

# prefix args
args=(
    "singularity"
    "exec"
    "-B" "${destination}:/opt/dumptarget"
)

if [ -n "${buildcache:-}" ]; then
    args+=( "-B" "${buildcache}:/opt/base_build_cache" )
fi

#suffix args
args+=(
    "${container}"
    "/opt/spack_install_scripts/update_build_cache_in_container.sh"
    "-d" "/opt/dumptarget"
    "-j" "${num_jobs}"
)

if [ -n "${buildcache:-}" ]; then
    args+=( "-b" "/opt/base_build_cache" )
fi

(
# Set variables that need to be defined but are irrelevant to buildcache
# dumping (TODO: keep in sync with lib/yashchiki/dummy_variables.sh!).
export BUILD_CACHE_NAME="${BUILD_CACHE_NAME:-undefined}"
export VISIONARY_GCC="${VISIONARY_GCC:-undefined}"
export WORKSPACE="${WORKSPACE:-undefined}"

echo ${args[*]}
${args[*]}
)
