"""Validate strip-only normalization and reject changed executable content."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import struct
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('sdk', 'staging', 'ipk'):
    parser.add_argument('--' + name, type=Path, required=True)
for name in ('package', 'version', 'library'):
    parser.add_argument('--' + name, required=True)
args = parser.parse_args()
relative = PurePosixPath(args.library)
assert args.library.startswith('usr/lib/') and '..' not in relative.parts
repo = Path(__file__).resolve().parents[1]
tool = repo / 'scripts/verify-staging-runtime-match.py'
command = [sys.executable, str(tool), '--staging', str(args.staging), '--ipk', str(args.ipk),
           '--package', args.package, '--version', args.version, '--sdk', str(args.sdk)]
original = (args.staging / args.library).read_bytes()
digest = hashlib.sha256(original).hexdigest()
result = subprocess.run(command, check=True, capture_output=True, text=True)
assert 'SDK strip normalization=1' in result.stdout, result.stdout
assert hashlib.sha256((args.staging / args.library).read_bytes()).hexdigest() == digest
with tempfile.TemporaryDirectory(prefix='tdvp-strip-runtime-negative.') as temporary:
    work = Path(temporary)
    staging = work / 'staging'
    library = staging / args.library
    library.parent.mkdir(parents=True)
    library.write_bytes(original)
    shutil.copy2(args.staging / 'tdvp-build-staging-receipt.json', staging)
    data = bytearray(original)
    section_table = struct.unpack_from('<Q', data, 40)[0]
    section_size, section_count = struct.unpack_from('<HH', data, 58)
    changed = False
    for index in range(section_count):
        header = section_table + index * section_size
        kind = struct.unpack_from('<I', data, header + 4)[0]
        flags = struct.unpack_from('<Q', data, header + 8)[0]
        offset, size = struct.unpack_from('<QQ', data, header + 24)
        if kind == 1 and flags & 4 and size:
            data[offset + min(32, size - 1)] ^= 1
            changed = True
            break
    assert changed, 'fixture ELF has no executable section'
    library.write_bytes(data)
    negative = command.copy()
    negative[negative.index('--staging') + 1] = str(staging)
    result = subprocess.run(negative, capture_output=True, text=True)
    assert result.returncode != 0 and 'normalized development/runtime bytes mismatch' in result.stderr, result.stderr
    library.write_bytes(original)
    bad_sdk = work / 'bad-sdk'
    bad_sdk.mkdir()
    (bad_sdk / 'tdvp-sdk-manifest.json').write_text('{}')
    negative[negative.index('--sdk') + 1] = str(bad_sdk)
    result = subprocess.run(negative, capture_output=True, text=True)
    assert result.returncode != 0 and 'normalization SDK mismatch' in result.stderr
print('SDK strip normalization: PASS unstripped provider, original preserved, executable drift and wrong SDK rejected')
