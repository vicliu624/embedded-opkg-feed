"""Check a real recovered SQLite artifact without building the runtime."""
import argparse
import io
from pathlib import Path
import shutil
import subprocess
import tempfile
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('sdk', type=Path)
parser.add_argument('archive', type=Path)
parser.add_argument('ipk', type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
command = ['python3', str(repo / 'scripts/restore-sqlite-development.py'),
           '--repo', str(repo), '--sdk', str(args.sdk),
           '--source-archive', str(args.archive), '--runtime-ipk', str(args.ipk)]
with tempfile.TemporaryDirectory(prefix='tdvp-sqlite-recovery-test-') as directory:
    root = Path(directory)
    output = root / 'development'
    subprocess.run(command + ['--output', str(output)], check=True)
    verify = command + ['--mode', 'verify', '--output', str(output)]
    subprocess.run(verify, check=True)
    duplicate = subprocess.run(command + ['--output', str(output)], capture_output=True)
    assert duplicate.returncode != 0 and b'output already exists' in duplicate.stderr
    header = output / 'usr/include/sqlite3.h'
    original = header.read_bytes()
    header.write_bytes(original + b'\n/* unexpected change */\n')
    changed = subprocess.run(verify, capture_output=True)
    assert changed.returncode != 0 and b'recovered file differs' in changed.stderr
    header.write_bytes(original)
    subprocess.run(verify, check=True)
    extra = output / 'usr/include/unexpected.h'
    extra.write_text('unexpected')
    assert subprocess.run(verify, capture_output=True).returncode != 0
    extra.unlink()
    bad_source = root / 'changed.tar.gz'
    shutil.copyfile(args.archive, bad_source)
    with bad_source.open('ab') as stream:
        stream.write(b'changed')
    bad_command = command.copy()
    bad_command[bad_command.index('--source-archive') + 1] = str(bad_source)
    rejected = subprocess.run(bad_command + ['--output', str(root / 'rejected')], capture_output=True)
    assert rejected.returncode != 0 and b'source digest mismatch' in rejected.stderr
    assert not (root / 'rejected').exists()
    wrong_sdk = root / 'wrong-sdk'
    wrong_sdk.mkdir()
    (wrong_sdk / 'tdvp-sdk-manifest.json').write_bytes(
        (args.sdk / 'tdvp-sdk-manifest.json').read_bytes() + b'\n')
    bad_command = command.copy()
    bad_command[bad_command.index('--sdk') + 1] = str(wrong_sdk)
    rejected = subprocess.run(bad_command + ['--output', str(root / 'sdk-rejected')], capture_output=True)
    assert rejected.returncode != 0 and b'SDK identity mismatch' in rejected.stderr
    assert not (root / 'sdk-rejected').exists()
    archive = root / 'control.tar.gz'
    control = b'Package: libsqlite3-0\nVersion: 999.0-1\nArchitecture: riscv64\n'
    with tarfile.open(archive, 'w:gz') as fixture:
        member = tarfile.TarInfo('./control')
        member.size = len(control)
        fixture.addfile(member, io.BytesIO(control))
    wrong_ipk = root / 'wrong-provider.ipk'
    subprocess.run(['ar', 'rc', str(wrong_ipk), str(archive)], check=True)
    bad_command = command.copy()
    bad_command[bad_command.index('--runtime-ipk') + 1] = str(wrong_ipk)
    rejected = subprocess.run(bad_command + ['--output', str(root / 'provider-rejected')], capture_output=True)
    assert rejected.returncode != 0 and b'runtime provider identity mismatch' in rejected.stderr
    assert not (root / 'provider-rejected').exists()
    assert not (output / 'tdvp-build-staging-receipt.json').exists()
print('SQLite recovery integration: PASS write/verify, duplicate rejection, changed bytes, extra files, source/SDK/provider identity; no fabricated build receipt')
