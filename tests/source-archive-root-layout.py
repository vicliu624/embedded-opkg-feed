"""Single-root source archives with normal and leading-dot layouts."""
from pathlib import Path
import io
import os
import subprocess
import tarfile
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tdvp-source-root-') as directory:
    work = Path(directory)
    for case, names, expected in (
        ('normal', ['source-1/file.txt'], True),
        ('dot', ['./source-1/file.txt'], True),
        ('repeated-dot', ['././source-1/file.txt'], True),
        ('two-roots', ['first/file.txt', './second/file.txt'], False),
        ('rootless', ['file.txt'], False),
        ('parent', ['../outside/file.txt'], False),
        ('absolute', ['/outside/file.txt'], False),
        ('traversal', ['source-1/../../outside.txt'], False),
    ):
        archive = work / (case + '.tar.gz')
        with tarfile.open(archive, 'w:gz') as output:
            for name in names:
                member = tarfile.TarInfo(name)
                member.size = 7
                output.addfile(member, io.BytesIO(b'fixture'))
        destination = work / case
        destination.mkdir()
        environment = dict(os.environ, FIXTURE_ARCHIVE=str(archive), FIXTURE_DEST=str(destination), FIXTURE_HELPER=str(repo / 'support/source-archive-library.sh'))
        result = subprocess.run(['bash', '-c', 'set -Eeuo pipefail; source "$FIXTURE_HELPER"; tdvp_source_archive_locked_file() { printf "%s\\n" "$FIXTURE_ARCHIVE"; }; tdvp_unpack_locked_source_archive fixture "$FIXTURE_DEST"'], env=environment, text=True, capture_output=True)
        assert (result.returncode == 0) == expected, (case, result.stdout, result.stderr)
        if expected:
            assert (destination / 'source-1/file.txt').read_bytes() == b'fixture'
            assert result.stdout.strip() == str(destination / 'source-1')
        assert not (work / 'outside.txt').exists()
        assert not (work / 'outside').exists()
print('Source archive root layout: PASS plain/dot layouts; multiple roots, rootless, absolute and traversal rejected')
