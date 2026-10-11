"""Verify opkg-installed native/compatible DBM libraries and persistent operations."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

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
assert candidate['libgdbm'].get('X-TDVP-Source-Version', candidate['libgdbm']['Version']) == '1.26-1'
assert candidate['libgdbm']['Version'] == installed['libgdbm']['Version']
assert installed['libgdbm']['Status'].endswith(' installed')
for soname in ('libgdbm.so.6', 'libgdbm_compat.so.4'):
    assert (root / 'usr/lib' / soname).is_file()
for development in ('libgdbm.so', 'libgdbm_compat.so'):
    assert not (root / 'usr/lib' / development).exists()
for filename in ('COPYING', 'AUTHORS', 'SOURCE.json'):
    assert (root / 'usr/share/licenses/libgdbm' / filename).is_file()
environment = dict(os.environ)
environment.pop('LD_LIBRARY_PATH', None)
environment.pop('QEMU_LD_PREFIX', None)
with tempfile.TemporaryDirectory(prefix='tdvp-gdbm-installed-') as directory:
    subprocess.run(['qemu-riscv64', '-L', str(root), '-E', 'LD_LIBRARY_PATH=' + str(root / 'usr/lib'), str(executable)], cwd=directory, env=environment, check=True, timeout=30)
    assert not list(Path(directory).iterdir()), 'database fixture cleanup incomplete'
print('Installed GDBM: PASS version, notices, runtime/development separation, persistence and traditional DBM operations')
