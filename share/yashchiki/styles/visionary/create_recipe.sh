#!/bin/bash

ROOT_DIR="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")")")")")"
source "${ROOT_DIR}/lib/yashchiki/commons.sh"

# create container description file
# * based on Debian buster (minimal) + a few extra packages (e.g. git, python, ...)
# * bind mount spack's fetch-cache and ccache into the container -> speed up stuff
# * bind mount spack's buildcache into the container -> speed up stuff
# * copy spack installation script into container
# * create "spack" user in the container and run spack installation script as spack user
#   (-> installs to /opt/spack, and creates views)
# * provide "apps" which set environment variables to appropriate views
cat <<EOF >"${YASHCHIKI_RECIPE_PATH}"
Bootstrap: docker
From: ${DOCKER_BASE_IMAGE}

%setup
    # location to bind-mount spack-folder
    mkdir \${APPTAINER_ROOTFS}/opt/spack
    # location to bind-mount spack-source-cache-folder
    mkdir -p \${APPTAINER_ROOTFS}/opt/spack/var/spack/cache/
    # copy spack repo
    rsync -av ${YASHCHIKI_SPACK_PATH}/ \${APPTAINER_ROOTFS}/opt/spack
    # location to bind-mount ccache
    mkdir \${APPTAINER_ROOTFS}/opt/ccache
    # location to bind-mount build_cache
    mkdir -p "\${APPTAINER_ROOTFS}${BUILD_CACHE_INSIDE}"
    # # create buildcache directory if it does not exist
    [ ! -d "${BUILD_CACHE_OUTSIDE}" ] && mkdir -p "${BUILD_CACHE_OUTSIDE}"
    # location to mount the full build cache folder into container because some files might be symlinked to other buildcaches
    # mount --no-mtab --bind "${BASE_BUILD_CACHE_OUTSIDE}" "\${APPTAINER_ROOTFS}${BASE_BUILD_CACHE_INSIDE}"
    # location to bind-mount preserved packages in case the build fails
    mkdir -p "\${APPTAINER_ROOTFS}${PRESERVED_PACKAGES_INSIDE}"
    # location to bind-mount tmp-folder
    mkdir -p "\${APPTAINER_ROOTFS}/tmp/spack"
    # location to bind-mount spack config tmp-folder
    mkdir -p "\${APPTAINER_ROOTFS}/tmp/spack_config"
    # copy install scripts
    mkdir "\${APPTAINER_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av --chmod 0755 "${ROOT_DIR}"/share/yashchiki/styles/${CONTAINER_STYLE}/*.sh "\${APPTAINER_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av --chmod 0755 "${ROOT_DIR}"/lib/yashchiki/*.sh "\${APPTAINER_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${ROOT_DIR}"/lib/yashchiki/*.awk "\${APPTAINER_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    rsync -av "${ROOT_DIR}"/share/yashchiki/patches "\${APPTAINER_ROOTFS}/${SPACK_INSTALL_SCRIPTS}"
    mkdir -p "\${APPTAINER_ROOTFS}/${META_DIR_INSIDE}"
    rsync -av "${META_DIR_OUTSIDE}/" "\${APPTAINER_ROOTFS}/${META_DIR_INSIDE}"
    # init scripts for user convenience
    mkdir -p "\${APPTAINER_ROOTFS}/opt/init"
    rsync -av "${ROOT_DIR}"/share/yashchiki/misc-files/init/*.sh "\${APPTAINER_ROOTFS}/opt/init"

%files
    # NOTE: Due to a bug in singularity 2.6 all paths in this section _cannot_
    # be surrounded in quotes.. ergo there should be no spaces in filenames! If
    # there are, I pray for your poor soul that escaping them works..
    # --obreitwi, 17-02-19 # 23:45:51
    # provide spack command to login shells
    ${ROOT_DIR}/share/yashchiki/misc-files/setup-spack.sh /etc/profile.d/setup-spack.sh
    ${ROOT_DIR}/share/yashchiki/misc-files/locale.gen /etc/locale.gen
    ${ROOT_DIR}/share/yashchiki/misc-files/locale.alias /etc/locale.alias
    ${ROOT_DIR}/share/yashchiki/misc-files/sudoers /etc/sudoers

%post
    # create a fingerprint by which we can identify the container from within
    cat /proc/sys/kernel/random/uuid > /opt/fingerprint

    # prerequisites
    "${SPACK_INSTALL_SCRIPTS}/install_prerequisites.sh" || exit 1
    # cannot specify permissions in files-section
    chmod 440 /etc/sudoers
    chown root:root /etc/sudoers
    # install locales
    locale-gen
    # propagate environment variables to container recipe
    export YASHCHIKI_BUILD_SPACK_GCC="${YASHCHIKI_BUILD_SPACK_GCC}"
    export YASHCHIKI_SPACK_GCC="${YASHCHIKI_SPACK_GCC}"
    export YASHCHIKI_SPACK_GCC_VERSION="${YASHCHIKI_SPACK_GCC_VERSION}"
    export YASHCHIKI_JOBS="${YASHCHIKI_JOBS}"
    export YASHCHIKI_SPACK_CONFIG="/tmp/spack_config"
    export YASHCHIKI_CACHES_ROOT="${YASHCHIKI_CACHES_ROOT}"
    export YASHCHIKI_BUILD_CACHE_NAME="${YASHCHIKI_BUILD_CACHE_NAME}"
    export YASHCHIKI_BUILD_CACHE_ON_FAILURE_NAME="${YASHCHIKI_BUILD_CACHE_ON_FAILURE_NAME:-}"
    export YASHCHIKI_SPACK_VERBOSE="${YASHCHIKI_SPACK_VERBOSE}"
    export YASHCHIKI_DEBUG=${YASHCHIKI_DEBUG}
    export CONTAINER_STYLE="${CONTAINER_STYLE}"
    # Improve efficiency by installing system packages in the background (even
    # though we set the number of worker to \${YASHCHIKI_JOBS}, often times - e.g. when
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
    "${SPACK_INSTALL_SCRIPTS}/complete_spack_install_routine_called_in_post.sh"
    # system dependencies might not have installed by now
    # currently, singularity needs some dependendencies from apt as well, so
    # wait till we are finished with system dependencies
    wait
    "${SPACK_INSTALL_SCRIPTS}/install_singularity.sh" || \
    (
        "${SPACK_INSTALL_SCRIPTS}/preserve_built_spack_packages.sh" &&
        exit 1  # propagate the error
    )
    # apply some system-level patching (TODO: remove this as soon as gccxml dependency is gone)
    "${SPACK_INSTALL_SCRIPTS}/manual_system_level_patching_routine_called_in_post_as_root.sh"
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
    export SPACK_PYTHON_BINARY=\${SVF}/bin/python
    export MANPATH=\${SVF}/man:\${SVF}/share/man\${MANPATH:+:}\${MANPATH}
    export LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64\${LIBRARY_PATH:+:}\${LIBRARY_PATH}
    export LD_LIBRARY_PATH=\${SVF}/lib:\${SVF}/lib64:\${SVF}/targets/x86_64-linux/lib:\${LD_LIBRARY_PATH:+:}\${LD_LIBRARY_PATH}
    export TCLLIBPATH=\${SVF}/lib\${TCLLIBPATH:+:}\${TCLLIBPATH}
    export CPATH=\${SVF}/include\${CPATH:+:}\${CPATH}
    export C_INCLUDE_PATH=\${SVF}/include\${C_INCLUDE_PATH:+:}\${C_INCLUDE_PATH}
    export CPLUS_INCLUDE_PATH=\${SVF}/include\${CPLUS_INCLUDE_PATH:+:}\${CPLUS_INCLUDE_PATH}
    export QUIET_CPATH=\${CPATH}
    export QUIET_C_INCLUDE_PATH=\${C_INCLUDE_PATH}
    export QUIET_CPLUS_INCLUDE_PATH=\${CPLUS_INCLUDE_PATH}
    export PKG_CONFIG_PATH=\${SVF}/lib/pkgconfig:\${SVF}/lib64/pkgconfig:\${SVF}/share/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig\${PKG_CONFIG_PATH:+:}\${PKG_CONFIG_PATH}
    export CMAKE_PREFIX_PATH=\${SVF}\${CMAKE_PREFIX_PATH:+:}\${CMAKE_PREFIX_PATH}
EOF
}
for view in "${spack_views[@]}"; do
    # generate two apps, one with visionary- prefix for compatability with old
    # scripts and one with stripped visionary- prefix
    (
        generate_appenv "${view}" "${view}"
        [[ "${view}" =~ ^visionary- ]] && generate_appenv "${view#visionary-}" "${view}"
    ) >> "${YASHCHIKI_RECIPE_PATH}"
done
