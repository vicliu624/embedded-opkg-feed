"""Exercise source-specific notice recognition with real locked review material."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--notices', type=Path, required=True)
args = parser.parse_args()
tool = Path(__file__).with_name('feed-application-notice-inventory.py')
original = {name: (args.notices / name).read_bytes() for name in ('readme.txt', 'readme2d.txt')}
with tempfile.TemporaryDirectory(prefix='tdvp-reviewed-readme.') as directory:
    root = Path(directory)
    for mode in ('original', 'tampered', 'wrong-path', 'wrong-package'):
        feed = root / mode
        feed.mkdir()
        package = 'unrelated' if mode == 'wrong-package' else 'libfft2d'
        control = feed / 'control.tar.gz'
        payload = feed / 'data.tar.gz'
        with tarfile.open(control, 'w:gz') as archive:
            data = f'Package: {package}\nVersion: 1-1\n'.encode()
            member = tarfile.TarInfo('./control')
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
        with tarfile.open(payload, 'w:gz') as archive:
            for name, data in original.items():
                if mode == 'tampered':
                    data += b'changed'
                prefix = 'usr/share/doc/libfft2d/' if mode == 'wrong-path' else 'usr/share/licenses/libfft2d/'
                member = tarfile.TarInfo('./' + prefix + name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        subprocess.run(['ar', 'rc', str(feed / 'fixture.ipk'), str(control), str(payload)],
                       check=True, capture_output=True)
        report = json.loads(subprocess.check_output([sys.executable, str(tool), str(feed)], text=True))
        assert report['package_count'] == 1
        row = report['packages'][0]
        assert row['notice_evidence'] is (mode == 'original'), mode
        assert report['missing_notice_count'] == (0 if mode == 'original' else 1)
        if mode == 'original':
            assert len(row['notice_files']) == 2
print('Reviewed README notice regression: PASS exact source material, tampered bytes, path and package boundaries')
