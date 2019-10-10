#!/bin/bash -x

SOURCE_DIR="$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")"
source "${SOURCE_DIR}/commons.sh"

GITLOG="git_log_yashchiki.txt"
( cd ${SOURCE_DIR} && git log > "${WORKSPACE}/${GITLOG}" )

RECIPE_FILENAME="${WORKSPACE}/visionary_recipe.def"

# create container description file
# * based on Debian stretch (minimal) + a few extra packages (e.g. git, python, ...)
# * bind mount spack's fetch-cache and ccache into the container -> speed up stuff
# * bind mount spack's buildcache into the container -> speed up stuff
# * copy spack installation script into container
# * create "spack" user in the container and run spack installation script as spack user
#   (-> installs to /opt/spack, and creates views)
# * provide "apps" which set environment variables to appropriate views
cat <<EOF >"${RECIPE_FILENAME}"
Bootstrap: debootstrap
MirrorURL: http://httpredir.debian.org/debian
OSVersion: stretch
Include: ca-certificates, ccache, curl, file, g++, gawk, gcc, git-core, lbzip2, less, libc6-dev, locales, make, netbase, parallel, patch, patchelf, procps, python, python-yaml, rsync, ssh, sudo, udev, unzip, xz-utils

%setup
    # bind-mount spack-folder as moving involves copying the complete download cache
    mkdir \${SINGULARITY_ROOTFS}/opt/spack
    mount --no-mtab --bind "${WORKSPACE}/spack" "\${SINGULARITY_ROOTFS}/opt/spack"
    # bind-mount ccache
    mkdir \${SINGULARITY_ROOTFS}/opt/ccache
    mount --no-mtab --bind "${HOME}/spack_ccache" "\${SINGULARITY_ROOTFS}/opt/ccache"
    # bind-mount build_cache
    mkdir "\${SINGULARITY_ROOTFS}${BUILD_CACHE_INSIDE}"
    mount --no-mtab --bind "${BUILD_CACHE_OUTSIDE}" "\${SINGULARITY_ROOTFS}${BUILD_CACHE_INSIDE}"
    # bind-mount preserved packages in case the build fails
    mkdir "\${SINGULARITY_ROOTFS}${PRESERVED_PACKAGES_INSIDE}"
    mount --no-mtab --bind "${PRESERVED_PACKAGES_OUTSIDE}" "\${SINGULARITY_ROOTFS}${PRESERVED_PACKAGES_INSIDE}"
    # bind-mount tmp-folder
    mkdir -p "\${SINGULARITY_ROOTFS}/tmp/spack"
    mount --no-mtab --bind "${JOB_TMP_SPACK}" "\${SINGULARITY_ROOTFS}/tmp/spack"
    # copy install scripts
    mkdir "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${SOURCE_DIR}"/*.sh "\${SINGULARITY_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    # init scripts for user convenience
    mkdir -p "\${SINGULARITY_ROOTFS}/opt/init"
    rsync -av "${WORKSPACE}"/misc-files/init/*.sh "\${SINGULARITY_ROOTFS}/opt/init"

%files
    # NOTE: Due to a bug in singularity 2.6 all paths in this section _cannot_
    # be surrounded in quotes.. ergo there should be no spaces in filenames! If
    # there are, I pray for your poor soul that escaping them works..
    # --obreitwi, 17-02-19 # 23:45:51
    ${WORKSPACE}/${GITLOG} ${GITLOG}
    # provide spack command to login shells
    ${WORKSPACE}/misc-files/setup-spack.sh /etc/profile.d/setup-spack.sh
    ${WORKSPACE}/misc-files/locale.gen /etc/locale.gen
    ${WORKSPACE}/misc-files/locale.alias /etc/locale.alias
    ${WORKSPACE}/misc-files/sudoers /etc/sudoers
    ${JENKINS_ENV_FILE} ${JENKINS_ENV_FILE_INSIDE}

%post
    # cannot specify permissions in files-section
    chmod 440 /etc/sudoers
    chown root:root /etc/sudoers
    # install locales
    locale-gen
    # propagate environment variables to container recipe
    export DEPENDENCY_PYTHON="${DEPENDENCY_PYTHON}"
    export DEPENDENCY_PYTHON3="${DEPENDENCY_PYTHON3}"
    export VISIONARY_GCC="${VISIONARY_GCC}"
    export VISIONARY_GCC_VERSION="${VISIONARY_GCC_VERSION}"
    # Improve efficiency by installing system packages in the background (even
    # though we set the number of worker to \$(nproc), often times - e.g. when
    # concretizing - only one process will be active.)
    # NOTE: For this to work all spack-related dependencies need to be
    # specified under "Inlucde:" above. install_system_dependencies.sh should
    # only install packages that are needed once the container finished
    # building!
    # We kill the main process in case of errors in order to have no silent
    # fails!
    PID_MAIN="\$\$"
    ( "${SPACK_INSTALL_SCRIPTS}/install_system_dependencies.sh" \
        || kill \${PID_MAIN} ) &
    "${SPACK_INSTALL_SCRIPTS}/complete_spack_install_routine_called_in_post_as_root.sh"
    # system dependencies might not have installed by now
    # currently, singularity needs some dependendencies from apt as well, so
    # wait till we are finished with system dependencies
    wait
    "${SPACK_INSTALL_SCRIPTS}/install_singularity_as_root.sh" || \
    (
    sudo -Eu spack "${SPACK_INSTALL_SCRIPTS}/preserve_built_spack_packages.sh" &&
        exit 1  # propagate the error
    )
EOF

# create appenvs for all views...
# append apps for each spackview...
generate_appenv() {
local name_app="$1"
local name_view="$2"
cat <<EOF
%appenv ${name_app}
    # there can only be one app loaded at any time
    export VISIONARY_ENV=${name_view}
    SVF=/opt/spack_views/\${VISIONARY_ENV}
    export PATH=\${SVF}/bin\${PATH:+:}\${PATH}
    export PYTHONHOME=\${SVF}
    export MANPATH=\${SVF}/man:\${SVF}/share/man\${MANPATH:+:}\${MANPATH}
    export LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LIBRARY_PATH:+:}\${LIBRARY_PATH}
    export LD_LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LD_LIBRARY_PATH:+:}\${LD_LIBRARY_PATH}
    export TCLLIBPATH=\${SVF}/lib\${TCLLIBPATH:+:}\${TCLLIBPATH}
    export CPATH=\${SVF}/include\${CPATH:+:}\${CPATH}
    export C_INCLUDE_PATH=\${SVF}/include\${C_INCLUDE_PATH:+:}\${C_INCLUDE_PATH}
    export CPLUS_INCLUDE_PATH=\${SVF}/include\${CPLUS_INCLUDE_PATH:+:}\${CPLUS_INCLUDE_PATH}
    export PKG_CONFIG_PATH=\${SVF}/lib/pkgconfig:\${SVF}/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:}\${PKG_CONFIG_PATH}
    export CMAKE_PREFIX_PATH=\${SVF}\${CMAKE_PREFIX_PATH:+:}\${CMAKE_PREFIX_PATH}
EOF
}
for view in "${spack_views[@]}"; do
    # generate two apps, one with visionary- prefix for compatability with old
    # scripts and one with stripped visionary- prefix
    (
        generate_appenv "${view}" "${view}"
        [[ "${view}" =~ ^visionary- ]] && generate_appenv "${view#visionary-}" "${view}"
    ) >> "${RECIPE_FILENAME}"

    if [ "${view}" = "visionary-simulation" ];then
cat <<EOF >>"${RECIPE_FILENAME}"
    export NEST_MODULES=visionarymodule
EOF
    fi
done
