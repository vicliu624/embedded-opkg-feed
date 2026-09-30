#!/usr/bin/env python3
"""Register public SONAME providers emitted by source-built feed libraries."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile


def read_map(path):
    records = {}
    for line in path.read_text().splitlines():
        if not line or line.startswith('#'):
            continue
        fields = line.split('|')
        if (len(fields) != 3 or not re.fullmatch(r'[A-Za-z0-9_+.-]+', fields[0])
                or not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', fields[1])
                or not re.fullmatch(r'[A-Za-z0-9.+:~_-]+', fields[2])):
            raise ValueError('invalid runtime owner record')
        soname, package, version = fields
        owner = (package, version)
        if soname in records and records[soname] != owner:
            raise ValueError(f'ambiguous runtime owner: {soname}')
        records[soname] = owner
    return records


def public_sonames(root, readelf):
    sonames = set()
    directory = root / 'usr/lib'
    for path in sorted(directory.glob('lib*.so*')):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open('rb') as stream:
            if stream.read(4) != b'\x7fELF':
                continue
        result = subprocess.run([readelf, '-d', str(path)], capture_output=True, text=True, check=True)
        sonames.update(re.findall(r'\(SONAME\).*\[([^\]]+)\]', result.stdout))
    return sonames


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner-map', type=Path, required=True)
    parser.add_argument('--payload-root', type=Path, required=True)
    parser.add_argument('--readelf', required=True)
    parser.add_argument('--package')
    parser.add_argument('--version')
    parser.add_argument('--import-map', type=Path)
    parser.add_argument('--allowed-package', action='append', default=[])
    arguments = parser.parse_args()
    if arguments.owner_map.is_symlink() or not arguments.owner_map.is_file():
        raise ValueError('runtime owner map must be a regular file')
    records = read_map(arguments.owner_map)
    available = public_sonames(arguments.payload_root, arguments.readelf)
    if arguments.import_map:
        allowed = dict(value.split('=', 1) for value in arguments.allowed_package)
        additions = {}
        for soname, owner in read_map(arguments.import_map).items():
            if records.get(soname) == owner:
                continue
            package, version = owner
            if allowed.get(package) != version or soname not in available:
                raise ValueError(f'imported provider lacks matching package and staged library: {soname}')
            additions[soname] = owner
    else:
        if (not arguments.package or not arguments.version
                or not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', arguments.package)
                or not re.fullmatch(r'[A-Za-z0-9.+:~_-]+', arguments.version)):
            raise ValueError('a valid source package and version are required')
        additions = {soname: (arguments.package, arguments.version) for soname in available}
    for soname, owner in additions.items():
        if not re.fullmatch(r'[A-Za-z0-9_+.-]+', soname):
            raise ValueError('invalid public SONAME')
        if soname in records and records[soname] != owner:
            raise ValueError(f'runtime provider collision: {soname}')
    updated = dict(records, **additions)
    if updated != records:
        with tempfile.NamedTemporaryFile(mode='w', dir=arguments.owner_map.parent, delete=False) as stream:
            temporary = Path(stream.name)
            for soname, (package, version) in sorted(updated.items()):
                stream.write(f'{soname}|{package}|{version}\n')
        try:
            os.replace(temporary, arguments.owner_map)
        finally:
            temporary.unlink(missing_ok=True)
    print(f'runtime owners registered: {len(additions)} public SONAMEs')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f'runtime owner registration failed: {error}') from None
