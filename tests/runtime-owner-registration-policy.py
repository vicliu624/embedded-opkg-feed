#!/usr/bin/env python3
"""Exercise source provider registration and cross-batch import refusal."""
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / 'scripts/register-runtime-owners.py'
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    payload = root / 'payload/usr/lib'
    payload.mkdir(parents=True)
    source = root / 'library.c'
    source.write_text('int fixture(void) { return 1; }\n')
    subprocess.run(['cc', '-shared', '-fPIC', '-Wl,-soname,libfixture.so.1',
                    str(source), '-o', str(payload / 'libfixture.so.1.0')], check=True)
    owner = root / 'owners'
    baseline = 'libbase.so.1|libbase|1.0-1\n'
    owner.write_text(baseline)
    command = [sys.executable, str(script), '--owner-map', str(owner),
               '--payload-root', str(payload.parent.parent), '--readelf', 'readelf']
    registration = ['--package', 'libfixture', '--version', '1.0-1']
    subprocess.run(command + registration, check=True)
    expected = baseline + 'libfixture.so.1|libfixture|1.0-1\n'
    assert owner.read_text() == expected
    subprocess.run(command + registration, check=True)
    assert owner.read_text() == expected
    result = subprocess.run(command + ['--package', 'other', '--version', '1.0-1'],
                            capture_output=True, text=True)
    assert result.returncode != 0 and 'collision' in result.stderr
    assert owner.read_text() == expected
    imported = root / 'imported'
    imported.write_text(expected)
    owner.write_text(baseline)
    result = subprocess.run(command + ['--import-map', str(imported)],
                            capture_output=True, text=True)
    assert result.returncode != 0
    assert owner.read_text() == baseline
    subprocess.run(command + ['--import-map', str(imported),
                              '--allowed-package', 'libfixture=1.0-1'], check=True)
    assert owner.read_text() == expected
    owner.write_text(baseline)
    imported.write_text(expected + 'libmissing.so.1|libfixture|1.0-1\n')
    result = subprocess.run(command + ['--import-map', str(imported),
                                      '--allowed-package', 'libfixture=1.0-1'],
                            capture_output=True, text=True)
    assert result.returncode != 0
    assert owner.read_text() == baseline
print('runtime-owner-registration-policy: PASS')
