#!/bin/bash -x

source /opt/spack/share/spack/setup-env.sh || exit 1

# we store all hashes currently installed
hashes_to_store="$(spack find -L | awk '/^[a-z0-9]/ { print "/"$1; }' | tr '\n' ' ')"
spack buildcache create -w -y -d /opt/build_cache -j$(nproc) ${hashes_to_store}
