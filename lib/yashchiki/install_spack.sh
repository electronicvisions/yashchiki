#!/bin/bash
# Install visionary spack packages (this should only be done after the compiler
# has been installed).

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

sourcedir="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${sourcedir}/commons.sh"
source "${sourcedir}/setup_env_spack.sh"

cd "$HOME"

install_from_buildcache "${spack_packages[@]+"${spack_packages[@]}"}"

echo "INSTALLING PACKAGES"
for package in "${spack_packages[@]+"${spack_packages[@]}"}"; do
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
    ${MY_SPACK_CMD} "${SPACK_ARGS_INSTALL[@]+"${SPACK_ARGS_INSTALL[@]}"}" install --fresh --no-cache --show-log-on-error --file "${specfile}"
done

# create the filesystem views (exposed via singularity --app option)
echo "CREATING VIEWS OF META PACKAGES" >&2
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
source ${SPACK_INSTALL_SCRIPTS}/spack_custom_view.sh
} | parallel_cmds

# Perform the remaining additions to the views defined in commons.
populate_views

# Hide python3 in ancient (python2-based) views:
# The host system might provide a python3 binary which spack will prefer over
# the view-provided python2 binary. Since we set PYTHONHOME this leads to
# incompatible python libraries search paths.
if compgen -G "${MY_SPACK_VIEW_PREFIX}/visionary-*/bin/python2" > /dev/null; then
    for pyf in ${MY_SPACK_VIEW_PREFIX}/visionary-*/bin/python2; do
        ln -fs ${pyf} "$(dirname ${pyf})/python3"
    done
fi

umask ${OLD_UMASK}

# Have convience symlinks for shells for user sessions so that they can be
# executed via:
# $ singularity shell -s /opt/shell/${SHELL} /containers/stable/latest
# which is independent of any app. Especially, this allows custom loading of
# modules within the container.
if ${MY_SPACK_CMD} location -i zsh; then
    ln -s "$(${MY_SPACK_CMD} location -i zsh)/bin/zsh" /opt/shell/zsh
fi
