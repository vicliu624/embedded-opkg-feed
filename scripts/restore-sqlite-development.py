"""Recover SQLite development files without compiling or replacing its runtime.

This creates an explicitly recovered artifact, not a build-staging receipt.
Strict producer export/import remains responsible for accepting this provenance.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--mode', choices=('write', 'verify'), default='write')
parser.add_argument('--repo', type=Path, required=True)
parser.add_argument('--sdk', type=Path, required=True)
parser.add_argument('--source-archive', type=Path, required=True)
parser.add_argument('--runtime-ipk', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
repo, sdk, archive, ipk = (p.resolve(strict=True) for p in
    (args.repo, args.sdk, args.source_archive, args.runtime_ipk))
output = args.output.absolute()
if args.mode == 'write':
    assert not output.exists() and not output.is_symlink(), 'output already exists'
else:
    assert output.is_dir() and not output.is_symlink(), 'missing recovered output'
lock = (repo / 'packages/libsqlite3-0/source.lock').read_text()
expected = re.search(r"SOURCE_ARTIFACT_1_SHA256='([0-9a-f]{64})'", lock)[1]
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected, 'source digest mismatch'
assert "UPSTREAM_VERSION='3.48.0'" in lock, 'unsupported source version'
sdk_manifest = sdk / 'tdvp-sdk-manifest.json'
platform = (repo / 'platforms/tdvp-k230-r1/platform.env').read_text()
expected_sdk = re.search(r"SDK_MANIFEST_SHA256='([0-9a-f]{64})'", platform)[1]
assert hashlib.sha256(sdk_manifest.read_bytes()).hexdigest() == expected_sdk, 'SDK identity mismatch'
headers = {}
with tarfile.open(archive, 'r:gz') as source:
    for name in ('sqlite3.h', 'sqlite3ext.h'):
        member = source.getmember('sqlite-autoconf-3480000/' + name)
        assert member.isfile() and 0 < member.size < 2000000
        headers[name] = source.extractfile(member).read()
assert re.search(rb'^#define SQLITE_VERSION_NUMBER\s+3048000\s*$', headers['sqlite3.h'], re.M)
control_bytes = subprocess.check_output(['ar', 'p', str(ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control_bytes), mode='r:gz') as control_archive:
    member = next(m for m in control_archive if m.name.lstrip('./') == 'control')
    assert member.isfile()
    control = control_archive.extractfile(member).read().decode()
for line in ('Package: libsqlite3-0', 'Version: 3.48.0-1', 'Architecture: riscv64'):
    assert line in control.splitlines(), 'runtime provider identity mismatch'
data_bytes = subprocess.check_output(['ar', 'p', str(ipk), 'data.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(data_bytes), mode='r:gz') as data_archive:
    libraries = [m for m in data_archive if m.isfile() and
        re.fullmatch(r'usr/lib/libsqlite3\.so\.0(?:\.[0-9]+)*', m.name.lstrip('./'))]
    assert len(libraries) == 1, 'ambiguous runtime library'
    member = libraries[0]
    assert 0 < member.size < 20000000
    runtime = data_archive.extractfile(member).read()
    runtime_name = Path(member.name).name
assert runtime[:6] == b'\x7fELF\x02\x01' and int.from_bytes(runtime[18:20], 'little') == 243, 'not RISC-V ELF64'
assert int.from_bytes(runtime[48:52], 'little') & 6 == 4, 'runtime is not double-float ABI'
files = {'usr/include/' + name: content for name, content in headers.items()}
files['usr/lib/' + runtime_name] = runtime
files['usr/lib/pkgconfig/sqlite3.pc'] = (
    'prefix=/usr\nexec_prefix=${prefix}\nlibdir=${exec_prefix}/lib\nincludedir=${prefix}/include\n\n'
    'Name: SQLite\nDescription: SQL database engine\nVersion: 3.48.0\n'
    'Libs: -L${libdir} -lsqlite3\nCflags: -I${includedir}\n').encode()
links = {name: runtime_name for name in ('libsqlite3.so', 'libsqlite3.so.0') if name != runtime_name}
provenance = {
    'schema': 1, 'kind': 'tdvp-recovered-sqlite-development',
    'package': 'libsqlite3-0', 'version': '3.48.0-1',
    'sdk_manifest_sha256': expected_sdk,
    'recovery_tool_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'source_archive_sha256': expected,
    'runtime_ipk_sha256': hashlib.sha256(ipk.read_bytes()).hexdigest(),
    'runtime_library_sha256': hashlib.sha256(runtime).hexdigest(),
    'files': {name: hashlib.sha256(content).hexdigest() for name, content in files.items()},
    'links': {'usr/lib/' + name: target for name, target in links.items()},
    'runtime_rebuilt': False,
}
if args.mode == 'write':
    output.mkdir(parents=True)
    for name, content in files.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        path.chmod(0o644)
    for name, target in links.items():
        (output / 'usr/lib' / name).symlink_to(target)
    (output / 'tdvp-development-recovery.json').write_text(json.dumps(provenance, sort_keys=True, indent=2) + '\n')
else:
    record = output / 'tdvp-development-recovery.json'
    assert record.is_file() and not record.is_symlink()
    assert json.loads(record.read_text()) == provenance, 'recovery provenance differs'
    for name, content in files.items():
        path = output / name
        assert path.is_file() and not path.is_symlink(), 'unsafe recovered file'
        assert path.read_bytes() == content and path.stat().st_mode & 0o7777 == 0o644, 'recovered file differs'
    for name, target in provenance['links'].items():
        path = output / name
        assert path.is_symlink() and path.readlink().as_posix() == target
        assert path.resolve(strict=True).is_relative_to(output.resolve(strict=True))
    actual = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file() or p.is_symlink()}
    assert actual == set(files) | set(provenance['links']) | {'tdvp-development-recovery.json'}, 'unexpected recovered payload'
print('SQLite development recovery: PASS', args.mode, 'locked source, SDK, runtime IPK and internal linker names; no runtime rebuild')
