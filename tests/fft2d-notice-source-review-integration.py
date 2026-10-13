"""Verify exact OouraFFT notices and fail closed on changed review inputs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--archive', type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('fft2d-notice-source-review.py')
with tempfile.TemporaryDirectory(prefix='tdvp-fft2d-notice-test.') as directory:
    root = Path(directory)
    output = root / 'review'
    command = [sys.executable, str(tool), '--archive', str(args.archive), '--output', str(output)]
    subprocess.run(command, check=True)
    manifest = json.loads((output / 'notice-source-record.json').read_text())
    assert manifest['package'] == 'libfft2d' and len(manifest['files']) == 2
    assert all(manifest[key] is False for key in
               ('runtime_rebuilt', 'historical_build_receipt', 'release_authorized'))
    with tarfile.open(fileobj=io.BytesIO(args.archive.read_bytes()), mode='r:gz') as archive:
        for item in manifest['files']:
            actual = (output / item['path']).read_bytes()
            assert actual == archive.extractfile(item['source_member']).read()
            assert hashlib.sha256(actual).hexdigest() == item['sha256']
    before = {path.relative_to(output): path.read_bytes()
              for path in output.rglob('*') if path.is_file()}
    assert subprocess.run(command, capture_output=True).returncode != 0
    assert before == {path.relative_to(output): path.read_bytes()
                      for path in output.rglob('*') if path.is_file()}
    bad = root / 'bad.tar.gz'
    content = args.archive.read_bytes()
    bad.write_bytes(content[:-1] + bytes([content[-1] ^ 1]))
    rejected = root / 'rejected'
    assert subprocess.run([sys.executable, str(tool), '--archive', str(bad),
                           '--output', str(rejected)], capture_output=True).returncode != 0
    assert not rejected.exists()
    link = root / 'output-link'
    link.symlink_to(root / 'missing-target', target_is_directory=True)
    assert subprocess.run([sys.executable, str(tool), '--archive', str(args.archive),
                           '--output', str(link)], capture_output=True).returncode != 0
    assert not (root / 'missing-target').exists()
print('OouraFFT notice regression: PASS exact source bytes, no overwrite, corrupted source and dangling symlink rejection')
