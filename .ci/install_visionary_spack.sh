#!/bin/bash -x
# Install visionary spack packages (this should only be done after the compiler
# has been installed).

set -euo pipefail

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

cd "$HOME"

# tensorflow fails
install_from_buildcache "${spack_packages[@]}"

echo "INSTALLING PACKAGES"
for package in "${spack_packages[@]}"; do
    # Disable cache because we already installed from build cache.
    # Also there is a bug that when `--no-cache` is not specified, install will
    # fail because spack checks for signed buildcache packages only.
    # PR pending: https://github.com/spack/spack/pull/11107
    ${MY_SPACK_BIN} install --no-cache --show-log-on-error ${package}
done

# create the filesystem views (exposed via singularity --app option)
echo "CREATING VIEWS OF META PACKAGES"
cd ${MY_SPACK_FOLDER}

# make views writable for non-spack users in container
OLD_UMASK=$(umask)
umask 000

# Perform custom view settings

####################################
# Packages still plagued by gccxml #
####################################

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-defaults visionary-defaults+tensorflow~gccxml

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls visionary-dls+dev~gccxml
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-without-dev visionary-dls~dev~gccxml

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-demos visionary-dls-demos

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey visionary-spikey+dev
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-spikey-without-dev visionary-spikey~dev

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer visionary-wafer+dev+tensorflow~gccxml
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-without-dev visionary-wafer~dev+tensorflow~gccxml

##################################################
# Strong independent packages who need no gccxml #
##################################################

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis visionary-analysis+dev
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-analysis-without-dev visionary-analysis~dev

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation "visionary-simulation+dev %${VISIONARY_GCC}"
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation-without-dev "visionary-simulation~dev %${VISIONARY_GCC}"

# slurvmiz needs no dev-tools because it is not for end-users
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-slurmviz "visionary-slurmviz %${VISIONARY_GCC}"

################################################
# nn-conv needs a different tensorflow version #
################################################

${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-nn-conv visionary-wafer+dev~tensorflow~gccxml
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-nn-conv tensorflow@1.8.0

# Ensure that only one version of visionary-dev-tools is installed as ${SPACK_VIEW_ARGS} view even
# if several are installed due to different constraints in other packages
hash_visionary_dev_tools="$(${MY_SPACK_BIN} spec -L ${SPEC_VIEW_VISIONARY_DEV_TOOLS} | awk ' $2 ~ /^visionary-dev-tools/ { print $1 }')"
${MY_SPACK_BIN} ${SPACK_VIEW_ARGS} view -d yes hardlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dev-tools "/${hash_visionary_dev_tools}"

# Perform the remaining additions to the views defined in commons.
populate_views

umask ${OLD_UMASK}

# Have convience symlinks for shells for user sessions so that they can be
# executed via:
# $ singularity shell -s /opt/shell/${SHELL} /containers/stable/latest
# which is independent of any app. Especially, this allows custom loading of
# modules within the container.
ln -s "$(${MY_SPACK_BIN} location -i zsh)/bin/zsh" /opt/shell/zsh
