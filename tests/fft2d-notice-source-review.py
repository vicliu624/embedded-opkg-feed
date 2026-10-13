"""Collect exact locked OouraFFT notices without modifying historical IPKs."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--archive', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
source = args.archive.read_bytes()
digest = hashlib.sha256(source).hexdigest()
assert digest == '5f4dabc2ae21e1f537425d58a49cdca1c49ea11db0d6271e2a4b27e9697548eb'
assert not args.output.exists() and not args.output.is_symlink()
planned = {}
with tarfile.open(fileobj=io.BytesIO(source), mode='r:gz') as archive:
    for name in ('readme.txt', 'readme2d.txt'):
        member = archive.getmember('OouraFFT-1.0/' + name)
        assert member.isfile() and 0 < member.size < 1000000
        planned[name] = archive.extractfile(member).read()
args.output.mkdir(parents=True)
records = []
for name, content in planned.items():
    destination = args.output / 'usr/share/licenses/libfft2d' / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as stream:
        stream.write(content)
    records.append({'source_member': 'OouraFFT-1.0/' + name,
                    'path': destination.relative_to(args.output).as_posix(),
                    'sha256': hashlib.sha256(content).hexdigest()})
manifest = {'schema': 1, 'kind': 'tdvp-source-notice-review-material',
            'package': 'libfft2d', 'archive_sha256': digest, 'files': records,
            'runtime_rebuilt': False, 'historical_build_receipt': False,
            'release_authorized': False}
(args.output / 'notice-source-record.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('OouraFFT source notice review: PASS two original files; historical IPK unchanged')
