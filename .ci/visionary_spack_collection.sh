# All spack packages that should be fetched/installed in the container
spack_packages=(
    "${SPEC_VIEW_VISIONARY_DEV_TOOLS}"
    # START python 3 packages
    "visionary-wafer~dev ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer~dev+gccxml ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer+gccxml ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer-visu ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-clusterservices ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-dls~dev ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "visionary-dls ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "py-jupyterhub ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "py-jupyterhub-dummyauthenticator ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    "py-jupyterhub-simplespawner ^${DEPENDENCY_PYTHON3} %${YASHCHIKI_SPACK_GCC}"
    # END python 3 packages
)

spack_views=(\
    visionary-dev-tools
    visionary-dls-core
    visionary-dls
    visionary-dls-nodev
    visionary-slurmviz
    visionary-wafer
    visionary-wafer-nodev
)

spack_views_no_default_gcc=(
    "visionary-nux" # currenlty visionary-nux is no view, but serves as example
)

spack_views_gccxml=(
    "visionary-wafer"
    "visionary-wafer-nodev"
)



spack_gid="nogroup"

spack_create_user_cmd() {
    adduser spack --uid 888 --no-create-home --home /opt/spack --disabled-password --system --shell /bin/bash
}

# all views get the default gcc except those in spack_views_no_default_gcc
# (defined above)
spack_add_to_view_with_dependencies["${YASHCHIKI_SPACK_GCC}"]="no"
spack_add_to_view["${YASHCHIKI_SPACK_GCC}"]="$(
    for viewname in "${spack_views[@]+"${spack_views[@]}"}"; do
        # check if the current view matches any view that does not get the
        # default gcc
        # Note: Currently this allow partial matches
        if printf "%s\n" "${spack_views_no_default_gcc[@]+"${spack_views_no_default_gcc[@]}"}" \
                | grep -qF "${viewname}"; then
            continue
        fi
        echo ${viewname}
    done | tr '\n' ' '
)"

## Add gccxml to those views that still depend on it
spack_add_to_view_gccxml="$(
    for viewname in "${spack_views[@]+"${spack_views[@]}"}"; do
        # check if the current view matches any view that gets gccxml
        # Note: Currently this allow partial matches
        if printf "%s\n" "${spack_views_gccxml[@]+"${spack_views_gccxml[@]}"}" \
                | grep -qF "${viewname}"; then
            echo ${viewname}
        fi
    done | tr '\n' ' '
)"
if [[ "$spack_add_to_view_gccxml" != "" ]]; then
    spack_add_to_view_with_dependencies["gccxml"]="no"
    spack_add_to_view["gccxml"]="$spack_add_to_view_gccxml"
fi
