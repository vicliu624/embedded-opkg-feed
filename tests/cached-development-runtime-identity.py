"""Compare a cached development library to its candidate runtime provider."""
import argparse
import hashlib
import io
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('cached_library', type=Path)
parser.add_argument('ipk', type=Path)
parser.add_argument('--package', required=True)
parser.add_argument('--library', required=True)
parser.add_argument('--strip-tool', type=Path)
args = parser.parse_args()
relative = PurePosixPath(args.library)
assert not relative.is_absolute() and '..' not in relative.parts
assert relative.as_posix().startswith('usr/lib/')
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['ar', 'p', str(args.ipk), 'control.tar.gz'])), mode='r:gz') as archive:
    controls = [m for m in archive.getmembers() if PurePosixPath(m.name).as_posix() == 'control']
    assert len(controls) == 1 and controls[0].isfile()
    fields = {}
    for line in archive.extractfile(controls[0]).read().decode().splitlines():
        if ': ' in line and not line.startswith((' ', '\t')):
            key, value = line.split(': ', 1)
            assert key not in fields
            fields[key] = value
    assert fields['Package'] == args.package and fields['Architecture'] == 'riscv64'
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['ar', 'p', str(args.ipk), 'data.tar.gz'])), mode='r:gz') as archive:
    matches = []
    for member in archive.getmembers():
        path = PurePosixPath(member.name)
        assert not path.is_absolute() and '..' not in path.parts
        if path == relative:
            matches.append(member)
    assert len(matches) == 1 and matches[0].isfile()
    expected = archive.extractfile(matches[0]).read()
with tempfile.TemporaryDirectory(prefix='tdvp-development-runtime-identity-') as directory:
    library = Path(directory) / 'library.so'
    shutil.copyfile(args.cached_library.resolve(strict=True), library)
    if args.strip_tool:
        subprocess.run([str(args.strip_tool.resolve(strict=True)), '--strip-unneeded', str(library)], check=True)
    actual = library.read_bytes()
    assert actual == expected, ('cached development/runtime bytes differ', args.package, fields['Version'],
                                hashlib.sha256(actual).hexdigest(), hashlib.sha256(expected).hexdigest())
print('Cached development runtime identity: PASS', args.package, fields['Version'], hashlib.sha256(expected).hexdigest())
