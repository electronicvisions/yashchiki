# All spack packages that should be fetched/installed in the container
spack_packages=(
    "f27-ido %${YASHCHIKI_SPACK_GCC}"
    "f27-niklas %${YASHCHIKI_SPACK_GCC}"
)

spack_views=(\
    ido
    niklas
)

spack_views_no_default_gcc=(
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
