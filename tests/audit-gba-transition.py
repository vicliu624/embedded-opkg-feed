import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tarfile
import tempfile

p = argparse.ArgumentParser()
for name in ('image', 'feed', 'old_ipk', 'opkg', 'output'):
    p.add_argument('--' + name.replace('_', '-'), type=Path, required=True)
a = p.parse_args()
work = Path(tempfile.mkdtemp(prefix='gba-transition.', dir=a.output))
root = work / 'root'
root.mkdir()
subprocess.run(['cp', '-a', '--reflink=auto', str(a.image) + '/.', str(root)], check=True)
status = root / 'var/lib/opkg/status'
original_status = status.read_bytes()
owner_lists = {x.name: x.read_bytes() for x in (a.image / 'var/lib/opkg/info').glob('*.list')}
control = subprocess.check_output(['ar', 'p', str(a.old_ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control), mode='r:gz') as archive:
    record = archive.extractfile('./control').read().decode()
assert 'Package: tdvp-cardputer-zero-gba\n' in record
assert 'Version: 0.1.0-12\n' in record
data = subprocess.check_output(['ar', 'p', str(a.old_ipk), 'data.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
    paths = [x.name.removeprefix('./') for x in archive.getmembers() if x.isfile() or x.issym()]
    assert all(not os.path.lexists(a.image / x) for x in paths), 'old GBA overlaps the paired image'
    archive.extractall(root, filter='data')
(root / 'var/lib/opkg/info/tdvp-cardputer-zero-gba.list').write_text(''.join('/' + x + '\n' for x in paths))
status.write_bytes(original_status + ('\n' + record.strip() + '\nStatus: install ok installed\n\n').encode())
lists = root / 'var/lib/opkg/audit-lists'
lists.mkdir()
(lists / 'audit').write_bytes((a.feed / 'Packages').read_bytes())
config = work / 'opkg.conf'
config.write_text('dest root /\noption info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\n'
    'option lists_dir /var/lib/opkg/audit-lists\narch riscv64 10\narch all 1\nsrc audit ' + a.feed.resolve().as_uri() + '\n')
command = [str(a.opkg), '-f', str(config), '-o', str(root)]
result = subprocess.run(command + ['upgrade', 'tdvp-cardputer-zero-gba'], capture_output=True, text=True)
(work / 'upgrade.log').write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stdout + result.stderr
records = {}
for record in status.read_text().split('\n\n'):
    fields = dict(x.split(': ', 1) for x in record.splitlines() if ': ' in x and not x.startswith(' '))
    if 'Package' in fields:
        records[fields['Package']] = fields
assert records['tdvp-cardputer-zero-gba']['Version'].startswith('0.1.0-13')
assert records['tdvp-gba']['Status'] in ('install ok installed', 'install ok unpacked')
assert not any(os.path.lexists(root / x) for x in paths), 'obsolete GBA files remain'
assert (root / 'usr/share/applications/tdvp-gba.desktop').is_file()
for record in original_status.decode().split('\n\n'):
    fields = dict(x.split(': ', 1) for x in record.splitlines() if ': ' in x and not x.startswith(' '))
    if 'Package' in fields:
        for field in ('Version', 'Status', 'Essential'):
            assert records[fields['Package']].get(field) == fields.get(field)
for name, content in owner_lists.items():
    assert (root / 'var/lib/opkg/info' / name).read_bytes() == content, name
manifest = json.loads((a.image / 'usr/share/tdvp/opkg/image-base.json').read_text())
for name, expected in manifest['files'].items():
    target = root / name.lstrip('/')
    assert os.path.lexists(target), name
    if expected['type'] == 'file':
        assert target.is_file() and not target.is_symlink(), name
        assert stat.S_IMODE(target.lstat().st_mode) == expected['mode'], name
        assert hashlib.sha256(target.read_bytes()).hexdigest() == expected['sha256'], name
    elif expected['type'] == 'symlink':
        assert target.is_symlink() and os.readlink(target) == expected['target'], name
report = {'upgrade_returncode': 0, 'old_version': '0.1.0-12',
    'new_version': records['tdvp-cardputer-zero-gba']['Version'], 'current_application': records['tdvp-gba']['Version'],
    'old_payload_removed': True, 'current_desktop_entry_present': True, 'base_unchanged': True,
    'target_code_executed': False, 'work': str(work)}
(work / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
