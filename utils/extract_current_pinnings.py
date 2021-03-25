#!/usr/env/python

''''Util to extract a list of pinnings from the current container'''

import yaml
import argparse


apps = ['wafer', 'dls', 'simulation', 'slurmviz']


for app in apps:
    speclist = ''
    try:
        spec = yaml.load(open(f'/opt/spack_views/visionary-{app}/.spack/visionary-{app}/spec.yaml'))
        for singlespec in spec['spec'][1:]:
            for k, v in singlespec.items():
                speclist += f'{k}@{v["version"]}\n'

        print(f'Writing dependency list "{spec-dep-{app}.list}"')
        with open(f'spec-dep-{app}.list', 'w') as f:
            f.write(speclist)
    except:
        print('Script must be run from within a container.')
        raise
