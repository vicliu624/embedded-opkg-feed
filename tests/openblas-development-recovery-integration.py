"""Exercise recovery verification and tamper rejection with real locked inputs."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--sdk', required=True)
parser.add_argument('--source-archive', required=True)
parser.add_argument('--runtime-ipk', required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
tool = repo / 'scripts/restore-openblas-lapacke-development.py'
with tempfile.TemporaryDirectory(prefix='tdvp-openblas-recovery-test.') as temporary:
    work = Path(temporary)
    output = work / 'development'
    command = [sys.executable, str(tool), '--repo', str(repo), '--sdk', args.sdk,
               '--source-archive', args.source_archive, '--runtime-ipk', args.runtime_ipk,
               '--output', str(output)]
    subprocess.run(command, check=True)
    subprocess.run(command + ['--mode', 'verify'], check=True)
    provenance = output / 'tdvp-development-recovery.json'
    original_provenance = provenance.read_bytes()
    record = json.loads(original_provenance)
    record['runtime_rebuilt'] = True
    provenance.write_text(json.dumps(record))
    assert subprocess.run(command + ['--mode', 'verify'], capture_output=True).returncode != 0, 'provenance tamper accepted'
    provenance.write_bytes(original_provenance)
    assert subprocess.run(command, capture_output=True).returncode != 0, 'existing output overwritten'
    assert not (output / 'tdvp-build-staging-receipt.json').exists()
    header = output / 'usr/include/lapacke.h'
    original = header.read_bytes()
    header.write_bytes(original + b'\n/* tampered fixture */\n')
    assert subprocess.run(command + ['--mode', 'verify'], capture_output=True).returncode != 0, 'header tamper accepted'
    header.write_bytes(original)
    extra = output / 'usr/include/unrecorded.h'
    extra.write_text('fixture')
    assert subprocess.run(command + ['--mode', 'verify'], capture_output=True).returncode != 0, 'extra file accepted'
    extra.unlink()
    link = output / 'usr/lib/libopenblas.so'
    target = link.readlink()
    link.unlink()
    link.symlink_to('/etc/passwd')
    assert subprocess.run(command + ['--mode', 'verify'], capture_output=True).returncode != 0, 'escaping link accepted'
    link.unlink()
    link.symlink_to(target)
    subprocess.run(command + ['--mode', 'verify'], check=True)
    bad_archive = work / 'bad.tar.gz'
    bad_archive.write_bytes(b'not the locked archive')
    bad = command.copy()
    bad[bad.index('--source-archive') + 1] = str(bad_archive)
    bad[bad.index('--output') + 1] = str(work / 'bad-output')
    assert subprocess.run(bad, capture_output=True).returncode != 0
    assert not (work / 'bad-output').exists(), 'failed input left an output'
    bad_sdk = work / 'sdk'
    bad_sdk.mkdir()
    (bad_sdk / 'tdvp-sdk-manifest.json').write_text('{}')
    bad = command.copy()
    bad[bad.index('--sdk') + 1] = str(bad_sdk)
    bad[bad.index('--output') + 1] = str(work / 'bad-sdk-output')
    assert subprocess.run(bad, capture_output=True).returncode != 0
    assert not (work / 'bad-sdk-output').exists()
    wrong_runtime = Path(args.runtime_ipk).parent / 'libgsl_2.8-1_riscv64.ipk'
    assert wrong_runtime.is_file(), 'real wrong-runtime fixture is required'
    bad = command.copy()
    bad[bad.index('--runtime-ipk') + 1] = str(wrong_runtime)
    bad[bad.index('--output') + 1] = str(work / 'bad-runtime-output')
    assert subprocess.run(bad, capture_output=True).returncode != 0, 'wrong runtime provider accepted'
    assert not (work / 'bad-runtime-output').exists()
print('OpenBLAS recovered development: PASS real inputs, tamper/extra/link/digest/SDK rejection')
