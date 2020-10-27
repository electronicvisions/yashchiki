#!/bin/bash
#
# Deploys the given file while inserting a preamble after shebang.
#

src="${2}"
dst="${1}"

if [ -d "${1}" ]; then
    dst="${1}/$(basename ${src})"
fi

make_preamble()
{
echo "#"
echo "# auto-deployed on $(date --iso) via"
echo "# https://brainscales-r.kip.uni-heidelberg.de:11443/job/bld_install-yashchiki/"
echo -n "# from git-commit: "
git log --no-decorate --oneline -n 1
echo "#"
echo "# Please submit changes at ssh://brainscales-r.kip.uni-heidelberg.de:29418/yashchiki"
echo ""
}

# source and destination are reversed for xargs!
len_preamble=$(awk -f "$(git rev-parse --show-toplevel)/.ci/find_num_lines_shebang.awk" "${src}")
head -n "${len_preamble}" "${src}" > "${dst}"
make_preamble >> "${dst}"
tail -n +$(( len_preamble + 1 )) "${src}" >> "${dst}"

# make scripts executable
chmod +x "${dst}"
