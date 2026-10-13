"""Reject incomplete/incorrect multi-provider mappings using real cache inputs."""
import argparse
import json
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile

parser = argparse.ArgumentParser()
for name in ('producer-repo', 'sdk', 'staging', 'review', 'runtime-directory'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
command = [sys.executable, str(repo / 'scripts/audit-multi-reviewed-development.py'), '--repo', str(repo)]
for name in ('producer-repo', 'sdk', 'staging', 'review', 'runtime-directory'):
    command += ['--' + name, str(getattr(args, name.replace('-', '_')))]
result = subprocess.run(command, check=True, capture_output=True, text=True)
audit = json.loads(result.stdout)
assert audit['import_authorized'] is False and len(audit['packages']) == 11
original = json.loads(args.review.read_text())
with tempfile.TemporaryDirectory(prefix='tdvp-multi-review-negative.') as temporary:
    path = Path(temporary) / 'review.json'
    negative = command.copy()
    negative[negative.index('--review') + 1] = str(path)
    cases = []
    missing = json.loads(json.dumps(original))
    missing['packages'].pop('libuv')
    cases.append(missing)
    extra = json.loads(json.dumps(original))
    extra['packages']['unreviewed'] = {'producer_version': '1-1', 'consumer_version': '1-1'}
    cases.append(extra)
    wrong_old = json.loads(json.dumps(original))
    wrong_old['packages']['libnode']['producer_version'] = '22.23.2-999'
    cases.append(wrong_old)
    wrong_new = json.loads(json.dumps(original))
    wrong_new['packages']['libnode']['consumer_version'] = '99.0-1'
    cases.append(wrong_new)
    draft = json.loads(json.dumps(original))
    draft['status'] = 'draft-not-importable'
    cases.append(draft)
    wrong_input = json.loads(json.dumps(original))
    wrong_input['consumer_shared_inputs_sha256'] = '0' * 64
    cases.append(wrong_input)
    omitted_difference = json.loads(json.dumps(original))
    omitted_difference['changed_inputs'].pop()
    cases.append(omitted_difference)
    duplicate_difference = json.loads(json.dumps(original))
    duplicate_difference['changed_inputs'].append(duplicate_difference['changed_inputs'][0])
    cases.append(duplicate_difference)
    missing_rationale = json.loads(json.dumps(original))
    missing_rationale['changed_inputs'][0]['rationale'] = '   '
    cases.append(missing_rationale)
    wrong_kind = json.loads(json.dumps(original))
    wrong_kind['kind'] = 'tdvp-multi-package-development-review-draft'
    cases.append(wrong_kind)
    for review in cases:
        path.write_text(json.dumps(review))
        result = subprocess.run(negative, capture_output=True)
        assert result.returncode != 0, 'invalid multi-provider review accepted'
    clone = Path(temporary) / 'consumer'
    for name in ('scripts', 'support'):
        shutil.copytree(repo / name, clone / name, ignore=shutil.ignore_patterns('__pycache__'))
    for name in original['packages']:
        shutil.copytree(repo / 'packages' / name, clone / 'packages' / name,
                        ignore=shutil.ignore_patterns('root', '__pycache__'))
    extra_input_command = command.copy()
    extra_input_command[extra_input_command.index('--repo') + 1] = str(clone)
    for relative in ('src/unreviewed.h', 'patches/unreviewed.patch'):
        extra_input = clone / 'packages/libuv' / relative
        extra_input.parent.mkdir(exist_ok=True)
        extra_input.write_text('unreviewed recipe input\n')
        result = subprocess.run(extra_input_command, capture_output=True)
        assert result.returncode != 0 and b'recipe input set changed' in result.stderr, 'new source/patch accepted or rejected for unrelated reason'
        extra_input.unlink()
print('Multi-provider audit: PASS real closure/runtime and missing/extra/version/draft/input rejection')
