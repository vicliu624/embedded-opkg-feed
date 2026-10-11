"""Use the actual target opkg to check immutable candidate version ordering."""
import argparse
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
for name in ('previous', 'candidate', 'image'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
indices = []
for directory in (args.previous, args.candidate):
    entries = {}
    for block in (directory / 'Packages').read_text().split('\n\n'):
        fields = dict(line.split(': ', 1) for line in block.splitlines() if ': ' in line and not line.startswith((' ', '\t')))
        if 'Package' in fields:
            assert fields['Package'] not in entries
            entries[fields['Package']] = fields
    indices.append(entries)
assert indices[0].keys() == indices[1].keys()
changed = 0
for name, previous in indices[0].items():
    candidate = indices[1][name]
    if previous['Version'] == candidate['Version']:
        assert previous['SHA256sum'] == candidate['SHA256sum'], 'same version changed bytes: ' + name
    else:
        result = subprocess.run(['qemu-riscv64', '-L', str(args.image), str(args.image / 'usr/bin/opkg'),
                                 'compare-versions', candidate['Version'], '>>', previous['Version']],
                                capture_output=True, text=True)
        assert result.returncode == 0, (name, previous['Version'], candidate['Version'], result.stderr)
        changed += 1
print('Target opkg monotonicity: PASS', changed, 'changed versions strictly increase;', len(indices[0]) - changed, 'IPKs unchanged')
