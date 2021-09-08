cat <<EOF
####################################
# Packages still plagued by gccxml #
####################################

${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer $(get_latest_hash visionary-wafer+dev~gccxml)
${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-nodev $(get_latest_hash visionary-wafer~dev~gccxml)

##################################################
# Strong independent packages who need no gccxml #
##################################################

${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation $(get_latest_hash "visionary-simulation+dev")
${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-simulation-nodev $(get_latest_hash "visionary-simulation~dev")

${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-core $(get_latest_hash visionary-dls-core "^${DEPENDENCY_PYTHON3}")

${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls $(get_latest_hash visionary-dls+dev "^${DEPENDENCY_PYTHON3}")
${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-nodev $(get_latest_hash visionary-dls~dev "^${DEPENDENCY_PYTHON3}")

# slurvmiz needs no dev-tools because it is not for end-users
${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-slurmviz $(get_latest_hash "visionary-slurmviz %${YASHCHIKI_SPACK_GCC}")

#############
# dev tools #
#############

${MY_SPACK_BIN} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dev-tools $(get_latest_hash "${SPEC_VIEW_VISIONARY_DEV_TOOLS}")
EOF
