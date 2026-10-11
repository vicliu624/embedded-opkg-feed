"""Reject changed pins, unreviewed prototype bytes and added source files."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('archive', 'image-patches', 'batch-patch', 'prototype'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('audit-opkg-upgrade-prototype-source.py')
with tempfile.TemporaryDirectory(prefix='tdvp-opkg-source-rejection.') as directory:
    root = Path(directory)
    for mode in ('archive', 'batch_patch', 'prototype', 'file-set'):
        values = dict(vars(args))
        if mode in ('archive', 'batch_patch'):
            changed = root / mode
            changed.write_bytes(values[mode].read_bytes() + b'tamper')
            values[mode] = changed
        else:
            changed = root / mode
            shutil.copytree(args.prototype, changed, symlinks=True)
            if mode == 'prototype':
                path = changed / 'libopkg/solvers/internal/opkg_upgrade_internal.c'
                path.write_bytes(path.read_bytes() + b'\n/* unreviewed bytes */\n')
            else:
                (changed / 'unreviewed.c').write_text('/* unreviewed source file */\n')
            values['prototype'] = changed
        command = [sys.executable, str(tool)]
        for key, value in values.items():
            command += ['--' + key.replace('_', '-'), str(value)]
        result = subprocess.run(command, capture_output=True, text=True)
        assert result.returncode != 0 and 'AssertionError' in result.stderr, (mode, result.stderr[-800:])
        assert 'tdvp-opkg-prototype-source-review' not in result.stdout
print('Opkg prototype source rejection: PASS archive/patch pin tamper, changed source bytes and added source file')
