"""Keep TDB transaction/robust locking support and complete notice inputs."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libtdb'
metadata = (package / 'package.env').read_text()
assert "VERSION='1.4.15-1'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE GPL-3.0.txt TDVP-COPYRIGHT-NOTICE'" in metadata
assert 'libtdb.so.1|libtdb|1.4.15-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-transactional-database'] == ['libtdb']
build = (repo / 'support/build-samba-library.sh').read_text()
assert 'libtdb) component=tdb' in build
assert '--disable-tdb-mutex-locking' not in build
assert 'source_root/common/' in build and 'source_root/lib/replace/' in build
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', '-n', str(repo / 'support/build-samba-library.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('TDB provider policy: PASS locked source/notice supplement, runtime owner and preserved mutex configuration')
