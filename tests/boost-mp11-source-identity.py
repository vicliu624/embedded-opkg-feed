"""Compare full Boost source against the existing MP11 development IPK."""
import argparse
import io
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('boost_source', type=Path)
parser.add_argument('mp11_ipk', type=Path)
args = parser.parse_args()
source = args.boost_source.resolve(strict=True)
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['ar', 'p', str(args.mp11_ipk), 'control.tar.gz'])), mode='r:gz') as archive:
    controls = [m for m in archive.getmembers() if PurePosixPath(m.name).as_posix() == 'control']
    assert len(controls) == 1 and controls[0].isfile()
    control = archive.extractfile(controls[0]).read().decode()
    assert 'Package: boost-mp11-dev\n' in control
    assert 'Version: 1.82.0-1\n' in control
    assert 'Architecture: riscv64\n' in control
checked = set()
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['ar', 'p', str(args.mp11_ipk), 'data.tar.gz'])), mode='r:gz') as archive:
    for member in archive.getmembers():
        path = PurePosixPath(member.name)
        assert not path.is_absolute() and '..' not in path.parts
        relative = path.as_posix()
        if not member.isfile() or not relative.startswith('usr/include/boost/mp11'):
            continue
        assert relative not in checked
        target = source / relative.removeprefix('usr/include/')
        assert target.is_file() and not target.is_symlink()
        assert target.read_bytes() == archive.extractfile(member).read(), relative
        checked.add(relative)
assert 'usr/include/boost/mp11.hpp' in checked and len(checked) > 10
print('Boost/MP11 development source identity: PASS', len(checked), 'existing owned headers byte-identical')
