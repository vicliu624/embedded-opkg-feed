"""Project a regular license member from a verified locked source archive."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('archive', type=Path)
parser.add_argument('package', type=Path)
parser.add_argument('payload', type=Path)
parser.add_argument('member')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
assert args.archive.is_file() and not args.archive.is_symlink(), 'unsafe source archive'
archive = args.archive.resolve(strict=True)
package = args.package.resolve(strict=True)
payload = args.payload.resolve(strict=True)
part = PurePosixPath(args.member)
assert not part.is_absolute() and '..' not in part.parts and '\\' not in args.member, 'unsafe source member'
result = subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package), '--emit-artifacts'], check=True, capture_output=True, text=True)
matching = [line.split('\t') for line in result.stdout.splitlines() if len(line.split('\t')) >= 3 and line.split('\t')[1] == archive.name]
assert len(matching) == 1, 'archive absent or ambiguous in source lock'
with archive.open('rb') as stream:
    assert hashlib.file_digest(stream, 'sha256').hexdigest() == matching[0][2], 'source archive hash differs'
with tarfile.open(archive, 'r:*') as source:
    member = source.getmember(args.member)
    assert member.isfile() and 0 < member.size <= 16 * 1024 * 1024, 'license member must be a nonempty regular file'
    content = source.extractfile(member).read()
with tempfile.TemporaryDirectory(prefix='tdvp-archive-license-') as temporary:
    extracted = Path(temporary)
    (extracted / part.name).write_bytes(content)
    subprocess.run(['python3', str(repo / 'support/install-source-licenses.py'), str(extracted), str(package), str(payload), '--license-file', part.name], check=True)
