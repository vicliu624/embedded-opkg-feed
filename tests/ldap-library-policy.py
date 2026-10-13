"""Require client features and controlled target-library projection."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libldap'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='2.6.15-2'" in metadata
assert 'libtool-no-runtime-path.patch' in build
path_patch = (package / 'libtool-no-runtime-path.patch').read_text()
assert '+runpath_var=' in path_patch and '+hardcode_libdir_flag_spec=""' in path_patch
assert 'Private build path retained in LDAP runtime' in build
assert "PACKAGE_BUILD_DEPENDS='libsasl2'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert 'pthread-select libc-memcmp' in build and 'qemu-riscv64 -L' in build
assert build.index('qemu-riscv64 -L') < build.index('ac_cv_func_memcmp_working=yes')
for flag in ('--with-tls=openssl', '--with-cyrus-sasl=yes', '--disable-slapd', '--disable-lloadd'):
    assert flag in build
assert 'make -C include DESTDIR=' in build
assert 'libraries/libldap/.libs/libldap.so.[0-9]*' in build
assert 'libraries/liblber/.libs/liblber.so.[0-9]*' in build
assert 'tdvp_assert_direct_archive_elfs' in build
assert 'BR2_COMPILER_PARANOID_UNSAFE_PATH' not in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for name in ('libldap', 'liblber'):
    assert f'{name}.so.2|libldap|2.6.15-2' in owners
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-directory-client'] == ['libldap']
consumer = (repo / 'tests/ldap-ber-runtime-smoke.c').read_text()
assert 'ldaps://' in consumer and 'ldap_str2dn' in consumer and 'ber_scanf' in consumer and 'not-an-ldap-url' in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('LDAP provider policy: PASS target probes, TLS/SASL features, controlled library projection and BER regression')
