#!/bin/bash

set -euo pipefail

# This script searches the environment-modules install folder for the init
# folder which contains the init scripts for a variety of shells.
# Unfortunately the location of the init folder changed between versions 3.x
# and 4.x which is why we now "find" it.

TARGET="/opt/init/modules.sh"
PATH_SOURCE="$(readlink -m "${BASH_SOURCE[0]}")"

MODULESHOME="$(/opt/spack/bin/spack location -i environment-modules)"
PATH_MODULES="$(find "${MODULESHOME}" -type d -path "*init" | head -n 1)"

cat <<EOF > "${TARGET}"
#!/bin/bash

EOF

cat <<EOF | tr '\n' ' ' | fold -w 78 -s | sed "s:^:# :g" >> "${TARGET}"
This script has been generated on $(date) via ${PATH_SOURCE} by searching
the environment-modules install folder for the init folder which contains the
init scripts for a variety of shells. It can be regenerated by running
${PATH_SOURCE} again.
EOF

(echo; echo) >> "${TARGET}"

cat <<EOF >> "${TARGET}"
source "${PATH_MODULES}/\$(readlink -f /proc/\$\$/exe | xargs basename)"
EOF

# Provide MODULESHOME for all singularity environments
cat <<EOF >> ${SINGULARITY_ENVIRONMENT}
MODULESHOME=${MODULESHOME}
export MODULESHOME
EOF

# ensure that the directories with spack-generated module files are available
# to use after sourcing /opt/init/modules.sh
(
IFS=$'\n'
for moduledir in $(find /opt/spack/share/spack/modules -mindepth 1 -maxdepth 1 -type d); do
cat <<EOF >> "${TARGET}"
export MODULEPATH="${moduledir}\${MODULEPATH:+:\${MODULEPATH}}"
EOF
done
)
