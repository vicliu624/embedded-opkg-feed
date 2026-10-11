"""Require explicit target probes and separate SASL host/target compilation."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libsasl2'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='2.1.28-2'" in metadata
assert 'andrew_cv_runpath_switch=none' in build
assert "-name '*.la' -delete" in build and '"$work/sysroot/usr"' in build
assert 'Private build path retained in SASL runtime' in build
assert "PACKAGE_KIND='runtime'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libkrb5 libgdbm'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert '$package_dir/gssapi-spnego-probe.c' in build
assert 'qemu-riscv64 -L' in build
assert build.index('qemu-riscv64 -L') < build.index('ac_cv_gssapi_supports_spnego=yes')
assert 'make -C include makemd5 CPPFLAGS=' in build
assert '--with-plugindir=/usr/lib/sasl2' in build and '--with-saslauthd=no' in build
assert 'tdvp_assert_elf_without_runtime_search_path' in build
assert 'cp -a "$payload/usr/lib/."' in build
assert 'COPYING' in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for name in ('libsasl2', 'libanonymous', 'libcrammd5', 'libdigestmd5', 'libgs2', 'libgssapiv2', 'libotp', 'libplain', 'libsasldb', 'libscram'):
    assert f'{name}.so.3|libsasl2|2.1.28-2' in owners
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-sasl-authentication'] == ['libsasl2']
consumer = (repo / 'tests/sasl-mechanism-runtime-smoke.c').read_text()
assert 'SCRAM-SHA-256' in consumer and 'GSSAPI' in consumer and 'SASL_CB_GETPATH' in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('SASL provider policy: PASS target probe, isolated native generator, module owners and source locks')
