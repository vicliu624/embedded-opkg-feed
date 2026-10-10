"""Keep BSD compatibility providers locked and separate runtime/development files."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
contract = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert contract['groups']['common-portability'] == ['libmd', 'libbsd']
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for name, version in (('libmd', '1.2.0-2'), ('libbsd', '0.12.2-1')):
    directory = repo / 'packages' / name
    metadata = (directory / 'package.env').read_text()
    assert f"VERSION='{version}'" in metadata
    assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert "PACKAGE_AUTO_RUNTIME_DEPENDS=1" in metadata
    assert "PACKAGE_LICENSE_FILES='COPYING'" in metadata
    assert f'{name}.so.0|{name}|{version}' in owners
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
bsd = (repo / 'packages/libbsd/package.env').read_text()
assert "PACKAGE_BUILD_DEPENDS='libmd'" in bsd
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in bsd
assert "'libbsd.so.[0-9]*'" in (repo / 'packages/libbsd/build.sh').read_text()
assert "'libmd.so.[0-9]*'" in (repo / 'packages/libmd/build.sh').read_text()
print('BSD provider policy: PASS locked sources, development dependency and runtime-only ELF selection')
