cat <<EOF
# just visionary-asic
${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/visionary-asic $(get_latest_hash "visionary-asic")
EOF
