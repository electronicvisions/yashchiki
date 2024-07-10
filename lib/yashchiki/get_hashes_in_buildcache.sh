# get hashes in buildcache [<build_cache-directory>]
# <buildcache-directory> defaults to ${BUILD_CACHE_INSIDE} if not supplied.
get_hashes_in_buildcache() {
    local buildcache_dir
    buildcache_dir="${1}"

    local resultsfile
    resultsfile=$(mktemp)

    if [ -d "${buildcache_dir}" ]; then
        # Naming scheme in the build_cache is <checksum>.tar.gz -> extract from full path
        ( find "${buildcache_dir}" -name "*.tar.gz" -mindepth 1 -maxdepth 1 -print0 \
            | xargs -r -0 -n 1 basename \
            | sed -e "s:\.tar\.gz$::g" \
	    | sort >"${resultsfile}") || /bin/true
    fi
    echo "DEBUG: Found $(wc -l <"${resultsfile}") hashes in buildcache: ${buildcache_dir}" >&2
    cat "${resultsfile}"
    rm "${resultsfile}"
}
