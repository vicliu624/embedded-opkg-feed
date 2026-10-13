"""Check review descriptors against package source locks without executing them."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
descriptor = json.loads((root / 'tests/fixtures/archive-notice-review-inputs.json').read_text())
assert descriptor['schema'] == 1
assert descriptor['kind'] == 'tdvp-locked-notice-review-inputs'
assert len(descriptor['archives']) == 10
seen = set()
for item in descriptor['archives']:
    assert item['package'] in ('archive-tools', 'wget')
    lock = (root / 'packages' / item['package'] / 'source.lock').read_text()
    values = dict(re.findall(r"^([A-Z0-9_]+)='([^'\n]*)'\s*$", lock, re.MULTILINE))
    matches = [key[:-5] for key, value in values.items()
               if key.startswith('SOURCE_ARTIFACT_') and key.endswith('_FILE')
               and value == item['file']]
    assert len(matches) == 1, 'review archive not uniquely source-locked'
    assert values[matches[0] + '_SHA256'] == item['sha256'], 'review digest drift'
    assert (item['package'], item['file']) not in seen
    seen.add((item['package'], item['file']))
    assert item['members'] and len(set(item['members'])) == len(item['members'])
    assert all(not name.startswith('/') and '..' not in name.split('/')
               for name in item['members'])
assert sum(len(item['members']) for item in descriptor['archives']) == 28
print('Archive notice source-lock policy: PASS 10 exact archive identities and 28 safe member paths')
