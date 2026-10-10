"""Check opkg-installed authentication providers and target interface consumers."""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('installed_root', type=Path)
parser.add_argument('feed', type=Path)
parser.add_argument('test_directory', type=Path)
parser.add_argument('readelf', type=Path)
args = parser.parse_args()
root, feed, tests, readelf = (p.resolve(strict=True) for p in (args.installed_root, args.feed, args.test_directory, args.readelf))
catalogues = []
for path in (feed / 'Packages', root / 'var/lib/opkg/status'):
    records = {}
    for block in path.read_text().split('\n\n'):
        fields = dict(line.split(': ', 1) for line in block.splitlines() if ': ' in line and not line.startswith((' ', '\t')))
        if 'Package' in fields:
            assert fields['Package'] not in records
            records[fields['Package']] = fields
    catalogues.append(records)
candidate, installed = catalogues
for name, version in (('libkrb5', '1.22.2-1'), ('libtirpc', '1.3.7-1')):
    assert candidate[name].get('X-TDVP-Source-Version', candidate[name]['Version']) == version
    assert candidate[name]['Version'] == installed[name]['Version']
    assert installed[name]['Status'].endswith(' installed')
assert 'libkrb5 (= ' + candidate['libkrb5']['Version'] + ')' in candidate['libtirpc']['Depends']
libraries = ('libgssapi_krb5.so.2', 'libgssrpc.so.4', 'libk5crypto.so.3', 'libkadm5clnt_mit.so.12',
             'libkadm5srv_mit.so.12', 'libkdb5.so.10', 'libkrad.so.0', 'libkrb5.so.3',
             'libkrb5support.so.0', 'libverto.so.0', 'libtirpc.so.3')
for library in libraries:
    path = root / 'usr/lib' / library
    assert path.is_file(), library
    assert not (root / 'usr/lib' / library.split('.so.')[0]).with_suffix('.so').exists(), library
    dynamic = subprocess.check_output([str(readelf), '-d', str(path)], text=True)
    assert '(RPATH)' not in dynamic and '(RUNPATH)' not in dynamic, library
for relative in ('usr/lib/krb5/plugins/kdb/db2.so', 'usr/share/licenses/libkrb5/NOTICE',
                 'usr/share/licenses/libkrb5/README', 'usr/share/licenses/libtirpc/COPYING'):
    assert (root / relative).is_file(), relative
environment = dict(os.environ)
environment.pop('LD_LIBRARY_PATH', None)
environment.pop('QEMU_LD_PREFIX', None)
for name in ('kerberos-runtime-smoke', 'tirpc-gssapi-runtime-smoke'):
    subprocess.run(['qemu-riscv64', '-L', str(root), '-E', 'LD_LIBRARY_PATH=' + str(root / 'usr/lib'),
                    '-E', 'KRB5_CONFIG=/dev/null', str(tests / name)], env=environment, check=True, timeout=30)
print('Installed Kerberos/RPC: PASS versions, dependency, notices, plugins, eleven no-RPATH libraries and target consumers')
