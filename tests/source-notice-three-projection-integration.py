"""Validate immutable review output and reject modified sources before writing."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--archives', type=Path, required=True)
parser.add_argument('--terminal', action='store_true')
args = parser.parse_args()
tool = Path(__file__).with_name('source-notice-three-projection.py')
with tempfile.TemporaryDirectory(prefix='tdvp-notice-projection-test.') as directory:
    root = Path(directory)
    output = root / 'review'
    command = [sys.executable, str(tool), '--archives', str(args.archives), '--output', str(output)]
    if args.terminal:
        command.append('--terminal')
    subprocess.run(command, check=True)
    manifest = json.loads((output / 'notice-source-record.json').read_text())
    assert manifest['release_authorized'] is False and manifest['historical_build_receipt'] is False and manifest['runtime_rebuilt'] is False
    files = [file for provider in manifest['providers'].values() for file in provider['files']]
    assert len(files) == (4 if args.terminal else 6)
    for file in files:
        assert hashlib.sha256((output / file['path']).read_bytes()).hexdigest() == file['sha256']
    assert subprocess.run(command, capture_output=True).returncode != 0, 'existing review output overwritten'
    archives = root / 'archives'
    archives.mkdir()
    for provider in manifest['providers'].values():
        shutil.copy2(args.archives / provider['archive'], archives / provider['archive'])
    bad = archives / next(iter(manifest['providers'].values()))['archive']
    content = bad.read_bytes()
    bad.write_bytes(content[:-1] + bytes([content[-1] ^ 1]))
    rejected_output = root / 'rejected'
    rejected = [sys.executable, str(tool), '--archives', str(archives), '--output', str(rejected_output)]
    if args.terminal:
        rejected.append('--terminal')
    result = subprocess.run(rejected, capture_output=True, text=True)
    assert result.returncode != 0 and 'source archive identity changed' in result.stderr
    assert not rejected_output.exists(), 'partial review emitted before all source identities passed'
print('Source notice projection: PASS exact output hashes, no-overwrite and source tamper rejection without partial output')
