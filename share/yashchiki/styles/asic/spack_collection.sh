# All spack packages that should be fetched/installed in the container
spack_packages=(
#    "visionary-dev-tools ^${DEPENDENCY_PYTHON} %${YASHCHIKI_SPACK_GCC}" # FIXME
    "visionary-asic ^${DEPENDENCY_PYTHON} %${YASHCHIKI_SPACK_GCC}"
)

spack_views=(\
    visionary-asic
)

spack_views_no_default_gcc=(\
    visionary-asic # ECM: system compiler for now
)

spack_views_gccxml=(
)
