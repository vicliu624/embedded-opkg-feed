"""Audit historical development and pinned input differences, without importing it."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo', type=Path, required=True)
parser.add_argument('--producer-repo', type=Path, required=True)
parser.add_argument('--sdk', type=Path, required=True)
parser.add_argument('--staging', type=Path, required=True)
parser.add_argument('--review', type=Path, required=True)
args = parser.parse_args()
repo, producer, sdk, staging, review_path = (p.resolve(strict=True) for p in
    (args.repo, args.producer_repo, args.sdk, args.staging, args.review))
receipt_path = staging / 'tdvp-build-staging-receipt.json'
assert receipt_path.is_file() and not receipt_path.is_symlink()
receipt = json.loads(receipt_path.read_text())
review = json.loads(review_path.read_text())
assert receipt['schema'] == 1 and review['schema'] == 1
assert review['kind'] == 'tdvp-development-input-diff-review'
assert review['status'] == 'diff-reviewed-not-import-authorization'
assert receipt['packages'] == [review['package']], 'review must cover the entire producer closure'
assert hashlib.sha256((sdk / 'tdvp-sdk-manifest.json').read_bytes()).hexdigest() == receipt['sdk_manifest_sha256'], 'SDK mismatch'
changes = {}
for name, digest in receipt['build_inputs'].items():
    relative = PurePosixPath(name)
    assert not relative.is_absolute() and '..' not in relative.parts and '.' not in relative.parts
    old = producer / name
    current = repo / name
    assert old.is_file() and not old.is_symlink() and old.resolve().is_relative_to(producer)
    assert hashlib.sha256(old.read_bytes()).hexdigest() == digest, 'producer input mismatch: ' + name
    assert current.is_file() and not current.is_symlink() and current.resolve().is_relative_to(repo)
    current_digest = hashlib.sha256(current.read_bytes()).hexdigest()
    if current_digest != digest:
        changes[name] = (digest, current_digest)
reviewed = {}
for item in review['changed_inputs']:
    name = item['path']
    assert name not in reviewed and name.startswith(('scripts/', 'support/')), 'recipe changes require separate review'
    assert item['rationale'].strip()
    reviewed[name] = (item['producer_sha256'], item['consumer_sha256'])
assert changes == reviewed, 'input differences do not match pinned review'
env = (repo / 'packages' / review['package'] / 'package.env').read_text()
assert re.search(r"^VERSION='([^']+)'$", env, re.M)[1] == review['version'], 'consumer package version mismatch'
for name, record in receipt['development_files'].items():
    relative = PurePosixPath(name)
    assert name.startswith('usr/') and not relative.is_absolute() and '..' not in relative.parts
    path = staging / name
    if record['type'] == 'symlink':
        assert path.is_symlink() and path.readlink().as_posix() == record['target'], 'development link mismatch'
        assert path.resolve(strict=True).is_relative_to(staging), 'development link escapes root'
    else:
        assert record['type'] == 'file' and path.is_file() and not path.is_symlink()
        assert path.stat().st_mode & 0o7777 == record['mode'], 'development mode mismatch'
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], 'development bytes mismatch'
actual = {p.relative_to(staging).as_posix() for p in (staging / 'usr').rglob('*') if p.is_file() or p.is_symlink()}
assert actual == set(receipt['development_files']), 'unrecorded development paths'
print(json.dumps({
    'kind': 'tdvp-historical-development-diff-audit', 'package': review['package'],
    'producer_inputs_verified': len(receipt['build_inputs']),
    'development_paths_verified': len(receipt['development_files']),
    'reviewed_changes': sorted(changes),
    'producer_receipt_sha256': hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
    'review_sha256': hashlib.sha256(review_path.read_bytes()).hexdigest(),
    'import_authorized': False,
    'scope': 'Recorded producer inputs and development bytes; new consumer inputs and builder integration are separate gates.'
}, sort_keys=True))
