"""Verify modern NIS installed dependency and preserve old compatibility ABI."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('image', type=Path)
parser.add_argument('installed_root', type=Path)
parser.add_argument('feed', type=Path)
parser.add_argument('executable', type=Path)
args = parser.parse_args()
image, root, feed, executable = (p.resolve(strict=True) for p in (args.image, args.installed_root, args.feed, args.executable))
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
assert candidate['libnsl-3'].get('X-TDVP-Source-Version', candidate['libnsl-3']['Version']) == '2.0.1-1'
assert candidate['libnsl-3']['Version'] == installed['libnsl-3']['Version']
assert installed['libnsl-3']['Status'].endswith(' installed')
assert 'libtirpc (= ' + candidate['libtirpc']['Version'] + ')' in candidate['libnsl-3']['Depends']
assert (root / 'usr/lib/libnsl.so.3').is_file()
original, preserved = image / 'usr/lib/libnsl.so.1', root / 'usr/lib/libnsl.so.1'
assert original.is_symlink() == preserved.is_symlink()
if original.is_symlink():
    assert original.readlink() == preserved.readlink()
assert hashlib.sha256(original.read_bytes()).digest() == hashlib.sha256(preserved.read_bytes()).digest()
for filename in ('COPYING', 'README', 'SOURCE.json'):
    assert (root / 'usr/share/licenses/libnsl-3' / filename).is_file()
environment = dict(os.environ)
environment.pop('LD_LIBRARY_PATH', None)
environment.pop('QEMU_LD_PREFIX', None)
subprocess.run(['qemu-riscv64', '-L', str(root), '-E', 'LD_LIBRARY_PATH=' + str(root / 'usr/lib'), str(executable)], env=environment, check=True, timeout=30)
print('Installed modern NIS: PASS version/dependency/notices, preserved glibc ABI bytes and two loaded interfaces')
