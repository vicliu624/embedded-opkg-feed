"""Project exact locked upstream notice bytes without rebuilding runtime.

This creates review material only, not an IPK, build receipt or legal clearance.
SQLite core preamble is kept distinct from the bundled Tcl-extension terms.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--archives', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
selection = parser.add_mutually_exclusive_group()
selection.add_argument('--terminal', action='store_true', help='Review dialog/htop/ncdu instead of the core three providers')
selection.add_argument('--utilities', action='store_true', help='Review nano/rsync/tmux instead of the core three providers')
args = parser.parse_args()
output = args.output.resolve()
assert not output.exists() and not output.is_symlink(), 'review output already exists'
providers = {
    'libzstd': ('zstd-1.5.7.tar.gz', 'eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3',
                ('zstd-1.5.7/LICENSE', 'zstd-1.5.7/COPYING')),
    'libubootenv-0': ('libubootenv-0.3.5.tar.gz', 'dc27ddcb377e259d898256e90449bc3128437660cacc33dc75f6630d3e52c44e',
                      ('libubootenv-0.3.5/LICENSES/CC0-1.0.txt', 'libubootenv-0.3.5/LICENSES/LGPL-2.1-or-later.txt', 'libubootenv-0.3.5/LICENSES/MIT.txt')),
    'libsqlite3-0': ('sqlite-autoconf-3480000.tar.gz', 'ac992f7fca3989de7ed1fe99c16363f848794c8c32a158dafd4eb927a2e02fd5',
                    ('sqlite-autoconf-3480000/sqlite3.h',)),
}
if args.terminal:
    providers = {
        'dialog': ('dialog-1.3-20220117.tgz', '754cb6bf7dc6a9ac5c1f80c13caa4d976e30a5a6e8b46f17b3bb9b080c31041f',
                   ('dialog-1.3-20220117/COPYING', 'dialog-1.3-20220117/package/debian/copyright')),
        'htop': ('htop-3.3.0.tar.xz', 'a69acf9b42ff592c4861010fce7d8006805f0d6ef0e8ee647a6ee6e59b743d5c', ('htop-3.3.0/COPYING',)),
        'ncdu': ('ncdu-1.21.tar.gz', 'a894d3a9b46bce578a6039bef48f54533ec402fb589b0769bfbb1d1edf9601a6', ('ncdu-1.21/COPYING',)),
    }
if args.utilities:
    providers = {
        'nano': ('nano-8.2.tar.xz', 'd5ad07dd862facae03051c54c6535e54c7ed7407318783fcad1ad2d7076fffeb', ('nano-8.2/COPYING', 'nano-8.2/COPYING.DOC')),
        'rsync': ('rsync-3.4.1.tar.gz', '2924bcb3a1ed8b551fc101f740b9f0fe0a202b115027647cf69850d65fd88c52',
                  ('rsync-3.4.1/COPYING', 'rsync-3.4.1/popt/COPYING')),
        'tmux': ('tmux-3.3a.tar.gz', 'e4fd347843bd0772c4f48d6dde625b0b109b7a380ff15db21e97c11a4dcdf93f', ('tmux-3.3a/COPYING',)),
    }
planned = {}
records = {}
for package, (filename, expected, members) in providers.items():
    source = args.archives / filename
    source_bytes = source.read_bytes()
    assert hashlib.sha256(source_bytes).hexdigest() == expected, 'source archive identity changed'
    files = []
    with tarfile.open(fileobj=io.BytesIO(source_bytes), mode='r:*') as archive:
        for name in members:
            member = archive.getmember(name)
            assert member.isfile() and 0 < member.size < 1000000
            data = archive.extractfile(member).read()
            extraction = 'whole upstream file'
            target = Path(name).name
            if package == 'libsqlite3-0':
                assert data.startswith(b'/*\n') and b'The author disclaims copyright' in data[:300]
                data = data[:data.index(b'*/') + 2]
                extraction = 'exact first header comment; includes core disclaimer, not Tcl-extension terms'
                target = 'COPYRIGHT.sqlite3-header.txt'
            relative = 'usr/share/licenses/' + package + '/' + target
            if relative in planned:
                target = Path(name).parent.name + '-' + target
                relative = 'usr/share/licenses/' + package + '/' + target
            assert relative not in planned
            planned[relative] = data
            files.append({'path': relative, 'source_member': name, 'sha256': hashlib.sha256(data).hexdigest(), 'extraction': extraction})
    records[package] = {'archive': filename, 'archive_sha256': expected, 'files': files}
# Validate every source before creating any output.
output.mkdir(parents=True)
for relative, data in planned.items():
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open('xb') as stream:
        stream.write(data)
manifest = {'schema': 1, 'kind': 'tdvp-source-notice-review-material', 'providers': records,
            'runtime_rebuilt': False, 'historical_build_receipt': False, 'release_authorized': False}
(output / 'notice-source-record.json').write_text(json.dumps(manifest, sort_keys=True, indent=2) + '\n')
print(f'Source notice review: PASS three locked archives, {len(planned)} exact notice projections; runtime unchanged, release not authorized')
