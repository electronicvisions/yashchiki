# All spack packages that should be fetched/installed in the container
spack_packages=(
    "visionary-dev-tools %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer~dev %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer+dev %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer~dev+gccxml %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer+dev+gccxml %${YASHCHIKI_SPACK_GCC}"
    "visionary-wafer-visu %${YASHCHIKI_SPACK_GCC}"
    "visionary-clusterservices %${YASHCHIKI_SPACK_GCC}"
    "visionary-dls~dev %${YASHCHIKI_SPACK_GCC}"
    "visionary-dls+dev %${YASHCHIKI_SPACK_GCC}"
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
