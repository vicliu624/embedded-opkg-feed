"""Keep the C/C++ transactional provider and its development projection complete."""
from pathlib import Path
import json
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libdb'
build = (package / 'build.sh').read_text()
metadata = (package / 'package.env').read_text()
assert "VERSION='18.1.40-1'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE EXAMPLES-LICENSE'" in metadata
assert "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libssl-3 libcrypto-3'" in metadata
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
for soname in ('libdb-18.1.so', 'libdb_cxx-18.1.so'):
    assert soname + '|libdb|18.1.40-1' in owners
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-berkeley-database'] == ['libdb']
for option in ('--enable-cxx', '--enable-compat185', '--enable-posixmutexes', '--enable-shared'):
    assert option in build
assert '--disable-replication' not in build
assert '-march=rv64imafdc -mabi=lp64d' in build
assert 'libdb-18.1.so libdb_cxx-18.1.so' in build
assert 'install_include install_lib' in build
assert 'tdvp_assert_direct_archive_elfs' in build
fixture = (repo / 'tests/berkeleydb-transaction-smoke.cpp').read_text()
for operation in ('txn_begin', 'commit', 'abort', 'DB_BTREE', 'reopened.get'):
    assert operation in fixture
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('Berkeley DB provider policy: PASS C/C++ APIs, transactions, source lock and runtime/development separation')
