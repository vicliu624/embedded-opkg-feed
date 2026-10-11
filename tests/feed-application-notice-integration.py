"""Prove supplementary notice locations without treating code/empty files as evidence."""
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

repo = Path(__file__).resolve().parents[1]
fixtures = {
    'application': {'usr/share/application/COPYING': 'fixture notice'},
    'node': {'usr/lib/node_modules/example/LICENSE-MIT.txt': 'fixture notice'},
    'code-only': {'usr/lib/node_modules/example/license.js': 'not a notice document', 'usr/share/example/LICENSE': ''},
    'image-alias': {},
    'mixed': {},
    'metadata': {},
    'link': {},
    'prior': {},
}
with tempfile.TemporaryDirectory(prefix='tdvp-application-notices.') as directory:
    root = Path(directory)
    feed = root / 'feed'
    feed.mkdir()
    for package, files in fixtures.items():
        work = root / package
        work.mkdir()
        for archive, contents in (('control.tar.gz', {'control': f'Package: {package}\nVersion: 1-1\n'}), ('data.tar.gz', files)):
            with tarfile.open(work / archive, mode='w:gz') as tar:
                for name, text in contents.items():
                    data = text.encode()
                    member = tarfile.TarInfo('./' + name)
                    member.size = len(data)
                    tar.addfile(member, io.BytesIO(data))
        subprocess.run(['ar', 'rc', str(feed / (package + '.ipk')), str(work / 'control.tar.gz'), str(work / 'data.tar.gz')], check=True, capture_output=True)
    plans = {'code-only': {'plan': {'image_files': {}, 'new_files': {'/x': {'type': 'file'}}}},
             'image-alias': {'plan': {'image_files': {'/x': {}}, 'new_files': {}}},
             'mixed': {'plan': {'image_files': {'/x': {}}, 'new_files': {'/y': {'type': 'file'}}}},
             'metadata': {'plan': {'image_files': {}, 'new_files': {}}},
             'link': {'plan': {'image_files': {}, 'new_files': {'/x': {'type': 'symlink'}}}},
             'prior': {'reused': True}}
    plan = root / 'image-report.json'
    plan.write_text(json.dumps({'packages': plans}))
    result = subprocess.check_output([sys.executable, str(repo / 'tests/feed-application-notice-inventory.py'), str(feed), '--image-report', str(plan)], text=True)
    report = json.loads(result)
    assert report['schema'] == 2 and report['package_count'] == 8 and report['missing_notice_count'] == 6
    assert set(report['additional_notice_files']) == {'application', 'node'}
    categories = report['missing_notice_categories']
    assert categories == {'image_only': ['image-alias'], 'new_payload': ['code-only'], 'mixed': ['mixed'],
                          'metadata_only': ['metadata'], 'link_only': ['link'], 'prior_reuse_unclassified': ['prior']}
print('Application notice inventory: PASS application/Node evidence, code/empty rejection and image/payload/meta/link/prior categories')
