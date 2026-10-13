"""Verify installed allocator/event providers and all declared notice bytes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('installed_root', type=Path)
parser.add_argument('feed', type=Path)
parser.add_argument('executable', type=Path)
args = parser.parse_args()
root, feed, executable = (p.resolve(strict=True) for p in (args.installed_root, args.feed, args.executable))
catalogues = []
for path in (feed / 'Packages', root / 'var/lib/opkg/status'):
    records = {}
    for block in path.read_text().split('\n\n'):
        fields = dict(line.split(': ', 1) for line in block.splitlines() if ': ' in line and not line.startswith((' ', '\t')))
        if 'Package' in fields:
            assert fields['Package'] not in records
            records[fields['Package']] = fields
    catalogues.append(records)
candidate, installed = catalogues
for name, version, soname in (('libtalloc', '2.5.0-1', 'libtalloc.so.2'), ('libtevent', '0.17.2-1', 'libtevent.so.0')):
    assert candidate[name].get('X-TDVP-Source-Version', candidate[name]['Version']) == version
    assert candidate[name]['Version'] == installed[name]['Version']
    assert installed[name]['Status'].endswith(' installed')
    assert (root / 'usr/lib' / soname).is_file()
    assert not (root / 'usr/lib' / (name + '.so')).exists()
    directory = root / 'usr/share/licenses' / name
    origin = json.loads((directory / 'SOURCE.json').read_text())
    assert set(origin['notice_sha256']) == {'LICENSE', 'GPL-3.0.txt', 'TDVP-COPYRIGHT-NOTICE'}
    for filename, digest in origin['notice_sha256'].items():
        assert hashlib.sha256((directory / filename).read_bytes()).hexdigest() == digest
    assert origin['notice_sha256']['GPL-3.0.txt'] == '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986'
assert 'libtalloc (= ' + candidate['libtalloc']['Version'] + ')' in candidate['libtevent']['Depends']
environment = dict(os.environ)
environment.pop('LD_LIBRARY_PATH', None)
environment.pop('QEMU_LD_PREFIX', None)
subprocess.run(['qemu-riscv64', '-L', str(root), '-E', 'LD_LIBRARY_PATH=' + str(root / 'usr/lib'), str(executable)], env=environment, check=True, timeout=30)
print('Installed talloc/tevent: PASS exact versions/dependency, three verified notices, runtime separation and timer/destructor consumer')
