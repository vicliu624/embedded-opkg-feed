"""Regression for full-feed notice inventory, including malformed archives."""
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

repo = Path(__file__).resolve().parents[1]

def make_ipk(directory, package, files, valid_control=True):
    directory.mkdir()
    for archive, contents in (('control.tar.gz', {'control': f'Package: {package}\nVersion: 1-1\n' if valid_control else 'Description: incomplete\n'}), ('data.tar.gz', files)):
        with tarfile.open(directory / archive, 'w:gz') as tar:
            for name, text in contents.items():
                data = text.encode()
                entry = tarfile.TarInfo('./' + name)
                entry.size = len(data)
                tar.addfile(entry, io.BytesIO(data))
    path = directory.parent / (package + '.ipk')
    subprocess.run(['ar', 'rc', str(path), str(directory / 'control.tar.gz'), str(directory / 'data.tar.gz')], check=True)
    return path

with tempfile.TemporaryDirectory(prefix='tdvp-notice-inventory-') as temporary:
    root = Path(temporary)
    good = root / 'good'
    good.mkdir()
    make_ipk(good / 'native', 'native', {'usr/share/licenses/native/LICENSE': 'BSD text', 'usr/share/licenses/native/SOURCE.json': '{}'})
    make_ipk(good / 'python', 'python', {'usr/lib/python3.13/site-packages/example.dist-info/licenses/LICENSE': 'MIT text'})
    make_ipk(good / 'missing', 'missing', {'usr/share/doc/missing/README': 'documentation', 'usr/share/licenses/missing/COPYING': ''})
    command = ['python3', str(repo / 'scripts/audit-feed-notice-inventory.py')]
    output = subprocess.check_output(command + [str(good)], text=True)
    report = json.loads(output)
    assert report['package_count'] == 3 and report['missing_notice_count'] == 1
    rows = {row['package']: row for row in report['packages']}
    assert rows['native']['source_records'] == ['usr/share/licenses/native/SOURCE.json']
    assert rows['python']['notice_evidence'] and not rows['missing']['notice_evidence']
    empty = root / 'empty'
    empty.mkdir()
    assert subprocess.run(command + [str(empty)], capture_output=True).returncode != 0
    invalid = root / 'invalid'
    invalid.mkdir()
    make_ipk(invalid / 'bad', 'bad', {}, valid_control=False)
    assert subprocess.run(command + [str(invalid)], capture_output=True).returncode != 0
    damaged = root / 'damaged'
    damaged.mkdir()
    (damaged / 'broken.ipk').write_bytes(b'not an ar archive')
    assert subprocess.run(command + [str(damaged)], capture_output=True).returncode != 0
print('Feed notice inventory: PASS native/Python, missing/empty notices, invalid identity and archive rejection')
