#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

# temporary spack config scope directory for fetching
tmp_config_scope=("$(mktemp -d)")

# set download mirror stuff to prefill outside of container
export MY_SPACK_FOLDER="${YASHCHIKI_SPACK_PATH}"
# here we need the spack path outside of the container, but in commons.sh
# the inside-container location is defined
export MY_SPACK_BIN="${MY_SPACK_FOLDER}/bin/spack"
# therefore we also need to redefine this command variable
export MY_SPACK_CMD="${MY_SPACK_BIN} --config-scope ${YASHCHIKI_SPACK_CONFIG} --config-scope ${tmp_config_scope}"

cat >"${tmp_config_scope}/config.yaml" <<EOF
config:
  source_cache: ${YASHCHIKI_CACHES_ROOT}/download_cache
EOF

# fetch "everything" (except for pip shitness)
echo "FETCHING..."

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

# Fetch GCC while system compiler is still available
echo "CONCRETIZE GCC"
if [ ${YASHCHIKI_BUILD_SPACK_GCC} -eq 1 ]; then
    echo "Concretizing ${YASHCHIKI_SPACK_GCC} for fetching.." >&2
    set +x  # do not clobber build log so much
    eval "${oldstate}"
    tmp_err="$(mktemp)"
    tmpfiles_concretize_err+=("${tmp_err}")
    ( set -x;
        ( specfile=$(get_specfile_name "${YASHCHIKI_SPACK_GCC}");
        (${MY_SPACK_CMD} spec --fresh -y "${YASHCHIKI_SPACK_GCC}" > "${specfile}")
        ) 2>"${tmp_err}" \
        || ( echo "CONCRETIZING FAILED" >> "${tmpfiles_concretize_err[0]}" );
    )
fi

# Add fake system compiler (needed for fetching)
# We create a compilers.yaml file in a temporary directory and
# add it as a scope.
# This is NOT the correct version but we need to concretize with the same
# version as we intend to build.
# Furthermore, we overwrite the compiler settings which are set with lower
# precedence.
# TODO: Spack needs to support concretizing with non-existent compiler.
cat >"${tmp_config_scope}/compilers.yaml" <<EOF
compilers::  # two colons to overwrite lower-precedence settings, i.e. system compiler.
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


echo "CONCRETIZE PACKAGES IN PARALLEL"
packages_to_spec=(
    "${yashchiki_dependencies[@]}"
    "${spack_packages[@]}"
)
for package in "${packages_to_spec[@]}"; do
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
    ( set -x;
        ( specfile=$(get_specfile_name "${package}");
        (${MY_SPACK_CMD} spec --fresh -y "${package}" > "${specfile}")
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
packages_to_fetch=(
    "${yashchiki_dependencies[@]}"
    "${spack_packages[@]}"
)

if [ ${YASHCHIKI_BUILD_SPACK_GCC} -eq 1 ]; then
	packages_to_fetch=(
		"${YASHCHIKI_SPACK_GCC}"
		"${packages_to_fetch[@]}"
	)
fi

# first check if concretization worked for all packages
for package in "${packages_to_fetch[@]}"; do
    specfile="$(get_specfile_name "${package}")"
	echo "Specfile for ${package} is ${specfile}."
	word_count=$(wc -l <"${specfile}")
    echo "Word count ${word_count}"
    if (( $(wc -l <"${specfile}") == 0 )); then
        echo "${package} failed to concretize!" >&2
        exit 1
    fi
done
# then fetch one package after another
for package in "${packages_to_fetch[@]}"; do
    specfile="$(get_specfile_name "${package}")"
	echo "Fetch ${package} (file: ${specfile})."
	if ! ${MY_SPACK_CMD} fetch -D "${specfile}"; then
		echo "ERROR: Fetching ${package} failed."
		# propagate error
		exit 1
	fi
done
