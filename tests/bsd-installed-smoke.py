"""Verify actual opkg-installed BSD libraries and run a compiled target consumer."""
import argparse
from pathlib import Path
import os
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
for name, version in (('libmd', '1.2.0-1'), ('libbsd', '0.12.2-1')):
    assert candidate[name]['Version'] == installed[name]['Version'] == version
    assert installed[name]['Status'].endswith(' installed')
    assert (root / 'usr/lib' / (name + '.so.0')).is_file()
    assert not (root / 'usr/lib' / (name + '.so')).exists(), 'development linker file leaked into runtime'
    assert (root / 'usr/share/licenses' / name / 'COPYING').is_file()
assert 'libmd (= 1.2.0-1)' in candidate['libbsd']['Depends']
environment = dict(os.environ)
environment.pop('LD_LIBRARY_PATH', None)
environment.pop('QEMU_LD_PREFIX', None)
subprocess.run(['qemu-riscv64', '-L', str(root), '-E', 'LD_LIBRARY_PATH=' + str(root / 'usr/lib'), str(executable)], env=environment, check=True, timeout=30)
print('Installed BSD providers: PASS exact versions, dependency, notices, runtime separation and target consumer')
