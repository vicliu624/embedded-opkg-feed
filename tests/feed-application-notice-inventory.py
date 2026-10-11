"""Supplement payload notice evidence for application and Node module layouts.

This inventories nonempty files only. It is not license adequacy or clearance.
The shared producer-input inventory script remains unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('feed', type=Path)
parser.add_argument('--image-report', type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
report = json.loads(subprocess.check_output([sys.executable, str(repo / 'scripts/audit-feed-notice-inventory.py'), str(args.feed)], text=True))
added = {}
reviewed_readmes = {
    'libfft2d': {
        'usr/share/licenses/libfft2d/readme.txt': '5b5e610da10394132a42d82ed6501fe1b83a1d19e1bb160c8ace10ed61708765',
        'usr/share/licenses/libfft2d/readme2d.txt': '0b2a2082537735a2a576dbec2e8f9c1a09812eac6df6a389502a6ba860072906',
    },
    'libubootenv-0': {
        'usr/share/licenses/libubootenv-0/CC0-1.0.txt': '0558101984550fa84d1d13c2af11d116c20079d2be58711e8d99cadce7009192',
        'usr/share/licenses/libubootenv-0/LGPL-2.1-or-later.txt': 'dc626520dcd53a22f727af3ee42c770e56c97a64fe3adb063799d8ab032fe551',
        'usr/share/licenses/libubootenv-0/MIT.txt': '89807acf2309bd285f033404ee78581602f3cd9b819a16ac2f0e5f60ff4a473e',
    },
}
for row in report['packages']:
    if row['notice_evidence']:
        continue
    ipk = args.feed / row['archive']
    members = subprocess.check_output(['ar', 't', str(ipk)], text=True).splitlines()
    payload = next(name for name in members if name.startswith('data.tar'))
    process = subprocess.Popen(['ar', 'p', str(ipk), payload], stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=process.stdout, mode='r|*') as archive:
            for entry in archive:
                name = entry.name.removeprefix('./')
                lower = name.lower()
                base = Path(lower).name
                if not entry.isfile() or not entry.size:
                    continue
                expected = reviewed_readmes.get(row['package'], {}).get(name)
                if expected:
                    if entry.size < 1000000 and hashlib.sha256(archive.extractfile(entry).read()).hexdigest() == expected:
                        added.setdefault(row['package'], []).append(name)
                    continue
                if not lower.startswith(('usr/share/', 'usr/lib/node_modules/', 'lib/node_modules/')):
                    continue
                if not re.fullmatch(r'(license|licence|copying|copyright|notice)([._-][a-z0-9]+)*', base):
                    continue
                if Path(base).suffix in ('.js', '.ts', '.py', '.sh', '.c', '.h', '.cpp', '.hpp', '.so', '.png', '.svg'):
                    continue
                added.setdefault(row['package'], []).append(name)
    finally:
        process.stdout.close()
        assert process.wait() == 0
    if row['package'] in added:
        row['notice_files'] = sorted(set(row['notice_files'] + added[row['package']]))
        row['notice_evidence'] = True
report['schema'] = 2
report['scope'] = 'nonempty notice-file presence, including application/Node layouts; not license adequacy or clearance'
report['additional_notice_files'] = added
report['missing_notice_count'] = sum(not row['notice_evidence'] for row in report['packages'])
if args.image_report:
    plans = json.loads(args.image_report.read_text())['packages']
    groups = {'image_only': [], 'new_payload': [], 'mixed': [], 'metadata_only': [], 'link_only': [], 'prior_reuse_unclassified': []}
    for row in report['packages']:
        if row['notice_evidence']:
            continue
        plan = plans[row['package']].get('plan')
        if plan is None:
            category = 'prior_reuse_unclassified'
        else:
            image, new = bool(plan['image_files']), bool(plan['new_files'])
            if not image and not new:
                category = 'metadata_only'
            elif not image and all(record['type'] == 'symlink' for record in plan['new_files'].values()):
                category = 'link_only'
            else:
                category = 'mixed' if image and new else 'image_only' if image else 'new_payload'
        groups[category].append(row['package'])
    report['missing_notice_categories'] = groups
print(json.dumps(report, sort_keys=True, indent=2))
