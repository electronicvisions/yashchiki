# Yashchiki

Visionary "containering"…

## Supported keywords in gerrit message

### `BUILD_THIS`

Start a yashicki build with this change as toplevel.


### `WITHOUT_FAILED_CACHE`

If a testing build fails, link all preserved packages and the current build
cache to a new temporary build cache under `failed/c<num>p<num>_<num>`.

Behaviour for testing builds triggered from gerrit:
* Unless the user specifies `WITHOUT_FAILED_CACHE` in the gerrit commit,
  check if there is a failed build cache for this changeset that was
  created as described above and use the latest one as build cache for
  the current build.
* The user can also supply `WITH_CACHE_NAME=<name>` to specify a
  different build cache to be used for this build.


### `WITH_CACHE_NAME=<name>`

Use `/home/vis_jenkins/build_caches/<name>` on `conviz` as buildcache instead
of the default one. Can also be used for failed caches.


### `WITH_SPACK_{CHANGE,REFSPEC}`

Since often times yashchiki and spack changes are tested together but
have no real dependency on one another, we misuse the `Depends-On`
mechanism in the commit message to build a container with a specific
spack and yashchiki changeset.

This changeset adds the possibility to specify:
* `WITH_SPACK_CHANGE=<change-num>` to use the latest patch set of the
  given spack changeset for the build
* `WITH_SPACK_REFSPEC=<refspec>` to specify a complete spack refspec
  that is to be used for this build (i.e.,
  refs/changes/<change-num[-2:]>/<change-num>/<patch-level>) to have
  full control over which changeset/patch level to build.

These take priority over commit-specified `Depends-On:` and are mutually
exclusive with jenkins-specified build parameters since each build gets
either triggered manually in jenkins or via gerrit.


### `WITH_DEBUG`

Specifying `WITH_DEBUG` in the triggering comment will enable debug output.
