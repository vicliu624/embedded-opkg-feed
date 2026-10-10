"""Require PostgreSQL client features and complete public development headers."""
from pathlib import Path
import json
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libpq'
build = (package / 'build.sh').read_text()
metadata = (package / 'package.env').read_text()
assert "VERSION='18.6-1'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libkrb5 libldap'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert "PACKAGE_LICENSE_FILES='COPYRIGHT'" in metadata
for option in ('--with-ssl=openssl', '--with-gssapi', '--with-ldap', '--disable-rpath'):
    assert option in build
assert 'make -C src/interfaces/libpq' in build
assert 'make -C src/include DESTDIR="$work/install" install' in build
assert '-march=rv64imafdc -mabi=lp64d' in build
assert 'libpq.so.[0-9]*' in build
assert 'libpq.so.5|libpq|18.6-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-sql-database-clients'] == ['libpq']
fixture = (repo / 'tests/libpq-runtime-smoke.c').read_text()
for operation in ('PQconninfoParse', 'PQescapeBytea', 'PQunescapeBytea', 'CONNECTION_BAD'):
    assert operation in fixture
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('libpq provider policy: PASS TLS/GSSAPI/LDAP, headers, source lock, CPU0 and runtime ownership')
