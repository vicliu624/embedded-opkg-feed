"""Reject wrong platform identities or tampered predecessor before composition."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('repo', 'image', 'raw', 'previous', 'signature', 'keyring', 'sdk'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('validate-notice-candidate-chain.py')
with tempfile.TemporaryDirectory(prefix='tdvp-chain-rejection.') as directory:
    root = Path(directory)
    for mode in ('image', 'sdk', 'previous'):
        values = dict(vars(args))
        changed = root / mode
        changed.mkdir()
        if mode == 'image':
            path = changed / 'usr/share/tdvp/opkg/image-base.json'
            path.parent.mkdir(parents=True)
            path.write_text('tampered identity')
        elif mode == 'sdk':
            (changed / 'tdvp-sdk-manifest.json').write_text('tampered SDK')
        else:
            (changed / 'Packages').write_bytes((args.previous / 'Packages').read_bytes() + b'tamper')
        values[mode] = changed
        output = root / (mode + '-output')
        command = [sys.executable, str(tool)]
        for key, value in values.items():
            command += ['--' + key, str(value)]
        command += ['--output', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        assert result.returncode != 0
        assert 'AssertionError' in result.stderr or 'CalledProcessError' in result.stderr
        assert not output.exists(), 'partial composition emitted for ' + mode
print('Candidate chain input rejection: PASS image/SDK identity and predecessor signature tamper; no partial output')
