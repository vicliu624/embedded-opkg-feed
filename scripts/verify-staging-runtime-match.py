"""Require reviewed development libraries to match their staged runtime IPK."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--staging', type=Path, required=True)
parser.add_argument('--ipk', type=Path, required=True)
parser.add_argument('--package', required=True)
parser.add_argument('--version', required=True)
parser.add_argument('--sdk', type=Path, help='Matched SDK for strip-only normalization of a temporary development copy')
parser.add_argument('--include-runtime-data', action='store_true', help='Also verify usr command/data files and links; legal notices are a separate gate')
args = parser.parse_args()
staging = args.staging.resolve(strict=True)
strip_tool = None
if args.sdk is not None:
    sdk = args.sdk.resolve(strict=True)
    receipt_path = staging / 'tdvp-build-staging-receipt.json'
    assert receipt_path.is_file() and not receipt_path.is_symlink(), 'SDK normalization needs staging receipt'
    receipt = json.loads(receipt_path.read_text())
    assert hashlib.sha256((sdk / 'tdvp-sdk-manifest.json').read_bytes()).hexdigest() == receipt['sdk_manifest_sha256'], 'normalization SDK mismatch'
    strip_tool = sdk / 'bin/riscv64-unknown-linux-gnu-strip'
    assert strip_tool.is_file(), 'matched strip tool absent'
control_bytes = subprocess.check_output(['ar', 'p', str(args.ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control_bytes), mode='r:gz') as archive:
    members = [m for m in archive if m.name.removeprefix('./') == 'control']
    assert len(members) == 1 and members[0].isfile()
    lines = archive.extractfile(members[0]).read().decode().splitlines()
    for key, value in (('Package', args.package), ('Version', args.version), ('Architecture', 'riscv64')):
        assert [line for line in lines if line.startswith(key + ':')] == [key + ': ' + value], 'runtime identity mismatch'
data_bytes = subprocess.check_output(['ar', 'p', str(args.ipk), 'data.tar.gz'])
verified = []
normalized = 0
with tarfile.open(fileobj=io.BytesIO(data_bytes), mode='r:gz') as archive:
    for member in archive:
        name = member.name.removeprefix('./')
        relative = PurePosixPath(name)
        assert not relative.is_absolute() and '..' not in relative.parts, 'unsafe runtime path'
        if args.include_runtime_data:
            if not name.startswith('usr/') or name.startswith(('usr/share/licenses/', 'usr/share/doc/')) or member.isdir():
                continue
            assert member.isfile() or member.issym(), 'unsupported runtime object'
            if member.issym():
                path = staging / name
                assert name not in verified and path.is_symlink() and path.readlink().as_posix() == member.linkname, 'runtime link mismatch: ' + name
                assert path.resolve(strict=True).is_relative_to(staging), 'runtime link escapes staging'
                verified.append(name)
                continue
        elif not member.isfile() or not name.startswith('usr/lib/') or '.so' not in relative.name:
            continue
        assert name not in verified and 0 <= member.size < 1000000000
        runtime = archive.extractfile(member).read()
        is_elf = runtime.startswith(b'\x7fELF')
        if is_elf or not args.include_runtime_data:
            assert runtime[:6] == b'\x7fELF\x02\x01' and int.from_bytes(runtime[18:20], 'little') == 243, 'runtime not RISC-V ELF64'
        path = staging / name
        assert path.is_file() and path.resolve(strict=True).is_relative_to(staging), 'runtime absent from development staging'
        development = path.read_bytes()
        target_digest = hashlib.sha256(runtime).digest()
        if hashlib.sha256(development).digest() != target_digest:
            assert is_elf and strip_tool is not None, 'development/runtime bytes mismatch: ' + name
            with tempfile.TemporaryDirectory(prefix='tdvp-runtime-strip-check.') as temporary:
                copy = Path(temporary) / 'library.so'
                copy.write_bytes(development)
                subprocess.run([str(strip_tool), '--strip-unneeded', str(copy)], check=True, capture_output=True)
                assert hashlib.sha256(copy.read_bytes()).digest() == target_digest, 'normalized development/runtime bytes mismatch: ' + name
            normalized += 1
        verified.append(name)
assert verified, 'reviewed runtime provider has no matching payload objects'
print('Development/runtime byte match: PASS ' + args.package + ' ' + str(len(verified)) + ' objects; SDK strip normalization=' + str(normalized))
