#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# hard-link source cache into spack folder to avoid duplication.
mkdir -p "${YASHCHIKI_SPACK_PATH}/var/spack/cache/"
find "${SOURCE_CACHE_DIR}" -mindepth 1 -maxdepth 1 -print0 \
    | xargs -r -n 1 "-I{}" -0 cp -vrl '{}' "${YASHCHIKI_SPACK_PATH}/var/spack/cache/"

# temporary spack config scope directory for fetching
tmp_config_scope=("$(mktemp -d)")

# set download mirror stuff to prefill outside of container
export MY_SPACK_FOLDER="${YASHCHIKI_SPACK_PATH}"
# here we need the spack path outside of the container, but in commons.sh
# the inside-container location is defined
export MY_SPACK_BIN="${MY_SPACK_FOLDER}/bin/spack"
# therefore we also need to redefine this command variable
export MY_SPACK_CMD="${MY_SPACK_BIN} --config-scope ${YASHCHIKI_SPACK_CONFIG} --config-scope ${tmp_config_scope}"

# Add fake system compiler (needed for fetching)
# We create a compilers.yaml file in a temporary directory and
# add it as a scope.
# This is NOT the correct version but we need to concretize with the same
# version as we intend to build.
# TODO: Spack needs to support concretizing with non-existent compiler.
cat >"${tmp_config_scope}/compilers.yaml" <<EOF
compilers:
- compiler:
    paths:
      cc: /usr/bin/gcc
      cxx: /usr/bin/g++
      f77: /usr/bin/gfortran
      fc: /usr/bin/gfortran
    operating_system: $(${MY_SPACK_CMD} arch -o)
    target: x86_64
    modules: []
    environment: {}
    extra_rpaths: []
    flags: {}
    spec: ${YASHCHIKI_SPACK_GCC}
EOF

# fetch "everything" (except for pip shitness)
echo "FETCHING..."

# concretize all spack packages in parallel
packages_to_fetch=(
    "${YASHCHIKI_SPACK_GCC}"
    "${spack_bootstrap_dependencies[@]}"
    "${spack_packages[@]}"
)
# verify that all concretizations were successful

# first entry is just a statefile to indicate fetching failed (as opposed to
# some warnings that are also printed to stderr during fetching)
tmpfiles_concretize_err=("$(mktemp)")

rm_tmp_files() {
    rm -v "${tmpfiles_concretize_err[@]}"
    rm -r $tmp_config_scope
}
trap rm_tmp_files EXIT


# Concretize a trivial spec to regenerate
# SPACK_ROOT/.spack/cache/{patches,providers,tags}/builtin-index.json
# This should prevent lockfile timeout issues as parallel spack calls can rely
# on the pregenerated index..
# Unfortunately, right now reindexing spack does not cause the index file to be
# generated.
echo "Regenerating database index." >&2
${MY_SPACK_CMD} spec aida >/dev/null

# for some reason the exit code of shopt indicates if option is set despite -q not being specified
oldstate="$(shopt -po xtrace)" || true

for package in "${packages_to_fetch[@]}"; do
    echo "Concretizing ${package:0:30} for fetching.." >&2
    # pause if we have sufficient concretizing jobs
    set +x  # do not clobber build log so much
    while (( $(jobs | wc -l) >= ${YASHCHIKI_JOBS} )); do
        # call jobs because otherwise we will not exit the loop
        jobs &>/dev/null
        sleep 1
    done
    eval "${oldstate}"
    tmp_err="$(mktemp)"
    tmpfiles_concretize_err+=("${tmp_err}")
    # We need to strip the compiler spec starting with '%' from the spec string
    # because the compiler is not yet known.
    # Note that this will also delete target information right now!
    package_wo_compiler="${package%%%*}"
    ( set -x;
        ( specfile=$(get_specfile_name "${package_wo_compiler}");
        (${MY_SPACK_CMD} spec --fresh -y "${package_wo_compiler}" > "${specfile}")
        ) 2>"${tmp_err}" \
        || ( echo "CONCRETIZING FAILED" >> "${tmpfiles_concretize_err[0]}" );
    ) &
done
# wait for all spawned jobs to complete
wait

# verify that all concretizations were successful
if (( $(cat "${tmpfiles_concretize_err[@]}" | wc -l) > 0 )); then
    {
        if (( $(wc -l <"${tmpfiles_concretize_err[0]}") > 0)); then
            echo -n "ERROR: "
        else
            echo -n "WARN: "
        fi
        echo "Encountered the following during concretizations prior to fetching:"
        cat "${tmpfiles_concretize_err[@]}"
    } | tee errors_concretization.log
    if (( $(wc -l <"${tmpfiles_concretize_err[0]}") > 0)); then
        exit 1
    fi
fi

# --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< ---
####################
# WORKAROUND START #
####################
# Switch to http for ftpmirror.gnu.org

# The https-version of ftpmirror.gnu.org sometimes redirects to old
# servers that have no secure (according to curl) SSL versions available,
# leading to the following error:

# ```
# curl: (35) error:1425F102:SSL routines:ssl_choose_client_version:unsupported protocol
# ```

# Since we are downloading public software and can verify its contents via
# hashes, there is no benefit of using https -> fall back to http.

find "${MY_SPACK_FOLDER}/var/spack/repos" -type f -print0 \
    | xargs -0 sed -i "s|https://ftpmirror.gnu.org|http://ftpmirror.gnu.org|g"
##################
# WORKAROUND END #
##################
# --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< --- 8< ---

# now fetch everything that is needed in order
fetch_specfiles=()
for package in "${packages_to_fetch[@]}"; do
    package_wo_compiler="${package%%%*}"
    specfile="$(get_specfile_name "${package_wo_compiler}")"
    if (( $(wc -l <"${specfile}") == 0 )); then
        echo "${package} failed to concretize!" >&2
        exit 1
    fi
    fetch_specfiles+=( "${specfile}" )
done
if ! ${MY_SPACK_CMD} fetch -D "${fetch_specfiles[@]/^/-f }"; then
    fetch_failed=1
else
    fetch_failed=0
fi

# update cache in any case to store successfully loaded files
rsync -av "${MY_SPACK_FOLDER}/var/spack/cache/" "${SOURCE_CACHE_DIR}/"

if (( fetch_failed != 0 )); then
    # propagate error
    exit 1
fi

echo
