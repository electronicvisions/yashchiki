cat <<EOF
####################################
# Packages still plagued by gccxml #
####################################

${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer $(get_latest_hash visionary-wafer+dev~gccxml)
${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-wafer-nodev $(get_latest_hash visionary-wafer~dev~gccxml)

##################################################
# Strong independent packages who need no gccxml #
##################################################

${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-core $(get_latest_hash visionary-dls-core)

${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls $(get_latest_hash visionary-dls+dev)
${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dls-nodev $(get_latest_hash visionary-dls~dev)

# slurvmiz needs no dev-tools because it is not for end-users
${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-slurmviz $(get_latest_hash "visionary-slurmviz %${YASHCHIKI_SPACK_GCC}")

#############
# dev tools #
#############

${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-dev-tools $(get_latest_hash "visionary-dev-tools %${YASHCHIKI_SPACK_GCC}")
EOF
