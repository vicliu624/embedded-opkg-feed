"""Require client runtime plugins and usable public plugin development headers."""
import hashlib
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libmariadb'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='3.4.11-1'" in metadata
assert "PACKAGE_KIND='runtime'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libkrb5 libzstd'" in metadata
assert "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libssl-3 libcrypto-3 libz libcurl-4'" in metadata
for feature in ('-DWITH_SSL=OPENSSL', '-DWITH_EXTERNAL_ZLIB=ON', '-DWITH_CURL=ON', '-DGSSAPI_FLAVOR=MIT'):
    assert feature in build
assert 'DEFAULT_SSL_VERIFY_SERVER_CERT=ON' in build
assert 'cp -a "$plugin_dir/"*.so "$payload/usr/lib/mariadb/plugin/"' in build
assert 'include/ma_compress.h' in build and 'public-compression-header.patch' in build
patch = (package / 'public-compression-header.patch').read_bytes()
assert hashlib.sha256(patch).hexdigest() == '1b33569cc4252deff6f6566a857975436af053ab9f6dda96daca9f2f30c73e9d'
assert b'-#include <ma_sys.h>' in patch and b'+#include <limits.h>' in patch
assert 'libmariadb.so.3|libmariadb|3.4.11-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert 'libmariadb' in json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-sql-database-clients']
fixture = (repo / 'tests/mariadb-runtime-smoke.c').read_text()
assert 'mysql_client_find_plugin' in fixture and 'auth_gssapi_client' in fixture
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('MariaDB provider policy: PASS locked public header fix, runtime plugins, TLS and dependency ownership')
