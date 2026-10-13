"""Report exact-version consumers that require coordinated notice revisions."""
import json
import hashlib
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
recipes = {}
for path in (root / 'packages').glob('*/package.env'):
    recipes[path.parent.name] = dict(re.findall(r"^([A-Z0-9_]+)='([^']*)'", path.read_text(), re.M))
initial = set('archive-tools dialog htop libsqlite3-0 libubootenv-0 libzstd nano ncdu rsync tmux wget'.split())
assert initial <= recipes.keys()
affected = set(initial)
rounds = []
while True:
    added = {name for name, values in recipes.items() if name not in affected
             and any(dependency in affected for dependency in
                     re.findall(r'([a-z0-9+.-]+) \(= [^)]+\)', values.get('PACKAGE_DEPENDS', '')))}
    if not added:
        break
    rounds.append(sorted(added))
    affected.update(added)
revisions = {}
for name in sorted(affected):
    old_version = recipes[name]['VERSION']
    upstream, revision = old_version.rsplit('-', 1)
    assert revision.isdecimal(), 'non-numeric package revision: ' + name
    revisions[name] = {'old_version': old_version,
                       'new_version': upstream + '-' + str(int(revision) + 1),
                       'package_env_sha256': hashlib.sha256((root / 'packages' / name / 'package.env').read_bytes()).hexdigest(),
                       'adds_source_notices': name in initial}
print(json.dumps({'schema': 1, 'scope': 'declared exact runtime dependencies only; excludes generated ELF/image aliases',
                  'initial_material_revisions': sorted(initial), 'consumer_rounds': rounds,
                  'total_recipes': len(affected), 'consumer_count': len(affected - initial),
                  'revisions': revisions, 'changes_applied': False}, indent=2))
