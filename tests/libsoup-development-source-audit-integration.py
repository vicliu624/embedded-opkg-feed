"""Reject header, generation and runtime changes in isolated development copies."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('archive', 'development', 'sdk', 'ipk'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
command = [sys.executable, str(Path(__file__).with_name('libsoup-development-source-audit.py'))]
for name in ('archive', 'development', 'sdk', 'ipk'):
    command += ['--' + name, str(getattr(args, name))]
result = subprocess.run(command, check=True, capture_output=True, text=True)
report = json.loads(result.stdout.splitlines()[-1])
assert report['headers_verified'] == 42 and report['import_authorized'] is False and report['historical_build_receipt'] is False
with tempfile.TemporaryDirectory(prefix='tdvp-soup-development-negative.') as directory:
    root = Path(directory)
    headers = root / 'usr/include/libsoup-3.0/libsoup'
    shutil.copytree(args.development / 'usr/include/libsoup-3.0/libsoup', headers, symlinks=True)
    libraries = root / 'usr/lib'
    libraries.mkdir(parents=True)
    for path in (args.development / 'usr/lib').glob('libsoup-3.0.so*'):
        shutil.copy2(path, libraries / path.name, follow_symlinks=False)
    cloned = command.copy()
    cloned[cloned.index('--development') + 1] = str(root)
    subprocess.run(cloned, check=True, capture_output=True)
    for name, error in (
        ('soup-message.h', 'public source header changed'),
        ('soup-version.h', 'version generator output differs'),
        ('soup-enum-types.h', 'SDK enum generator output differs'),
        ('soup.h', 'installed umbrella transformation changed'),
    ):
        path = headers / name
        original = path.read_bytes()
        path.write_bytes(original + b'\n/* changed header */\n')
        result = subprocess.run(cloned, capture_output=True, text=True)
        assert result.returncode != 0 and error in result.stderr, 'header change accepted or rejected for unrelated reason'
        path.write_bytes(original)
    extra = headers / 'unreviewed.h'
    extra.write_text('/* unexpected source file */\n')
    result = subprocess.run(cloned, capture_output=True, text=True)
    assert result.returncode != 0 and 'public header set changed' in result.stderr
    extra.unlink()
    library = next(path for path in libraries.glob('libsoup-3.0.so*') if path.is_file() and not path.is_symlink())
    original = library.read_bytes()
    library.write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
    assert subprocess.run(cloned, capture_output=True).returncode != 0, 'runtime byte change accepted'
print('libsoup public development: PASS source/generated headers and runtime; source/version/enum/umbrella/extra/runtime rejection')
