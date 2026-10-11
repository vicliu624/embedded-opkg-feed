"""Reject mismatched runtime bytes even when package identity is unchanged."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--staging', type=Path, required=True)
parser.add_argument('--ipk', type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
command = [sys.executable, str(repo / 'scripts/verify-staging-runtime-match.py'),
           '--staging', str(args.staging), '--ipk', str(args.ipk), '--package', 'libdb', '--version', '18.1.40-1']
subprocess.run(command, check=True)
with tempfile.TemporaryDirectory(prefix='tdvp-runtime-match.') as temporary:
    staging = Path(temporary) / 'staging'
    shutil.copytree(args.staging, staging, symlinks=True)
    library = staging / 'usr/lib/libdb-18.1.so'
    library.chmod(0o644)
    original = library.read_bytes()
    library.write_bytes(original + b'fixture-runtime-drift')
    negative = command.copy()
    negative[negative.index('--staging') + 1] = str(staging)
    assert subprocess.run(negative, capture_output=True).returncode != 0, 'runtime drift accepted'
    library.unlink()
    assert subprocess.run(negative, capture_output=True).returncode != 0, 'missing runtime accepted'
    wrong_version = command.copy()
    wrong_version[wrong_version.index('--version') + 1] = '0-invalid'
    assert subprocess.run(wrong_version, capture_output=True).returncode != 0, 'wrong IPK version accepted'
print('Staging/runtime match: PASS real bytes, drift, missing file and wrong identity rejection')
