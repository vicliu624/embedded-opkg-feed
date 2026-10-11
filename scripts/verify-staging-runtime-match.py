"""Require reviewed development libraries to match their staged runtime IPK."""
import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--staging', type=Path, required=True)
parser.add_argument('--ipk', type=Path, required=True)
parser.add_argument('--package', required=True)
parser.add_argument('--version', required=True)
args = parser.parse_args()
staging = args.staging.resolve(strict=True)
control_bytes = subprocess.check_output(['ar', 'p', str(args.ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control_bytes), mode='r:gz') as archive:
    members = [m for m in archive if m.name.removeprefix('./') == 'control']
    assert len(members) == 1 and members[0].isfile()
    lines = archive.extractfile(members[0]).read().decode().splitlines()
    for key, value in (('Package', args.package), ('Version', args.version), ('Architecture', 'riscv64')):
        assert [line for line in lines if line.startswith(key + ':')] == [key + ': ' + value], 'runtime identity mismatch'
data_bytes = subprocess.check_output(['ar', 'p', str(args.ipk), 'data.tar.gz'])
verified = []
with tarfile.open(fileobj=io.BytesIO(data_bytes), mode='r:gz') as archive:
    for member in archive:
        name = member.name.removeprefix('./')
        relative = PurePosixPath(name)
        assert not relative.is_absolute() and '..' not in relative.parts, 'unsafe runtime path'
        if not member.isfile() or not name.startswith('usr/lib/') or '.so' not in relative.name:
            continue
        assert name not in verified and 0 < member.size < 1000000000
        runtime = archive.extractfile(member).read()
        assert runtime[:6] == b'\x7fELF\x02\x01' and int.from_bytes(runtime[18:20], 'little') == 243, 'runtime not RISC-V ELF64'
        path = staging / name
        assert path.is_file() and path.resolve(strict=True).is_relative_to(staging), 'runtime absent from development staging'
        assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(runtime).digest(), 'development/runtime bytes mismatch: ' + name
        verified.append(name)
assert verified, 'reviewed runtime provider has no shared libraries'
print('Development/runtime byte match: PASS ' + args.package + ' ' + str(len(verified)) + ' libraries')
