"""Keep modern NIS separate from immutable glibc compatibility symbols."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libnsl-3'
metadata = (package / 'package.env').read_text()
assert "VERSION='2.0.1-1'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libtirpc'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata and 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
assert "'libnsl.so.[0-9]*'" in (package / 'build.sh').read_text()
assert 'libnsl.so.3|libnsl-3|2.0.1-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-nis-compatibility'] == ['libnsl-3']
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('Modern NIS provider policy: PASS source lock, declared RPC staging and parallel ABI owner')
