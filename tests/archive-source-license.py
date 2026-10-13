"""Exercise archive license projection and fail-closed source/member checks."""
from pathlib import Path
import hashlib
import io
import shutil
import subprocess
import tarfile
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tdvp-archive-license-test-') as temporary:
    work = Path(temporary)
    package = work / 'package'
    shutil.copytree(repo / 'packages/node', package, ignore=shutil.ignore_patterns('root'))
    archive = work / 'node-v22.23.2.tar.gz'
    content = b'Fixture original upstream terms\r\n'
    with tarfile.open(archive, 'w:gz') as source:
        member = tarfile.TarInfo('node-v22.23.2/LICENSE')
        member.size = len(content)
        source.addfile(member, io.BytesIO(content))
        link = tarfile.TarInfo('node-v22.23.2/NOTICE')
        link.type = tarfile.SYMTYPE
        link.linkname = '/outside'
        source.addfile(link)
    original = 'cdaed46fcd8923a55974b7bbc7caaadeaaf7aed60cc137e59837b72f575ef641'
    lock = package / 'source.lock'
    lock.write_text(lock.read_text().replace(original, hashlib.sha256(archive.read_bytes()).hexdigest()))
    payload = work / 'payload'
    payload.mkdir()
    command = ['python3', str(repo / 'support/install-archive-source-license.py'), str(archive), str(package), str(payload)]
    subprocess.run(command + ['node-v22.23.2/LICENSE'], check=True)
    assert (payload / 'usr/share/licenses/node/LICENSE').read_bytes() == content
    assert (payload / 'usr/share/licenses/node/SOURCE.json').is_file()
    subprocess.run(command + ['node-v22.23.2/LICENSE'], check=True)
    for member in ('node-v22.23.2/NOTICE', '../LICENSE', '/LICENSE', 'node-v22.23.2/MISSING'):
        result = subprocess.run(command + [member], capture_output=True)
        assert result.returncode != 0, member
    with archive.open('ab') as stream:
        stream.write(b'tampered')
    result = subprocess.run(command + ['node-v22.23.2/LICENSE'], capture_output=True)
    assert result.returncode != 0
print('Archive source license: PASS original bytes, origin, idempotence, links/path/missing/hash rejection')
