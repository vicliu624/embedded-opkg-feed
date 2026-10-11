"""Build an isolated notice-only revision using the production IPK packager."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tarfile

parser = argparse.ArgumentParser()
for name in ('repo', 'ipk', 'notices', 'output', 'sdk', 'base', 'owners'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
assert not args.output.exists()
source_digest = hashlib.sha256(args.ipk.read_bytes()).hexdigest()
data = subprocess.check_output(['ar', 'p', str(args.ipk), 'data.tar.gz'])
control = subprocess.check_output(['ar', 'p', str(args.ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control), mode='r:gz') as archive:
    old_control = archive.extractfile('./control').read().decode()
assert 'Package: libzstd\n' in old_control and 'Version: 1.5.7-1\n' in old_control
record = json.loads((args.notices / 'notice-source-record.json').read_text())
files = record['providers']['libzstd']['files']
assert len(files) == 2
for item in files:
    assert item['path'].startswith('usr/share/licenses/libzstd/')
    assert hashlib.sha256((args.notices / item['path']).read_bytes()).hexdigest() == item['sha256']
args.output.mkdir(parents=True)
package = args.output / 'package'
payload = package / 'root'
payload.mkdir(parents=True)
with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
    archive.extractall(payload, filter='data')
for item in files:
    destination = payload / item['path']
    assert not destination.exists() and not destination.is_symlink()
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes((args.notices / item['path']).read_bytes())
metadata = (args.repo / 'packages/libzstd/package.env').read_text()
assert "VERSION='1.5.7-1'" in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
metadata = metadata.replace("VERSION='1.5.7-1'", "VERSION='1.5.7-2'")
metadata = metadata.replace("PACKAGE_BASE_OVERLAY='deny'", "PACKAGE_BASE_OVERLAY='identical'")
(package / 'package.env').write_text(metadata)
environment = dict(os.environ, TDVP_SDK_ROOT=str(args.sdk), TDVP_FEED_BASE_ROOT=str(args.base),
                   TDVP_RUNTIME_OWNER_MAP=str(args.owners),
                   TDVP_READELF=str(args.sdk / 'bin/riscv64-unknown-linux-gnu-readelf'))
subprocess.run(['bash', str(args.repo / 'scripts/build-ipk.sh'), '--platform', 'tdvp-k230-r1',
                str(package), str(args.output / 'ipks')], env=environment, check=True)
new_ipk = args.output / 'ipks/libzstd_1.5.7-2_riscv64.ipk'
new_control_archive = subprocess.check_output(['ar', 'p', str(new_ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(new_control_archive), mode='r:gz') as archive:
    new_control = archive.extractfile('./control').read().decode()
assert new_control == old_control.replace('Version: 1.5.7-1\n', 'Version: 1.5.7-2\n'), 'unexpected control or dependency change'
new_data = subprocess.check_output(['ar', 'p', str(new_ipk), 'data.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as old, tarfile.open(fileobj=io.BytesIO(new_data), mode='r:gz') as new:
    old_members = {m.name.removeprefix('./'): m for m in old if not m.isdir()}
    new_members = {m.name.removeprefix('./'): m for m in new if not m.isdir()}
    assert set(new_members) - set(old_members) == {item['path'] for item in files}
    assert set(old_members) <= set(new_members)
    for item in files:
        assert new.extractfile(new_members[item['path']]).read() == (args.notices / item['path']).read_bytes()
    for name, member in old_members.items():
        updated = new_members[name]
        assert (member.type, member.mode, member.linkname) == (updated.type, updated.mode, updated.linkname)
        if member.isfile():
            assert old.extractfile(member).read() == new.extractfile(updated).read()
assert hashlib.sha256(args.ipk.read_bytes()).hexdigest() == source_digest
print('Zstd isolated notice revision: PASS production packager, unchanged controls except revision, original payload and two exact additions; not release-authorized')
