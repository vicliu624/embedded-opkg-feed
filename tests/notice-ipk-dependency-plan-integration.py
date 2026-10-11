"""Prove control-derived dependency traversal and duplicate-version rejection."""
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

tool = Path(__file__).with_name('notice-ipk-dependency-plan.py')
initial = 'archive-tools dialog htop libsqlite3-0 libubootenv-0 libzstd nano ncdu rsync tmux wget'.split()
with tempfile.TemporaryDirectory(prefix='tdvp-notice-ipk-plan.') as directory:
    root = Path(directory)
    feed = root / 'feed'
    feed.mkdir()
    fixtures = {name: '' for name in initial}
    fixtures.update({'generated-consumer': 'libzstd (= 1-1)',
                     'transitive-consumer': 'generated-consumer (= 1-1)',
                     'wrong-version': 'libzstd (= 9-1)', 'unbounded': 'libzstd (>= 1-1)'})
    for name, depends in fixtures.items():
        control = root / (name + '.tar.gz')
        with tarfile.open(control, 'w:gz') as archive:
            data = f'Package: {name}\nVersion: 1-1\nDepends: {depends}\nDescription: fixture\n'.encode()
            member = tarfile.TarInfo('./control')
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
        # ar member must have the real control.tar.gz name.
        work = root / name
        work.mkdir()
        renamed = work / 'control.tar.gz'
        renamed.write_bytes(control.read_bytes())
        subprocess.run(['ar', 'rc', str(feed / (name + '.ipk')), str(renamed)], check=True, capture_output=True)
    report = json.loads(subprocess.check_output([sys.executable, str(tool), str(feed)], text=True))
    assert report['package_count'] == 15 and report['total_packages'] == 13
    assert report['consumer_rounds'] == [['generated-consumer'], ['transitive-consumer']]
    assert 'wrong-version' not in report['packages'] and 'unbounded' not in report['packages']
    (feed / 'duplicate.ipk').write_bytes((feed / 'libzstd.ipk').read_bytes())
    result = subprocess.run([sys.executable, str(tool), str(feed)], capture_output=True, text=True)
    assert result.returncode != 0 and 'duplicate package versions' in result.stderr
print('Actual IPK dependency plan: PASS exact-version and transitive edges, constraint boundaries and duplicate rejection')
