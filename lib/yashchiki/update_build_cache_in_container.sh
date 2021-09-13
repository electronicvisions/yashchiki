#!/bin/bash
#
# General plan of action:
#
# Create a hard-linked copy, update that copy and only copy new additions back.
# This ensure minimum locking time.
#

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

usage() { cat  1>&2 <<EOF
Usage: ${0} [-c <base-cache>] [-d <destination-folder>]

Options:
  -b <base-cache>           Base cache containing packages that should not be
                            dumped to destination.
                            Defaults to \$BUILD_CACHE_INSIDE.

  -d <destination-folder>   Folder into which the packages will be put.
                            Defaults to <base-cache>.

  -q                        Be almost quiet about it, i.e., show no progress.
EOF
exit 1;
}

base_buildcache=""
destination_folder=""

destination_folder_specified=0
quiet=0

while getopts ":b:d:q" opts; do
    case "${opts}" in
        b)
            base_buildcache="${OPTARG}"
            ;;
        d)
            destination_folder="${OPTARG}"
            destination_folder_specified=1
            ;;
        q)
            quiet=1
            ;;
        *)
            usage
            ;;
    esac
done

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

if [ -z "${base_buildcache}" ]; then
    base_buildcache="${BUILD_CACHE_INSIDE}"
fi

if (( destination_folder_specified == 0 )); then
    destination_folder=${base_buildcache}
fi


source /opt/spack/share/spack/setup-env.sh
export SPACK_SHELL="bash"

# we store all hashes currently installed that are not already in the buildcache
get_hashes_to_store() {
    comm -13 <(get_hashes_in_buildcache "${base_buildcache}") <(get_hashes_in_spack)
}

if [ "${destination_folder}" = "${base_buildcache}" ]; then
    # if the destination folder is the same as the base buildcache, we need to
    # lock exclusively since we put things into the buildcache
    lock_file -e "${base_buildcache}/${LOCK_FILENAME}"
else
    lock_file "${base_buildcache}/${LOCK_FILENAME}"
fi

args_progress="--eta"
if (( quiet == 1 )); then
    args_progress=""
fi

# find requires current working directory to be readable by spack user
cd ${MY_SPACK_FOLDER}

get_hashes_to_store \
    | parallel -r ${args_progress} -j$(nproc) \
        tar Pcfz "${destination_folder}/{}.tar.gz" \"\$\(spack location -i /{}\)\"

# verify integrity (of actual files, not possible symlinks)
find "${destination_folder}" -type f -name "*.tar.gz" -print0 \
    | parallel -r -0 -j$(nproc) "tar Ptf '{}' 1>/dev/null"
