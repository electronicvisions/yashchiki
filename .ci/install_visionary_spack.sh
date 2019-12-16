#!/bin/bash -x
# Install visionary spack packages (this should only be done after the compiler
# has been installed).

set -euo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

cd "$HOME"

install_from_buildcache "${spack_packages[@]}"

echo "INSTALLING PACKAGES"
for package in "${spack_packages[@]}"; do
    # Disable cache because we already installed from build cache.
    # Also there is a bug that when `--no-cache` is not specified, install will
    # fail because spack checks for signed buildcache packages only.
    # PR pending: https://github.com/spack/spack/pull/11107
    specfile="$(get_specfiles "${package}")"
    if (( $(wc -l <"${specfile}") == 0 )); then
        echo "ERROR: Failed to concretize ${package} for install." >&2
        exit 1
    fi
    echo "Installing: ${package}" >&2
    ${MY_SPACK_BIN} --verbose install --no-cache --show-log-on-error --file "${specfile}"
done

# create the filesystem views (exposed via singularity --app option)
echo "CREATING VIEWS OF META PACKAGES"
cd ${MY_SPACK_FOLDER}

# make views writable for non-spack users in container
OLD_UMASK=$(umask)
umask 000

################################
# Perform custom view settings #
################################

# NOTE: Please note that these lines cannot share state because each is
# executed essentially in parallel in its own subshell.
#
# For reproducibility reasons, each view should only appear once per call to
# parallel_cmds! Due to the fact that we simply ignore file duplicates if
# several spack packages get linked into the same view and the random order of
# execution in a parallel context, builds might become unstable otherwise.
{
cat <<EOF
####################################
# Packages still plagued by gccxml #
####################################

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls $(get_latest_hash visionary-dls+dev~gccxml "^${DEPENDENCY_PYTHON3}")
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev $(get_latest_hash visionary-dls~dev~gccxml "^${DEPENDENCY_PYTHON3}")

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey $(get_latest_hash visionary-spikey+dev)
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey-without-dev $(get_latest_hash visionary-spikey~dev)

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer $(get_latest_hash visionary-wafer+dev+tensorflow~gccxml)
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev $(get_latest_hash visionary-wafer~dev+tensorflow~gccxml)

##################################################
# Strong independent packages who need no gccxml #
##################################################

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation $(get_latest_hash "visionary-simulation+dev %${VISIONARY_GCC}")
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation-without-dev $(get_latest_hash "visionary-simulation~dev %${VISIONARY_GCC}")

# slurvmiz needs no dev-tools because it is not for end-users
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-slurmviz $(get_latest_hash "visionary-slurmviz %${VISIONARY_GCC}")

############
# exa-mode #
############

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-exa $(get_latest_hash "visionary-exa+dev %${VISIONARY_GCC}")
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-exa-without-dev $(get_latest_hash "visionary-exa~dev %${VISIONARY_GCC}")

#############
# dev tools #
#############

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dev-tools $(get_latest_hash "${SPEC_VIEW_VISIONARY_DEV_TOOLS}")
EOF
} | parallel_cmds

# Perform the remaining additions to the views defined in commons.
populate_views

umask ${OLD_UMASK}

# Have convience symlinks for shells for user sessions so that they can be
# executed via:
# $ singularity shell -s /opt/shell/${SHELL} /containers/stable/latest
# which is independent of any app. Especially, this allows custom loading of
# modules within the container.
ln -s "$(${MY_SPACK_BIN} location -i zsh)/bin/zsh" /opt/shell/zsh

# remove temporary cache folder
rm -rfv /opt/spack/.spack
