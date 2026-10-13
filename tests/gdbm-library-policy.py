"""Require both public GNU DBM interfaces and exact source/runtime identities."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libgdbm'
metadata = (package / 'package.env').read_text()
assert "VERSION='1.26-1'" in metadata
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata and 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
assert "PACKAGE_LICENSE_FILES='COPYING AUTHORS'" in metadata
assert '--enable-libgdbm-compat' in (package / 'build.sh').read_text()
assert "'libgdbm*.so.[0-9]*'" in (package / 'build.sh').read_text()
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for soname in ('libgdbm.so.6', 'libgdbm_compat.so.4'):
    assert f'{soname}|libgdbm|1.26-1' in owners
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-dbm'] == ['libgdbm']
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('GDBM provider policy: PASS locked source, compatibility interface, notices and two runtime SONAMEs')
