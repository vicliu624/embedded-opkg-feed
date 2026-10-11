"""Upgrade a copied old candidate with signature checks and runtime byte gates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--prototype-opkg', type=Path)
for name in ('image', 'old-work', 'feed', 'signature', 'output'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
image, old_work, feed = (path.resolve(strict=True) for path in (args.image, args.old_work, args.feed))
opkg = args.prototype_opkg or image / 'usr/bin/opkg'
opkg_digest = hashlib.sha256(opkg.read_bytes()).hexdigest()
if args.prototype_opkg:
    assert opkg_digest == 'd3c93827cb49091edb28b163226c5340b0ce656b119b5deddb57fb65b844a94a', 'unreviewed prototype binary'
assert not args.output.exists() and not args.output.is_symlink()
assert 'option check_signature 1' in (old_work / 'opkg.conf').read_text()
old_root = old_work / 'root'
original_status = hashlib.sha256((old_root / 'var/lib/opkg/status').read_bytes()).hexdigest()
args.output.mkdir(parents=True)
root = args.output / 'root'
shutil.copytree(old_root, root, symlinks=True)
before = {}
for directory in ('usr', 'lib', 'bin', 'sbin', 'etc'):
    for path in (root / directory).rglob('*'):
        if path.is_symlink():
            before[path.relative_to(root).as_posix()] = ('link', os.readlink(path), path.lstat().st_mode)
        elif path.is_file():
            before[path.relative_to(root).as_posix()] = ('file', hashlib.file_digest(path.open('rb'), 'sha256').hexdigest(), path.stat().st_mode)
for suffix in ('', '.asc', '.sig'):
    destination = root / ('var/lib/opkg/lists/fixture' + suffix)
    assert destination.resolve().is_relative_to(root)
    shutil.copy2(feed / 'Packages' if not suffix else args.signature, destination)
config = args.output / 'opkg.conf'
config.write_text('dest root /\noption lists_dir /var/lib/opkg/lists\n'
                  'option info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\n'
                  'option check_signature 1\noption signature_type gpg-asc\n'
                  'option gpg_trust_level TrustAny\noption gpg_dir /fixture-keyring\n'
                  'arch all 1\narch riscv64 100\nsrc fixture ' + feed.as_uri() + '\n')
entries = {}
for block in (feed / 'Packages').read_text().split('\n\n'):
    fields = dict(line.split(': ', 1) for line in block.splitlines() if ': ' in line and not line.startswith((' ', '\t')))
    if 'Package' in fields:
        assert fields['Package'] not in entries
        entries[fields['Package']] = fields['Version']
assert len(entries) == 445
for name in ('cache', 'tmp'):
    (args.output / name).mkdir()
command = ['qemu-riscv64', '-L', str(image), str(opkg), '-f', str(config),
           '-o', str(root), '--cache-dir', str(args.output / 'cache'), '--host-cache-dir', '-t', str(args.output / 'tmp')]
env = dict(os.environ, IPKG_INSTROOT=str(root), PKG_ROOT=str(root))
for label, operation in (('plan', ['--noaction', '--combine', 'upgrade']),
                          ('upgrade', ['--combine', 'upgrade']), ('configure', ['--force-postinstall', 'configure'])):
    result = subprocess.run(command + operation, env=env, capture_output=True, text=True, timeout=1200)
    (args.output / (label + '.log')).write_text(result.stdout + result.stderr)
    assert result.returncode == 0, (label, (result.stdout + result.stderr)[-6000:])
    if label == 'plan':
        assert hashlib.sha256((root / 'var/lib/opkg/status').read_bytes()).hexdigest() == original_status
installed = {}
for block in (root / 'var/lib/opkg/status').read_text().split('\n\n'):
    fields = dict(line.split(': ', 1) for line in block.splitlines() if ': ' in line and not line.startswith((' ', '\t')))
    if fields.get('Status', '').endswith(' installed'):
        installed[fields['Package']] = fields['Version']
assert all(installed.get(name) == version for name, version in entries.items())
for relative, previous in before.items():
    path = root / relative
    assert path.exists() or path.is_symlink(), 'existing runtime removed: ' + relative
    current = ('link', os.readlink(path), path.lstat().st_mode) if path.is_symlink() else (
        'file', hashlib.file_digest(path.open('rb'), 'sha256').hexdigest(), path.stat().st_mode)
    assert current == previous, 'existing runtime changed: ' + relative
after_paths = {path.relative_to(root).as_posix() for directory in ('usr', 'lib', 'bin', 'sbin', 'etc')
               for path in (root / directory).rglob('*') if path.is_symlink() or path.is_file()}
added = after_paths - before.keys()
assert len(added) == 43 and all(path.startswith('usr/share/licenses/') for path in added), 'unexpected new runtime paths'
assert hashlib.sha256((old_root / 'var/lib/opkg/status').read_bytes()).hexdigest() == original_status
(args.output / 'acceptance.json').write_text(json.dumps({'schema': 1, 'candidate_packages': len(entries),
    'installed_packages': len(installed), 'protected_existing_paths': len(before),
    'signature_enabled': True, 'old_root_unchanged': True, 'device_test': False,
    'prototype_opkg': bool(args.prototype_opkg), 'opkg_sha256': opkg_digest}, indent=2) + '\n')
print('Target opkg upgrade: PASS 445 candidate versions,', len(before), 'existing runtime paths unchanged; old root preserved; prototype=', bool(args.prototype_opkg))
