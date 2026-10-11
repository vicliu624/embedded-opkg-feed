"""Assemble a new immutable raw candidate after validating every replacement."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

parser = argparse.ArgumentParser()
for name in ('source', 'replacements', 'plan', 'output'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
assert not args.output.exists() and not args.output.is_symlink()
plan = json.loads(args.plan.read_text())
assert plan['schema'] == 1 and plan['changes_applied'] is False
sources = {path.name: path for path in args.source.glob('*.ipk')}
assert len(sources) == plan['package_count']
selected = dict(sources)
records = []
for name, revision in plan['revisions'].items():
    old = sources[plan['packages'][name]['archive']]
    assert hashlib.sha256(old.read_bytes()).hexdigest() == revision['ipk_sha256']
    new = args.replacements / name / 'ipks' / f"{name}_{revision['new_version']}_riscv64.ipk"
    controls = []
    payloads = []
    for ipk in (old, new):
        data = subprocess.check_output(['ar', 'p', str(ipk), 'control.tar.gz'])
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            controls.append(archive.extractfile('./control').read().decode())
        data = subprocess.check_output(['ar', 'p', str(ipk), 'data.tar.gz'])
        files = {}
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            for member in archive:
                if member.isdir():
                    continue
                path = member.name.removeprefix('./')
                assert path not in files
                assert not path.startswith('/') and '..' not in Path(path).parts
                digest = hashlib.sha256(archive.extractfile(member).read()).hexdigest() if member.isfile() else None
                files[path] = (member.type.decode(), member.mode, member.linkname, digest)
        payloads.append(files)
    assert hashlib.sha256(controls[0].encode()).hexdigest() == revision['control_sha256']
    expected = controls[0].replace(f"Version: {revision['old_version']}\n", f"Version: {revision['new_version']}\n")
    for dependency, change in plan['revisions'].items():
        expected = expected.replace(f"{dependency} (= {change['old_version']})", f"{dependency} (= {change['new_version']})")
    assert controls[1] == expected, 'unexpected replacement control: ' + name
    assert payloads[0].keys() <= payloads[1].keys()
    assert all(value == payloads[1][path] for path, value in payloads[0].items()), 'original runtime changed: ' + name
    added = set(payloads[1]) - set(payloads[0])
    assert bool(added) == revision['adds_source_notices']
    assert all(path.startswith('usr/share/licenses/' + name + '/') and payloads[1][path][0] == '0' for path in added)
    del selected[old.name]
    assert new.name not in selected
    selected[new.name] = new
    records.append({'package': name, 'input_sha256': revision['ipk_sha256'],
                    'replacement_sha256': hashlib.sha256(new.read_bytes()).hexdigest(), 'added_paths': sorted(added)})
assert len(selected) == plan['package_count']
args.output.mkdir(parents=True)
for name, path in selected.items():
    shutil.copy2(path, args.output / name)
(args.output / 'notice-revision-assembly.json').write_text(json.dumps({
    'schema': 1, 'plan_sha256': hashlib.sha256(args.plan.read_bytes()).hexdigest(),
    'package_count': len(selected), 'replacements': records, 'release_authorized': False}, indent=2) + '\n')
print('Notice candidate assembly: PASS', len(selected), 'packages,', len(records), 'verified replacements; unsigned')
