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
Extract and dump all information from a container that is needed to re-create it.

Usage:
    ${__script_name} -c <container> -d <destination>

Options:
    -h                Display this message.
    -c <container>    Path to container which to dump.
    -d <destination>  File into which to dump the dna (i.e., extracted
                      information).
                      If filename does not end with .tar.gz it will be appended.

    -v                Display script version.
EOF
}

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------

while getopts ":hvb:c:d:" opt
do
  case $opt in

    h )  usage; exit 0   ;;

    v )  echo "${__script_name} ${__script_version}"; exit 0   ;;

    c )  container="${OPTARG}" ;;

    d )  destination="${OPTARG}" ;;

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
else
    destination="${destination%\.tar\.gz}.tar.gz"
fi

container_name="$(basename "$(readlink -m "${container}")")"
container_name="${container_name%%.*}"

tmpdir="$(mktemp -d)"
dump_target_outside="${tmpdir}/dumptarget/${container_name}"
mkdir -p "${dump_target_outside}"

rm_tmpdir()
{
    rm -rf "${tmpdir}"
}

trap rm_tmpdir EXIT

run_in_container()
{
    local args
    # prefix args
    args=(
        "singularity"
        "exec"
        "-B" "${dump_target_outside}:/opt/dumptarget"
    )
    # suffix args
    args+=("${container}")

    # add command
    args+=("${@}")
    (
    ${args[*]}
    )
}

echo "Dumping spack git log.." >&2
run_in_container "cp /opt/meta/spack_git.log /opt/dumptarget/spack_git.log"
echo "Dumping yashchiki git log.." >&2
run_in_container "cp /opt/meta/yashchiki_git.log /opt/dumptarget/yashchiki_git.log"
echo "Dumping spack spec files.." >&2
run_in_container "cp -a /opt/spack_specs /opt/dumptarget"

echo "Compressing.." >&2
cd "${dump_target_outside}/.."
tar cfz "${destination}" "${container_name}" >/dev/null || ( echo "Compression failed!" >&2; exit 1  )
echo "Done" >&2
