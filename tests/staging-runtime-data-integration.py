"""Verify real npm payloads and reject data/link drift without changing cache."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('staging', 'sdk', 'runtime-ipk', 'links-ipk'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
tool = repo / 'scripts/verify-staging-runtime-match.py'
with tempfile.TemporaryDirectory(prefix='tdvp-runtime-data-test.') as temporary:
    staging = Path(temporary) / 'staging'
    shutil.copytree(args.staging / 'usr/lib/node_modules', staging / 'usr/lib/node_modules', symlinks=True)
    (staging / 'usr/bin').mkdir()
    for name in ('npm', 'npx', 'corepack'):
        (staging / 'usr/bin' / name).symlink_to((args.staging / 'usr/bin' / name).readlink())
    shutil.copy2(args.staging / 'tdvp-build-staging-receipt.json', staging)
    base = [sys.executable, str(tool), '--staging', str(staging), '--sdk', str(args.sdk), '--include-runtime-data']
    runtime = base + ['--ipk', str(args.runtime_ipk), '--package', 'npm-runtime', '--version', '10.9.8-3']
    links = base + ['--ipk', str(args.links_ipk), '--package', 'npm', '--version', '10.9.8-3']
    subprocess.run(runtime, check=True)
    subprocess.run(links, check=True)
    metadata = staging / 'usr/lib/node_modules/npm/package.json'
    original = metadata.read_bytes()
    metadata.write_bytes(original + b'\nfixture-data-drift\n')
    result = subprocess.run(runtime, capture_output=True, text=True)
    assert result.returncode != 0 and 'development/runtime bytes mismatch' in result.stderr
    metadata.write_bytes(original)
    link = staging / 'usr/bin/npm'
    link.unlink()
    link.symlink_to('../lib/node_modules/npm/bin/npx-cli.js')
    result = subprocess.run(links, capture_output=True, text=True)
    assert result.returncode != 0 and 'runtime link mismatch' in result.stderr
print('Runtime data: PASS 2018 npm files, 3 launch links, data and link drift rejection')
