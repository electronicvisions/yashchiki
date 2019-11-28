#!/usr/bin/env python
# encoding: utf-8

"""
Validate the given buildcache. Print all hashes that are in the buildcache but
(for whatever reason) not all hashes of their dependencies are.
"""


import argparse
import collections as c
import copy
import logging
import os
import os.path as osp
import re
import yaml


log = logging.getLogger("check_build_cache_integrity")


class BuildCache(object):
    """Represents a buildcache."""

    re_entry = re.compile(r"[a-z0-9]+\.tar\.gz$")

    def __init__(self, directory):
        self.directory = directory

        raw_entries = filter(
                self.re_entry.match,
                os.listdir(directory))

        self.entries = list(map(BuildcacheEntry, raw_entries))
        self.hash_to_entry = {e.hash: e for e in self.entries}

    def contains_hash(self, hash):
        return hash in self.hash_to_entry

    def __len__(self):
        return len(self.entries)


class BuildcacheEntry(object):
    def __init__(self, filename):
        self.filename = filename
        self.hash = osp.basename(filename).split(osp.extsep)[0]


class SpecCollection(object):
    """
    A collection of specs and a mapping from build_hashes to actual hashes.
    """

    def __init__(self, specfiles):
        self.specs = []
        self.build_hash_to_spec = {}
        self.build_hash_to_hash = {}

        for file in specfiles:
            for spec in get_specs(file):
                self.specs.append(spec)
                self.build_hash_to_spec[spec["build_hash"]] = spec
                self.build_hash_to_hash[spec["build_hash"]] = spec["hash"]


class SpecEntry(c.namedtuple("SpecEntry", ("spec", "entry"))):
    def __str__(self):
        return f"{self.spec['name']}@{self.spec['version']}: "\
               f"{self.entry.filename}"


def get_num_uniq_spec_entries(spec_entries):
    """
    Get the number of uniq spec entries:

    Args:
        spec_entries: Iteratble over SpecEntries

    Returns:
        number of uniq elements.
    """
    return len(set(map(lambda se: se.entry.hash, spec_entries)))


def get_specs(filename):
    """Read file and yield all specs it contains.

    Args:
        filename: String describing filename to read.

    Returns:
        Iterator over (name, spec)>
    """
    with open(filename, "r") as f:
        data = yaml.load(f)

    for e in data["spec"]:
        for name, spec in e.items():
            spec["name"] = name
            yield spec


def setup_log(verbosity, quietness):
    handler = logging.StreamHandler()

    handler.setFormatter(logging.Formatter(
        "%(asctime)s %(levelname)s: %(message)s",
        datefmt="%y-%m-%d %H:%M:%S"))

    log.addHandler(handler)

    if verbosity > 0:
        log.setLevel(logging.DEBUG)
    elif quietness > 1:
        log.setLevel(logging.FATAL)
    elif quietness > 0:
        log.setLevel(logging.ERROR)
    else:
        log.setLevel(logging.INFO)


def setup_parser():
    parser = argparse.ArgumentParser(description=__doc__)

    parser.add_argument(
        "-v", "--verbose", action="count", default=0,
        help="Be more verbose (overrides --quiet)")
    parser.add_argument(
        "-q", "--quiet", action="count", default=0,
        help="Be quiet(er)")

    parser.add_argument(
        "-b", "--build_cache", required=True,
        help="Build cache to be validated.")
    parser.add_argument(
        "specfile", nargs="+",
        help="Specfile from which hashes are extracted.")
    parser.add_argument(
        "-r", "--remove", action="store_true",
        help="Remove packages that are missing dependencies.")
    parser.add_argument(
        "-k", "--show-to-keep", action="store_true",
        help="Show packages that should be kept.")

    return parser


def specs_to_spec_entries(specs, build_cache):
    """Filter all given specs and yield only those that are present in the
    build_cache.

    Args:
        specs: Dictionary describing spec.

        build_cache: BuildCache instance to check specs against.

    Returns:
        Iterator over SpecEntries present in build_cache.
    """
    return map(lambda s: SpecEntry(s, build_cache.hash_to_entry[s["hash"]]),
               filter(lambda s: build_cache.contains_hash(s["hash"]),
                      specs))


