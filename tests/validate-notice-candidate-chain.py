"""Validate a fixture-signed candidate chain without changing publication locks."""
import argparse
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

parser = argparse.ArgumentParser()
for name in ('repo', 'image', 'raw', 'previous', 'signature', 'keyring', 'sdk', 'output'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
assert not args.output.exists() and not args.output.is_symlink()
image_digest = '13cab0042c6268976cbf795443559e30eacc671ed7670e5b2568b332b4589794'
assert hashlib.sha256((args.image / 'usr/share/tdvp/opkg/image-base.json').read_bytes()).hexdigest() == image_digest
assert hashlib.sha256((args.sdk / 'tdvp-sdk-manifest.json').read_bytes()).hexdigest() == 'cea9099600fe14fffefb0dae12dc3f81f9593d0e5affaaa603360747c9e45e6f'
verified = subprocess.run(['gpgv', '--status-fd', '1', '--keyring', str(args.keyring),
                           str(args.signature), str(args.previous / 'Packages')],
                          capture_output=True, text=True, check=True)
assert '[GNUPG:] VALIDSIG 043E82E6C978FD06CB39E92DF0D726585DF2C76B ' in verified.stdout
scripts = args.repo / 'scripts'
for feed in (args.raw, args.previous):
    subprocess.run(['bash', str(scripts / 'verify-feed.sh'), '--platform', 'tdvp-k230-r1', str(feed)], check=True)
subprocess.run([sys.executable, str(scripts / 'compose_image_backed_feed.py'), '--source', str(args.raw),
                '--image-root', str(args.image), '--image-manifest-sha256', image_digest,
                '--previous', str(args.previous), '--output', str(args.output)], check=True)
subprocess.run(['bash', str(scripts / 'verify-feed.sh'), '--platform', 'tdvp-k230-r1', str(args.output)], check=True)
subprocess.run([sys.executable, str(scripts / 'verify-declared-dependencies.py'), str(args.output / 'Packages'),
                str(args.image / 'var/lib/opkg/status')], check=True)
for script in ('verify-runtime-closure.sh', 'verify-target-runtime-coverage.sh'):
    subprocess.run(['bash', str(scripts / script), '--platform', 'tdvp-k230-r1',
                    '--base-root', str(args.image), str(args.output)], check=True)
subprocess.run([sys.executable, str(scripts / 'verify-historical-package-continuity.py'),
                '--repo-root', str(args.repo), '--candidate', str(args.output)], check=True)
for ipk in sorted(args.output.glob('*.ipk')):
    with tempfile.TemporaryDirectory(prefix='tdvp-chain-payload.') as directory:
        data = subprocess.check_output(['ar', 'p', str(ipk), 'data.tar.gz'])
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            archive.extractall(directory, filter='data')
        subprocess.run([sys.executable, str(scripts / 'verify-published-sdk-payload.py'),
                        str(args.sdk), directory], check=True)
print('Fixture candidate chain: PASS verified predecessor signature, complete production payload gates; publication lock unchanged')
