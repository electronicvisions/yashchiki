# All spack packages that should be fetched/installed in the container
spack_packages=(
#    "${SPEC_VIEW_VISIONARY_DEV_TOOLS}" # FIXME
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

spack_gid="nobody"

spack_create_user_cmd() {
    adduser spack --uid 888 --gid nobody --no-create-home --no-user-group --home /opt/spack --system --shell /bin/bash
}
