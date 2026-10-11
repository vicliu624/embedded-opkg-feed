"""Report exact-version consumers that require coordinated notice revisions."""
import json
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
print(json.dumps({'schema': 1, 'scope': 'declared exact runtime dependencies only; excludes generated ELF/image aliases',
                  'initial_material_revisions': sorted(initial), 'consumer_rounds': rounds,
                  'total_recipes': len(affected), 'consumer_count': len(affected - initial),
                  'changes_applied': False}, indent=2))
