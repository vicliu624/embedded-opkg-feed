"""Reject invalid public pkg-config records before compiling a consumer."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('archive', 'development', 'sdk', 'ipk', 'root'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
command = [sys.executable, str(Path(__file__).with_name('libsoup-pkgconfig-consumer-integration.py'))]
for name in ('archive', 'development', 'sdk', 'ipk', 'root'):
    command += ['--' + name, str(getattr(args, name))]
with tempfile.TemporaryDirectory(prefix='tdvp-soup-pc-negative.') as directory:
    root = Path(directory)
    shutil.copytree(args.development / 'usr/include/libsoup-3.0', root / 'usr/include/libsoup-3.0', symlinks=True)
    libraries = root / 'usr/lib'
    libraries.mkdir(parents=True)
    for path in (args.development / 'usr/lib').glob('libsoup-3.0.so*'):
        shutil.copy2(path, libraries / path.name, follow_symlinks=False)
    pc = libraries / 'pkgconfig/libsoup-3.0.pc'
    pc.parent.mkdir()
    original = (args.development / 'usr/lib/pkgconfig/libsoup-3.0.pc').read_text()
    command[command.index('--development') + 1] = str(root)
    for changed, error in (
        (original.replace('Version: 3.6.6', 'Version: 3.6.999'), 'public pkg-config version differs'),
        (original.replace('-lsoup-3.0', '-lsoup-other'), 'public linker metadata differs'),
        (original.replace('-I${includedir}/libsoup-3.0', '-I${includedir}/libsoup-other'), 'public include metadata differs'),
        (original + '\nproducer_prefix=/tmp/obsolete\n', 'producer path in public metadata'),
    ):
        pc.write_text(changed)
        result = subprocess.run(command, capture_output=True, text=True)
        assert result.returncode != 0 and error in result.stderr, 'metadata accepted or rejected for unrelated reason'
print('libsoup pkg-config rejection: PASS wrong version/library/include and producer prefix rejection before compilation')
