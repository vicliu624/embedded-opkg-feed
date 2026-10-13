"""Build an isolated notice-only revision using the production IPK packager."""
import argparse
import hashlib
import io
import json
import os
import re
import shlex
from pathlib import Path
import subprocess
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--package', default='libzstd', choices=('libzstd', 'libsqlite3-0', 'libubootenv-0',
    'archive-tools', 'dialog', 'htop', 'nano', 'ncdu', 'rsync', 'tmux', 'wget',
    'libcurl-4', 'python3-runtime', 'tdvp-dev-tools', 'tdvp-diagnostics', 'tdvp-source-tools',
    'curl', 'python3', 'tdvp-nodejs-tools', 'libboost', 'libmariadb', 'libnetcdf', 'libopenexr', 'libsoup3'))
plans = parser.add_mutually_exclusive_group()
plans.add_argument('--revision-plan', type=Path)
plans.add_argument('--candidate-plan', type=Path)
parser.add_argument('--notices', type=Path)
for name in ('repo', 'ipk', 'output', 'sdk', 'base', 'owners'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
metadata = (args.repo / 'packages' / args.package / 'package.env').read_text()
old_version = re.search(r"^VERSION='([^']+)'", metadata, re.M)[1]
upstream, revision = old_version.rsplit('-', 1)
assert revision.isdecimal()
new_version = upstream + '-' + str(int(revision) + 1)
revisions = {}
if args.revision_plan or args.candidate_plan:
    plan = json.loads((args.revision_plan or args.candidate_plan).read_text())
    assert plan['schema'] == 1 and plan['changes_applied'] is False
    revisions = plan['revisions']
    assert args.package in revisions
    for name, change in revisions.items():
        assert re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', name)
        if args.revision_plan:
            assert hashlib.sha256((args.repo / 'packages' / name / 'package.env').read_bytes()).hexdigest() == change['package_env_sha256']
    assert revisions[args.package]['old_version'] == old_version
    assert revisions[args.package]['new_version'] == new_version
assert not args.output.exists()
source_digest = hashlib.sha256(args.ipk.read_bytes()).hexdigest()
if args.candidate_plan:
    assert source_digest == revisions[args.package]['ipk_sha256'], 'candidate IPK identity changed'
data = subprocess.check_output(['ar', 'p', str(args.ipk), 'data.tar.gz'])
control = subprocess.check_output(['ar', 'p', str(args.ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control), mode='r:gz') as archive:
    old_control = archive.extractfile('./control').read().decode()
assert f'Package: {args.package}\n' in old_control and f'Version: {old_version}\n' in old_control
if args.candidate_plan:
    assert hashlib.sha256(old_control.encode()).hexdigest() == revisions[args.package]['control_sha256']
files = []
if args.notices:
    record = json.loads((args.notices / 'notice-source-record.json').read_text())
    files = record['providers'][args.package]['files'] if 'providers' in record else [
        item for origin in record['archives'] if origin['package'] == args.package for item in origin['files']]
    assert files
else:
    assert revisions and revisions[args.package]['adds_source_notices'] is False
for item in files:
    assert item['path'].startswith(f'usr/share/licenses/{args.package}/')
    assert '..' not in Path(item['path']).parts
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
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata or "PACKAGE_BASE_OVERLAY='identical'" in metadata
metadata = metadata.replace(f"VERSION='{old_version}'", f"VERSION='{new_version}'")
metadata = metadata.replace("PACKAGE_BASE_OVERLAY='deny'", "PACKAGE_BASE_OVERLAY='identical'")
if args.candidate_plan:
    fields = dict(re.findall(r'^([A-Za-z0-9-]+): ([^\n]*)$', old_control, re.M))
    dependencies = re.sub(r'^tdvp-platform-abi \(= [^)]+\)(?:,|$)', '', fields.get('Depends', ''))
    dependencies = re.sub(r' \| tdvp-image-[a-z0-9+.-]+', '', dependencies)
    # The candidate control is the metadata authority for this isolated reuse.
    # Production recipe changes remain a separate reviewed operation.
    for key, value in {'PACKAGE_DEPENDS': dependencies, 'DESCRIPTION': fields['Description'],
                       'MAINTAINER': fields['Maintainer'], 'PACKAGE_SECTION': fields['Section']}.items():
        metadata += '\n' + key + '=' + shlex.quote(value) + '\n'
for name, change in revisions.items():
    metadata = metadata.replace(f"{name} (= {change['old_version']})", f"{name} (= {change['new_version']})")
(package / 'package.env').write_text(metadata)
environment = dict(os.environ, TDVP_SDK_ROOT=str(args.sdk), TDVP_FEED_BASE_ROOT=str(args.base),
                   TDVP_RUNTIME_OWNER_MAP=str(args.owners),
                   TDVP_READELF=str(args.sdk / 'bin/riscv64-unknown-linux-gnu-readelf'))
if revisions:
    owner_lines = []
    for line in args.owners.read_text().splitlines():
        fields = line.split('|')
        if len(fields) == 3 and fields[1] in revisions:
            change = revisions[fields[1]]
            assert fields[2] == change['old_version'], 'unexpected owner version'
            fields[2] = change['new_version']
            line = '|'.join(fields)
        owner_lines.append(line)
    revised_owners = args.output / 'runtime-owners.tsv'
    revised_owners.write_text('\n'.join(owner_lines) + '\n')
    environment['TDVP_RUNTIME_OWNER_MAP'] = str(revised_owners)
# Reproduce explicit historical image alternatives; the final control equality
# gate rejects any missing, reordered or additional dependency regardless.
aliases = re.findall(r'([a-z0-9+.-]+) \(= [^)]+\) \| (tdvp-image-[a-z0-9+.-]+)', old_control)
if aliases:
    mapping = args.output / 'image-provider-map.tsv'
    mapping.write_text(''.join(provider + '|' + image + '\n' for provider, image in sorted(set(aliases))))
    environment['TDVP_IMAGE_PROVIDER_MAP'] = str(mapping)
subprocess.run(['bash', str(args.repo / 'scripts/build-ipk.sh'), '--platform', 'tdvp-k230-r1',
                str(package), str(args.output / 'ipks')], env=environment, check=True)
new_ipk = args.output / 'ipks' / f'{args.package}_{new_version}_riscv64.ipk'
new_control_archive = subprocess.check_output(['ar', 'p', str(new_ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(new_control_archive), mode='r:gz') as archive:
    new_control = archive.extractfile('./control').read().decode()
expected_control = old_control.replace(f'Version: {old_version}\n', f'Version: {new_version}\n')
for name, change in revisions.items():
    expected_control = expected_control.replace(f"{name} (= {change['old_version']})", f"{name} (= {change['new_version']})")
assert new_control == expected_control, 'unexpected control or dependency change'
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
print('Isolated notice revision: PASS', args.package, 'production packager, only planned control revisions, original payload and', len(files), 'exact additions; not release-authorized')
