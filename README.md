# Yashchiki

Visionary container image build flow.
This repository contains code and CI configuration files to build a singularity-based container image containing all visionary software dependencies.
Currently two different images are generated:
firstly, a standard image for experimenting/modeling, software development and related activities with BrainScaleS and other systems — software is provided by a Spack-based installation process;
secondly, an *ASIC*-image providing an environment for ASIC-related tools (RTL simulators, etc.).
The CI flow (via Jenkins) integrates into Gerrit (Code-Review tool) for triggering container image builds as well as software builds based on *testing* container images.

## Supported keywords in gerrit message

NOTE: These options are to be specified in the gerrit COMMENT message, NOT in
the git COMMIT message!

The idea is that, often times, these modifiers are just temporarily attached to
a single build rather than a complete change.

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


### `WITH_DEBUG`

Specifying `WITH_DEBUG` in the triggering comment will enable debug output.


## Supported keywords in commit message

Since often times yashchiki and spack changes are tested together but
have no real dependency on one another, we misuse the `Depends-On`
mechanism in the commit message to build a container with a specific
spack and yashchiki changeset.
