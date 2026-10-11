"""Prove changed candidate inputs are rejected before creating a payload."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('repo', 'ipk', 'notices', 'plan', 'sdk', 'base', 'owners'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('zstd-notice-repack-integration.py')
with tempfile.TemporaryDirectory(prefix='tdvp-notice-repack-negative.') as directory:
    root = Path(directory)
    for mode in ('ipk', 'control-pin', 'revision', 'notice'):
        plan = json.loads(args.plan.read_text())
        ipk = args.ipk
        notices = args.notices
        if mode == 'ipk':
            ipk = root / 'modified.ipk'
            ipk.write_bytes(args.ipk.read_bytes() + b'tamper')
        elif mode == 'control-pin':
            plan['revisions']['libzstd']['control_sha256'] = '0' * 64
        elif mode == 'revision':
            plan['revisions']['libzstd']['new_version'] = '1.5.7-999'
        elif mode == 'notice':
            notices = root / 'modified-notices'
            shutil.copytree(args.notices, notices)
            record = json.loads((notices / 'notice-source-record.json').read_text())
            path = notices / record['providers']['libzstd']['files'][0]['path']
            path.write_bytes(path.read_bytes() + b'tamper')
        plan_path = root / (mode + '.json')
        plan_path.write_text(json.dumps(plan))
        output = root / (mode + '-output')
        command = [sys.executable, str(tool), '--package', 'libzstd', '--repo', str(args.repo),
                   '--ipk', str(ipk), '--notices', str(notices), '--candidate-plan', str(plan_path),
                   '--output', str(output), '--sdk', str(args.sdk), '--base', str(args.base),
                   '--owners', str(args.owners)]
        result = subprocess.run(command, capture_output=True, text=True)
        assert result.returncode != 0 and 'AssertionError' in result.stderr, mode
        assert not output.exists(), 'partial payload created for ' + mode
print('Notice repack input rejection: PASS changed IPK, control pin, revision and notice; no partial payload')