def verify_spec(spec, spec_collection, build_cache):
    """
    Verify given spec in the context of build_cache.

    Args:
        spec: Dict describing spec details.

        spec_collection: SpecCollection object needed for mapping between
                         build_hash and real hash.

        build_cache: BuildCache object in which the spec should be verified.

    Returns:
        Boolean whether or not the spec was verified.
    """
    log.debug(f"Verifying {spec['name']}@{spec['version']} "
              f"[{spec['hash']}]")
    for dep, info in spec.get("dependencies", {}).items():
        if set(info["type"]).isdisjoint(set(["run", "link"])):
            log.debug("Skipping build-only dependency: "
                      f"[{spec['hash']}] -> {dep} [{info['hash']}]")
            continue
        if not build_cache.contains_hash(
                spec_collection.build_hash_to_hash[info["hash"]]):
            log.warning(
                "Dependency NOT in build cache: "
                f"{spec['name']}@{spec['version']} [{spec['hash']}] -> "
                f"{dep} [{info['hash']}]")
            return False
        else:
            log.debug(f"Dependency found: {spec['name']} "
                      f"[{spec['hash']}] -> {dep} [{info['hash']}]")
    return True


def verify_specfiles(specfiles, build_cache):
    """
    Verify all specfiles given.

    Args:
        specfiles: Iterator of specfiles.

        build_cache: BuildCache instance in which the specfile should be
                     checked.

    Returns:
        Dict with "missing" and "present" keys. Each is a list of SpecEntries.
        "present" points to a list with specs that exist with all their
        dependencies in the build cache and "missing" points to a list with
        those that do not.
    """
    spec_collection = SpecCollection(specfiles)

    spec_deps_missing = []
    spec_deps_present = []

    for spec in copy.deepcopy(spec_collection.specs):
        if verify_spec(spec,
                       spec_collection=spec_collection,
                       build_cache=build_cache):
            spec_deps_present.append(spec)
        else:
            spec_deps_missing.append(spec)

    log.info(f"{len(spec_deps_missing)}/{len(spec_collection.specs)} "
             "specs have missing deps, "
             f"{len(spec_deps_present)}/{len(spec_collection.specs)} "
             "specs have all deps!")

    spec_deps_present = list(specs_to_spec_entries(spec_deps_present,
                                                   build_cache=build_cache))
    spec_deps_missing = list(specs_to_spec_entries(spec_deps_missing,
                                                   build_cache=build_cache))

    log.info(f"{get_num_uniq_spec_entries(spec_deps_missing)}"
             f"/{len(build_cache.entries)} entries have missing deps, "
             f"{get_num_uniq_spec_entries(spec_deps_present)}"
             f"/{len(build_cache.entries)} entries have all deps!")

    log.debug(f"{'=' * 30} PRESENT {'=' * 30}")
    for se in spec_deps_present:
        log.debug(f"{se.entry.hash} present {se}")
    log.debug(f"{'=' * 30} MISSING {'=' * 30}")
    for se in spec_deps_missing:
        log.debug(f"{se.entry.hash} missing {se}")

    return {"present": spec_deps_present, "missing": spec_deps_missing}


if __name__ == "__main__":
    parser = setup_parser()
    args = parser.parse_args()

    setup_log(args.verbose, args.quiet)

    build_cache = BuildCache(args.build_cache)

    if args.verbose:
        log.info(f"# of Hashes in build cache: {len(build_cache)}")
        if log.getEffectiveLevel() <= logging.DEBUG:
            for e in build_cache.entries:
                log.debug(f"Hash in cache: {e.hash}")

    checked_specs = verify_specfiles(args.specfile, build_cache)
    to_remove = checked_specs["missing"]
    to_keep = checked_specs["present"]

    if not args.remove:
        if len(to_remove) > 0:
            log.warning(
                f"# The following {len(to_remove)} specs should be removed "
                "from the buildcache:")
            for se in to_remove:
                log.warning(se)
        else:
            log.info("No entries should be removed from build cache.")
        if args.show_to_keep and len(to_keep) > 0:
            log.info(
                f"# The following {len(to_keep)} specs should be kept "
                "from the buildcache:")
            for se in to_keep:
                log.info(se)
    else:
        for e in to_remove:
            log.info(f"Removing {e.filename}..")
            os.remove(e.filename)
