# All spack packages that should be fetched/installed in the container
spack_packages=(
#    "visionary-dev-tools %${YASHCHIKI_SPACK_GCC}" # FIXME
    "visionary-asic %${YASHCHIKI_SPACK_GCC}"
)

spack_views=(\
    visionary-asic
)

spack_views_no_default_gcc=(\
    visionary-asic # ECM: system compiler for now
)
