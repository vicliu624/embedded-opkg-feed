"""Exercise no-overwrite and identity rejection against a verified candidate."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('source', 'replacements', 'plan', 'existing-output'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('assemble-notice-candidate.py')
assert args.existing_output.is_dir()
original_record = (args.existing_output / 'notice-revision-assembly.json').read_bytes()
command = [sys.executable, str(tool), '--source', str(args.source),
           '--replacements', str(args.replacements), '--plan', str(args.plan),
           '--output', str(args.existing_output)]
result = subprocess.run(command, capture_output=True, text=True)
assert result.returncode != 0 and 'AssertionError' in result.stderr
assert (args.existing_output / 'notice-revision-assembly.json').read_bytes() == original_record
with tempfile.TemporaryDirectory(prefix='tdvp-notice-assembly-negative.') as directory:
    root = Path(directory)
    for mode in ('source-pin', 'control-pin'):
        plan = json.loads(args.plan.read_text())
        first = next(iter(plan['revisions']))
        field = 'ipk_sha256' if mode == 'source-pin' else 'control_sha256'
        plan['revisions'][first][field] = '0' * 64
        changed = root / (mode + '.json')
        changed.write_text(json.dumps(plan))
        output = root / (mode + '-output')
        result = subprocess.run([sys.executable, str(tool), '--source', str(args.source),
                                 '--replacements', str(args.replacements), '--plan', str(changed),
                                 '--output', str(output)], capture_output=True, text=True)
        assert result.returncode != 0 and 'AssertionError' in result.stderr, mode
        assert not output.exists(), 'partial candidate created for ' + mode
print('Notice candidate assembly rejection: PASS existing-output preservation, source/control identity rejection; no partial candidate')
