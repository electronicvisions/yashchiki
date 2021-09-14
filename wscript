def depends(ctx):
    ctx("spack", branch="visionary")

def options(opt):
    pass

def configure(cfg):
    pass

def build(bld):
    # install /bin
    for bin in bld.path.ant_glob('bin/**/*'):
        bld.install_as('${PREFIX}/%s' % bin.path_from(bld.path), bin)

    # install /lib
    for lib in bld.path.ant_glob('lib/**/*'):
        bld.install_as('${PREFIX}/%s' % lib.path_from(bld.path), lib)

    # install /share
    for share in bld.path.ant_glob('share/**/*'):
        bld.install_as('${PREFIX}/%s' % share.path_from(bld.path), share)
