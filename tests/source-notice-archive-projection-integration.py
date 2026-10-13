"""Exercise aggregate review material integrity without rebuilding target code."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--archives', type=Path, required=True)
parser.add_argument('--decoder', type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('source-notice-archive-projection.py')
with tempfile.TemporaryDirectory(prefix='tdvp-archive-notice-test.') as directory:
    root = Path(directory)
    output = root / 'review'
    command = [sys.executable, str(tool), '--archives', str(args.archives),
               '--decoder', str(args.decoder), '--output', str(output)]
    subprocess.run(command, check=True)
    manifest = json.loads((output / 'notice-source-record.json').read_text())
    assert all(manifest[key] is False for key in
               ('runtime_rebuilt', 'historical_build_receipt', 'release_authorized'))
    assert len(manifest['archives']) == 10
    files = [item for archive in manifest['archives'] for item in archive['files']]
    assert len(files) == 28 and len({item['path'] for item in files}) == 28
    before = {item['path']: hashlib.sha256((output / item['path']).read_bytes()).hexdigest()
              for item in files}
    assert all(before[item['path']] == item['sha256'] for item in files)
    assert subprocess.run(command, capture_output=True).returncode != 0
    assert all(hashlib.sha256((output / path).read_bytes()).hexdigest() == digest
               for path, digest in before.items()), 'existing output was modified'
    archives = root / 'archives'
    archives.mkdir()
    for archive in manifest['archives']:
        shutil.copy2(args.archives / archive['archive'], archives / archive['archive'])
    # Corrupt the last input: earlier valid inputs must not produce partial output.
    bad = archives / manifest['archives'][-1]['archive']
    content = bad.read_bytes()
    bad.write_bytes(content[:-1] + bytes([content[-1] ^ 1]))
    rejected = root / 'rejected-source'
    result = subprocess.run([sys.executable, str(tool), '--archives', str(archives),
                             '--decoder', str(args.decoder), '--output', str(rejected)],
                            capture_output=True, text=True)
    assert result.returncode != 0 and 'locked archive changed' in result.stderr
    assert not rejected.exists(), 'partial output created for modified source'
    decoder = root / 'modified-decoder'
    shutil.copy2(args.decoder, decoder)
    with decoder.open('ab') as stream:
        stream.write(b'tamper')
    rejected = root / 'rejected-decoder'
    result = subprocess.run([sys.executable, str(tool), '--archives', str(args.archives),
                             '--decoder', str(decoder), '--output', str(rejected)],
                            capture_output=True, text=True)
    assert result.returncode != 0 and 'review host decoder changed' in result.stderr
    assert not rejected.exists(), 'partial output created for modified decoder'
print('Aggregate notice regression: PASS 28 hashes, no overwrite, late-source and decoder tamper rejection')
