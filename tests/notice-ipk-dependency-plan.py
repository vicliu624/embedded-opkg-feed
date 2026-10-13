"""Inspect immutable candidate controls before coordinating notice revisions."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('feed', type=Path)
args = parser.parse_args()
packages = {}
for path in sorted(args.feed.glob('*.ipk')):
    members = subprocess.check_output(['ar', 't', str(path)], text=True).splitlines()
    control_member = next(name for name in members if name.startswith('control.tar'))
    data = subprocess.check_output(['ar', 'p', str(path), control_member])
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as archive:
        control = next(member for member in archive if member.name.removeprefix('./') == 'control')
        text = archive.extractfile(control).read().decode()
    fields = dict(re.findall(r'^([A-Za-z0-9-]+): ([^\n]*)$', text, re.M))
    name = fields['Package']
    assert name not in packages, 'duplicate package versions: ' + name
    packages[name] = {'version': fields['Version'], 'depends': fields.get('Depends', ''),
                      'description': fields.get('Description', ''), 'archive': path.name,
                      'ipk_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'control_sha256': hashlib.sha256(text.encode()).hexdigest()}
initial = set('archive-tools dialog htop libsqlite3-0 libubootenv-0 libzstd nano ncdu rsync tmux wget'.split())
assert initial <= packages.keys()
affected = set(initial)
rounds = []
while True:
    added = {name for name, values in packages.items() if name not in affected
             and any(dependency in affected and packages[dependency]['version'] == version
                     for dependency, version in re.findall(r'([a-z0-9+.-]+) \(= ([^)]+)\)', values['depends']))}
    if not added:
        break
    affected.update(added)
    rounds.append(sorted(added))
revisions = {}
for name in sorted(affected):
    version = packages[name]['version']
    upstream, revision = version.rsplit('-', 1)
    assert revision.isdecimal(), 'non-numeric candidate revision: ' + name
    revisions[name] = {'old_version': version, 'new_version': upstream + '-' + str(int(revision) + 1),
                       'ipk_sha256': packages[name]['ipk_sha256'],
                       'control_sha256': packages[name]['control_sha256'],
                       'adds_source_notices': name in initial}
print(json.dumps({'schema': 1, 'scope': 'actual candidate exact-version dependency edges; alternative branches require solver validation',
                  'package_count': len(packages), 'initial_material_revisions': sorted(initial),
                  'consumer_rounds': rounds, 'total_packages': len(affected),
                  'packages': {name: packages[name] for name in sorted(affected)},
                  'revisions': revisions, 'changes_applied': False}, indent=2))
