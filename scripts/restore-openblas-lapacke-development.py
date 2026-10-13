"""Recover the public LAPACKE development subset without rebuilding OpenBLAS.

This is an explicitly recovered artifact, not a producer build receipt and not
the complete OpenBLAS development configuration. Strict builder import is not
enabled for this artifact until its dedicated acceptance path is implemented.
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
assert not output.is_symlink(), 'unsafe output'
assert not output.exists() if args.mode == 'write' else output.is_dir(), 'output state mismatch'
lock = (repo / 'packages/libopenblas/source.lock').read_text()
expected = re.search(r"SOURCE_ARTIFACT_1_SHA256='([0-9a-f]{64})'", lock)[1]
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected, 'source digest mismatch'
assert "UPSTREAM_VERSION='0.3.29'" in lock, 'unsupported source version'
platform = (repo / 'platforms/tdvp-k230-r1/platform.env').read_text()
sdk_hash = re.search(r"SDK_MANIFEST_SHA256='([0-9a-f]{64})'", platform)[1]
assert hashlib.sha256((sdk / 'tdvp-sdk-manifest.json').read_bytes()).hexdigest() == sdk_hash, 'SDK identity mismatch'
files = {}
with tarfile.open(archive, 'r:gz') as source:
    for name in ('lapack.h', 'lapacke.h', 'lapacke_config.h', 'lapacke_mangling.h'):
        member = source.getmember('OpenBLAS-0.3.29/lapack-netlib/LAPACKE/include/' + name)
        assert member.isfile() and 0 < member.size < 5000000
        files['usr/include/' + name] = source.extractfile(member).read()
control_bytes = subprocess.check_output(['ar', 'p', str(ipk), 'control.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(control_bytes), mode='r:gz') as control_tar:
    members = [m for m in control_tar if m.name.lstrip('./') == 'control']
    assert len(members) == 1 and members[0].isfile()
    control = control_tar.extractfile(members[0]).read().decode()
for line in ('Package: libopenblas', 'Version: 0.3.29-1', 'Architecture: riscv64'):
    assert line in control.splitlines(), 'runtime identity mismatch'
data_bytes = subprocess.check_output(['ar', 'p', str(ipk), 'data.tar.gz'])
with tarfile.open(fileobj=io.BytesIO(data_bytes), mode='r:gz') as data_tar:
    members = [m for m in data_tar if m.isfile() and
               re.fullmatch(r'usr/lib/libopenblas[^/]*\.so(?:\.[0-9]+)*', m.name.lstrip('./'))]
    assert len(members) == 1, 'ambiguous runtime'
    member = members[0]
    assert 0 < member.size < 100000000
    runtime = data_tar.extractfile(member).read()
    runtime_name = Path(member.name).name
assert runtime[:6] == b'\x7fELF\x02\x01' and int.from_bytes(runtime[18:20], 'little') == 243, 'not RISC-V ELF64'
assert int.from_bytes(runtime[48:52], 'little') & 6 == 4, 'wrong floating-point ABI'
configs = re.findall(rb'OpenBLAS 0\.3\.29[^\x00]*', runtime)
assert len(configs) == 1 and b'RISCV64_GENERIC' in configs[0] and b'USE64BITINT' not in configs[0], 'unsupported runtime configuration'
files['usr/lib/' + runtime_name] = runtime
files['usr/lib/pkgconfig/lapacke.pc'] = (
    'prefix=/usr\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n\n'
    'Name: LAPACKE\nDescription: Recovered OpenBLAS LP64 LAPACKE interface\n'
    'Version: 0.3.29\nLibs: -L${libdir} -lopenblas\nCflags: -I${includedir}\n').encode()
links = {'usr/lib/' + name: runtime_name for name in ('libopenblas.so', 'libopenblas.so.0') if name != runtime_name}
record = {
    'schema': 1, 'kind': 'tdvp-recovered-openblas-lapacke-development',
    'package': 'libopenblas', 'version': '0.3.29-1', 'subset': 'public-lapacke-lp64',
    'sdk_manifest_sha256': sdk_hash, 'source_archive_sha256': expected,
    'runtime_ipk_sha256': hashlib.sha256(ipk.read_bytes()).hexdigest(),
    'runtime_config': configs[0].decode(), 'runtime_rebuilt': False,
    'recovery_tool_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    'files': {name: hashlib.sha256(content).hexdigest() for name, content in files.items()},
    'links': links,
}
if args.mode == 'write':
    output.mkdir(parents=True)
    for name, content in files.items():
        path = output / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        path.chmod(0o644)
    for name, target in links.items():
        (output / name).symlink_to(target)
    (output / 'tdvp-development-recovery.json').write_text(json.dumps(record, sort_keys=True, indent=2) + '\n')
else:
    provenance = output / 'tdvp-development-recovery.json'
    assert provenance.is_file() and not provenance.is_symlink()
    assert json.loads(provenance.read_text()) == record, 'provenance mismatch'
    for name, content in files.items():
        path = output / name
        assert path.is_file() and not path.is_symlink()
        assert path.read_bytes() == content and path.stat().st_mode & 0o7777 == 0o644, 'file mismatch'
    for name, target in links.items():
        path = output / name
        assert path.is_symlink() and path.readlink().as_posix() == target
        assert path.resolve(strict=True).is_relative_to(output.resolve(strict=True))
    actual = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file() or p.is_symlink()}
    assert actual == set(files) | set(links) | {'tdvp-development-recovery.json'}, 'extra files'
assert not (output / 'tdvp-build-staging-receipt.json').exists(), 'recovery must not forge producer receipt'
print('OpenBLAS LAPACKE recovered development: PASS ' + args.mode)
