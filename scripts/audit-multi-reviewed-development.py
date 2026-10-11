"""Audit a complete historical provider closure without importing or relabeling it."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
for name in ('repo', 'producer-repo', 'sdk', 'staging', 'review', 'runtime-directory'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
repo, producer, sdk, staging, review_path, runtime_directory = (p.resolve(strict=True) for p in
    (args.repo, args.producer_repo, args.sdk, args.staging, args.review, args.runtime_directory))
receipt_path = staging / 'tdvp-build-staging-receipt.json'
assert receipt_path.is_file() and not receipt_path.is_symlink()
receipt = json.loads(receipt_path.read_text())
review = json.loads(review_path.read_text())
assert receipt['schema'] == 1 and review['schema'] == 2
assert review['kind'] == 'tdvp-multi-package-development-input-review'
assert review['status'] == 'diff-reviewed-not-import-authorization'
packages = review['packages']
assert packages and sorted(packages) == receipt['packages'], 'review must cover exact producer closure'
sdk_digest = hashlib.sha256((sdk / 'tdvp-sdk-manifest.json').read_bytes()).hexdigest()
assert sdk_digest == receipt['sdk_manifest_sha256'], 'SDK mismatch'
for package, versions in packages.items():
    assert re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', package)
    for root, field in ((producer, 'producer_version'), (repo, 'consumer_version')):
        env = (root / 'packages' / package / 'package.env').read_text()
        assert re.search(r"^VERSION='([^']+)'$", env, re.M)[1] == versions[field], 'package version mapping mismatch'
    assert versions['producer_version'].rsplit('-', 1)[0] == versions['consumer_version'].rsplit('-', 1)[0], 'upstream upgrade needs new development build'
    old_lock = producer / 'packages' / package / 'source.lock'
    new_lock = repo / 'packages' / package / 'source.lock'
    assert old_lock.is_file() and new_lock.is_file() and old_lock.read_bytes() == new_lock.read_bytes(), 'source lock changed'
changes = {}
current_recipe_inputs = set()
for package in packages:
    root = repo / 'packages' / package
    paths = [root / part for part in ('package.env', 'source.lock', 'build.sh') if (root / part).exists()]
    for directory in ('src', 'patches', 'files'):
        if (root / directory).exists():
            paths += list((root / directory).rglob('*'))
    for path in paths:
        if path.is_dir() or path.suffix == '.pyc' or '__pycache__' in path.parts:
            continue
        assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(repo), 'unsafe current recipe input'
        current_recipe_inputs.add(path.relative_to(repo).as_posix())
assert current_recipe_inputs == {name for name in receipt['build_inputs'] if name.startswith('packages/')}, 'recipe input set changed; new source/patch needs separate review'
for name, digest in receipt['build_inputs'].items():
    relative = PurePosixPath(name)
    assert not relative.is_absolute() and '..' not in relative.parts
    old, current = producer / name, repo / name
    assert old.is_file() and not old.is_symlink() and old.resolve().is_relative_to(producer)
    assert current.is_file() and not current.is_symlink() and current.resolve().is_relative_to(repo)
    assert hashlib.sha256(old.read_bytes()).hexdigest() == digest, 'producer input changed'
    current_digest = hashlib.sha256(current.read_bytes()).hexdigest()
    if current_digest != digest:
        changes[name] = (digest, current_digest)
reviewed = {}
for item in review['changed_inputs']:
    name = item['path']
    assert name not in reviewed and item['rationale'].strip()
    if name.startswith('packages/'):
        parts = PurePosixPath(name).parts
        assert len(parts) == 3 and parts[1] in packages and parts[2] in ('package.env', 'build.sh'), 'unreviewable source/header change'
    else:
        assert name.startswith(('scripts/', 'support/'))
    reviewed[name] = (item['producer_sha256'], item['consumer_sha256'])
assert changes == reviewed, 'unreviewed input difference'
shared = {}
paths = list((repo / 'support').rglob('*')) + [p for p in (repo / 'scripts').iterdir() if p.suffix in ('.py', '.sh')]
for path in sorted(set(paths)):
    if path == repo / 'support/ai-common-library-cohort.json' or path.is_dir() or path.suffix == '.pyc' or '__pycache__' in path.parts:
        continue
    assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(repo)
    shared[path.relative_to(repo).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
shared_digest = hashlib.sha256(json.dumps(shared, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
assert shared_digest == review['consumer_shared_inputs_sha256'] and len(shared) == review['consumer_shared_inputs_count'], 'consumer snapshot changed'
for name, record in receipt['development_files'].items():
    relative = PurePosixPath(name)
    assert name.startswith('usr/') and '..' not in relative.parts
    path = staging / name
    if record['type'] == 'symlink':
        assert path.is_symlink() and path.readlink().as_posix() == record['target']
        assert path.resolve(strict=True).is_relative_to(staging)
    else:
        assert record['type'] == 'file' and path.is_file() and not path.is_symlink()
        assert path.stat().st_mode & 0o7777 == record['mode']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], 'development changed'
actual = {p.relative_to(staging).as_posix() for p in (staging / 'usr').rglob('*') if p.is_file() or p.is_symlink()}
assert actual == set(receipt['development_files']), 'extra development paths'
for package, versions in sorted(packages.items()):
    version = versions['consumer_version']
    assert re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.+:~_-]*', version)
    ipk = runtime_directory / (package + '_' + version + '_riscv64.ipk')
    assert ipk.is_file() and not ipk.is_symlink(), 'current runtime IPK absent'
    subprocess.run([sys.executable, str(repo / 'scripts/verify-staging-runtime-match.py'),
                    '--staging', str(staging), '--sdk', str(sdk), '--ipk', str(ipk),
                    '--package', package, '--version', version, '--include-runtime-data'],
                   check=True, stdout=sys.stderr)
print(json.dumps({'kind': 'tdvp-multi-historical-development-diff-audit', 'packages': packages,
                  'producer_inputs_verified': len(receipt['build_inputs']),
                  'development_paths_verified': len(receipt['development_files']),
                  'consumer_shared_inputs_sha256': shared_digest,
                  'producer_receipt_sha256': hashlib.sha256(receipt_path.read_bytes()).hexdigest(),
                  'review_sha256': hashlib.sha256(review_path.read_bytes()).hexdigest(),
                  'import_authorized': False}, sort_keys=True))
