"""Require locked standalone allocator/events providers and full license notices."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-memory-events'] == ['libtalloc', 'libtevent']
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for name, version, soname in (('libtalloc', '2.5.0-1', 'libtalloc.so.2'), ('libtevent', '0.17.2-1', 'libtevent.so.0')):
    directory = repo / 'packages' / name
    metadata = (directory / 'package.env').read_text()
    assert f"VERSION='{version}'" in metadata
    assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert "PACKAGE_LICENSE_FILES='LICENSE GPL-3.0.txt TDVP-COPYRIGHT-NOTICE'" in metadata
    assert f'{soname}|{name}|{version}' in owners
    assert '3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986' in (directory / 'source.lock').read_text()
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
assert "PACKAGE_BUILD_DEPENDS='libtalloc'" in (repo / 'packages/libtevent/package.env').read_text()
build = (repo / 'support/build-samba-library.sh').read_text()
for required in ('--bundled-libraries=', '--cross-execute=', '--with-libiconv=', 'PKGCONFIG=/usr/bin/pkg-config',
                 'PKG_CONFIG_LIBDIR=', '--disable-rpath-install', 'extract-source-copyright-notices.py'):
    assert required in build, required
subprocess.run(['bash', '-n', str(repo / 'support/build-samba-library.sh')], check=True)
print('Talloc/tevent provider policy: PASS dependencies, locked source/license texts, cross probes and target pkg-config')
