"""Check the Imath runtime/development provider contract."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libimath'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='3.2.3-1'" in metadata
assert "PACKAGE_KIND='shared-library'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE.md'" in metadata
assert 'libImath-3_2.so.[0-9]*' in build
for option in ('-DBUILD_TESTING=OFF', '-DPYTHON=OFF', '-DPYBIND11=OFF', '-DBUILD_WEBSITE=OFF'):
    assert option in build
assert 'libImath-3_2.so.30|libimath|3.2.3-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert 'libimath' in json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['vision-hdr']
consumer = (repo / 'tests/imath-runtime-smoke.cpp').read_text()
assert '0x3e00' in consumer and 'cross(b)' in consumer and 'inverse()' in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('Imath provider policy: PASS versioned library, staging contract and geometry regression')
