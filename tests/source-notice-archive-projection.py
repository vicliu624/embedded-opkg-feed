"""Prepare locked aggregate archive/Wget review material; no runtime rebuild."""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--archives', type=Path, required=True)
parser.add_argument('--decoder', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
descriptor = Path(__file__).with_name('fixtures') / 'archive-notice-review-inputs.json'
inputs = json.loads(descriptor.read_text())
assert inputs['schema'] == 1 and inputs['kind'] == 'tdvp-locked-notice-review-inputs'
assert hashlib.sha256(args.decoder.read_bytes()).hexdigest() == '9351a6fda34ea8a6282d7a42954a2dec20f6cf3d63cf59ebff6c1d6687a26aed', 'review host decoder changed'
output = args.output.resolve()
assert not output.exists() and not output.is_symlink(), 'review output already exists'
planned, records = {}, []
for item in inputs['archives']:
    assert re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', item['package'])
    assert Path(item['file']).name == item['file']
    source = (args.archives / item['file']).read_bytes()
    assert hashlib.sha256(source).hexdigest() == item['sha256'], 'locked archive changed: ' + item['file']
    data = subprocess.check_output([str(args.decoder), '-dc'], input=source) if item['file'].endswith('.lz') else source
    projected = []
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as archive:
        for name in item['members']:
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts
            member = archive.getmember(name)
            assert member.isfile() and 0 < member.size < 1000000
            content = archive.extractfile(member).read()
            relative = 'usr/share/licenses/' + item['package'] + '/' + name
            assert relative not in planned
            planned[relative] = content
            projected.append({'path': relative, 'source_member': name, 'sha256': hashlib.sha256(content).hexdigest()})
    records.append({'package': item['package'], 'archive': item['file'], 'archive_sha256': item['sha256'], 'files': projected})
assert len(planned) == 28 and len(records) == 10
output.mkdir(parents=True)
for relative, content in planned.items():
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as stream:
        stream.write(content)
manifest = {'schema': 1, 'kind': 'tdvp-aggregate-notice-review-material', 'archives': records,
            'descriptor_sha256': hashlib.sha256(descriptor.read_bytes()).hexdigest(),
            'host_decoder_sha256': hashlib.sha256(args.decoder.read_bytes()).hexdigest(),
            'host_decoder_source_sha256': '09418a6d8fb83f5113f5bd856e09703df5d37bae0308c668d0f346e3d3f0a56f',
            'runtime_rebuilt': False, 'historical_build_receipt': False, 'release_authorized': False}
(output / 'notice-source-record.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')
print('Aggregate notice review: PASS 10 locked archives, 28 original files; runtime unchanged and release not authorized')
