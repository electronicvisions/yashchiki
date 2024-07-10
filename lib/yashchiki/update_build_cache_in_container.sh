#!/bin/bash
#
# General plan of action:
#
# Create a hard-linked copy, update that copy and only copy new additions back.
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
num_jobs=1

while getopts ":b:d:qj:" opts; do
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
        j)
            num_jobs="${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/get_hashes_in_buildcache.sh"

if [ -z "${base_buildcache}" ]; then
    base_buildcache="${BUILD_CACHE_INSIDE}"
fi

if (( destination_folder_specified == 0 )); then
    destination_folder=${base_buildcache}
fi


source /opt/spack/share/spack/setup-env.sh
export SPACK_SHELL="bash"

get_hashes_in_spack() {
    # we only return hashes that are actually IN spack, i.e., that reside under /opt/spack/opt/spack
    spack find --no-groups -Lp | awk '$3 ~ /^\/opt\/spack\/opt\/spack\// { print $1 }' | sort
}


# we store all hashes currently installed that are not already in the buildcache
get_hashes_to_store() {
    comm -13 <(get_hashes_in_buildcache "${base_buildcache}") <(get_hashes_in_spack)
}

args_progress="--eta"
if (( quiet == 1 )); then
    args_progress=""
fi

# find requires current working directory to be readable by spack user
cd ${destination_folder}

# Create tmpdir in destination folder to compress into,
# atomically move compressed files into the destination folder afterwards
tmpdir_in_destination_folder="$(mktemp -d --tmpdir=${destination_folder})"

rm_tmpdir() {
    rm -r $tmpdir_in_destination_folder
}
trap rm_tmpdir EXIT

get_hashes_to_store \
    | parallel -r ${args_progress} -j${num_jobs} \
        tar Pcfz "${tmpdir_in_destination_folder}/{}.tar.gz" \"\$\(spack location -i /{}\)\"

# verify integrity (of actual files, not possible symlinks)
find "${tmpdir_in_destination_folder}" -type f -name "*.tar.gz" -print0 \
    | parallel -r -0 -j${num_jobs} "tar Ptf '{}' 1>/dev/null"

# atomically move files into destination folder
find "${tmpdir_in_destination_folder}" -type f -name "*.tar.gz" -print0 \
    | parallel -r -0 -j${num_jobs} "mv '{}' ${destination_folder} 1>/dev/null"
