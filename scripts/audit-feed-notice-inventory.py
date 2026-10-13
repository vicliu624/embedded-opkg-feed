"""Inventory legal delivery evidence in every IPK; this is not legal clearance."""
import argparse
import json
from pathlib import Path
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('feed', type=Path)
args = parser.parse_args()
packages = []
for ipk in sorted(args.feed.glob('*.ipk')):
    members = subprocess.check_output(['ar', 't', str(ipk)], text=True).splitlines()
    controls = [name for name in members if name.startswith('control.tar')]
    payloads = [name for name in members if name.startswith('data.tar')]
    if len(controls) != 1 or len(payloads) != 1:
        raise SystemExit(f'Invalid IPK archive members: {ipk}')
    metadata = {}
    notices = []
    sources = []
    for archive, is_control in ((controls[0], True), (payloads[0], False)):
        process = subprocess.Popen(['ar', 'p', str(ipk), archive], stdout=subprocess.PIPE)
        try:
            with tarfile.open(fileobj=process.stdout, mode='r|*') as tar:
                for entry in tar:
                    name = entry.name.removeprefix('./')
                    if is_control and name == 'control':
                        for line in tar.extractfile(entry).read().decode().splitlines():
                            if ': ' in line:
                                key, value = line.split(': ', 1)
                                metadata[key] = value
                    elif not is_control and entry.isfile() and entry.size:
                        lower = name.lower()
                        python_notice = lower.startswith(('usr/lib/python', 'lib/python')) and '/site-packages/' in lower
                        if lower.startswith(('usr/share/licenses/', 'usr/share/doc/')) or python_notice:
                            base = Path(lower).name
                            if base == 'source.json':
                                sources.append(name)
                            elif any(token in base for token in ('license', 'licence', 'copying', 'copyright', 'notice', 'authors')):
                                notices.append(name)
        finally:
            process.stdout.close()
            code = process.wait()
        if code:
            raise SystemExit(f'ar failed for {ipk}: {code}')
    if 'Package' not in metadata or 'Version' not in metadata:
        raise SystemExit(f'Missing package identity: {ipk}')
    packages.append({'package': metadata['Package'], 'version': metadata['Version'],
                     'archive': ipk.name, 'notice_files': sorted(notices),
                     'source_records': sorted(sources),
                     'notice_evidence': bool(notices)})
if not packages:
    raise SystemExit('Feed has no IPKs')
print(json.dumps({'schema': 1, 'scope': 'all IPK payloads; file presence only, not license adequacy',
                  'package_count': len(packages),
                  'missing_notice_count': sum(not row['notice_evidence'] for row in packages),
                  'packages': packages}, indent=2))
