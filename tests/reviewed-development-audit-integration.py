"""Test pinned producer-difference review against real development inputs."""
import argparse
import json
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('producer-repo', 'sdk', 'staging', 'review'):
    parser.add_argument('--' + name, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
command = [sys.executable, str(repo / 'scripts/audit-reviewed-development.py'), '--repo', str(repo)]
for name in ('producer-repo', 'sdk', 'staging', 'review'):
    command += ['--' + name, getattr(args, name.replace('-', '_'))]
result = subprocess.run(command, check=True, capture_output=True, text=True)
record = json.loads(result.stdout)
assert record['import_authorized'] is False
review = json.loads(Path(args.review).read_text())
with tempfile.TemporaryDirectory(prefix='tdvp-review-negative.') as temporary:
    path = Path(temporary) / 'review.json'
    negative = command.copy()
    negative[negative.index('--review') + 1] = str(path)
    cases = []
    wrong_inventory = json.loads(json.dumps(review))
    wrong_inventory['consumer_shared_inputs_sha256'] = '0' * 64
    cases.append(wrong_inventory)
    missing_inventory = json.loads(json.dumps(review))
    missing_inventory.pop('consumer_shared_inputs_sha256')
    cases.append(missing_inventory)
    changed = json.loads(json.dumps(review))
    changed['changed_inputs'][0]['consumer_sha256'] = '0' * 64
    cases.append(changed)
    missing = json.loads(json.dumps(review))
    missing['changed_inputs'].pop()
    cases.append(missing)
    duplicate = json.loads(json.dumps(review))
    duplicate['changed_inputs'].append(duplicate['changed_inputs'][0])
    cases.append(duplicate)
    wrong_version = json.loads(json.dumps(review))
    wrong_version['version'] = '0-invalid'
    cases.append(wrong_version)
    authorized = json.loads(json.dumps(review))
    authorized['status'] = 'approved-for-import'
    cases.append(authorized)
    for changed in cases:
        path.write_text(json.dumps(changed))
        result = subprocess.run(negative, capture_output=True)
        assert result.returncode != 0, 'invalid review accepted'
    consumer = Path(temporary) / 'consumer'
    shutil.copytree(repo, consumer, symlinks=True)
    (consumer / 'scripts/unreviewed-new-helper.py').write_text('print("unreviewed fixture")\n')
    changed_command = command.copy()
    changed_command[changed_command.index('--repo') + 1] = str(consumer)
    assert subprocess.run(changed_command, capture_output=True).returncode != 0, 'new consumer input accepted'
print('Reviewed development audit: PASS real inputs and hash/missing/duplicate/version/status rejection')
