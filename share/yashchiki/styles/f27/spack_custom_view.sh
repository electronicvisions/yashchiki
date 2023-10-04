cat <<EOF

${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/ido $(get_latest_hash f27-ido "^${DEPENDENCY_PYTHON}")
${MY_SPACK_CMD} ${SPACK_ARGS_VIEW[@]+"${SPACK_ARGS_VIEW[@]}"} view -d yes symlink -i ${MY_SPACK_VIEW_PREFIX}/niklas $(get_latest_hash f27-niklas "^${DEPENDENCY_PYTHON}")

EOF
