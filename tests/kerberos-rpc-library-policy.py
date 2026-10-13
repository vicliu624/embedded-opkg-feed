"""Require matched SDK authentication providers without reducing RPC features."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-authentication-rpc'] == ['libkrb5', 'libtirpc']
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for name, version, soname in (('libkrb5', '1.22.2-1', 'libkrb5.so.3'), ('libtirpc', '1.3.7-1', 'libtirpc.so.3')):
    directory = repo / 'packages' / name
    metadata = (directory / 'package.env').read_text()
    assert f"VERSION='{version}'" in metadata
    assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
    assert f'{soname}|{name}|{version}' in owners
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
krb = (repo / 'packages/libkrb5/build.sh').read_text()
assert '--disable-rpath' in krb and '--with-system-et' in krb
assert 'timeout 30 qemu-riscv64' in krb
assert 'sdk-constructor-destructor-smoke' in krb and 'sdk-printf-positional-smoke' in krb
assert "PACKAGE_LICENSE_FILES='NOTICE README'" in (repo / 'packages/libkrb5/package.env').read_text()
rpc = (repo / 'packages/libtirpc/build.sh').read_text()
assert '--enable-gssapi' in rpc and '--disable-gssapi' not in rpc
assert 'krb5-config' in rpc
assert "PACKAGE_BUILD_DEPENDS='libkrb5'" in (repo / 'packages/libtirpc/package.env').read_text()
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in (repo / 'packages/libtirpc/package.env').read_text()
assert 'comerr-dev' in (repo / '.github/actions/published-sdk/action.yml').read_text()
print('Kerberos/RPC policy: PASS source locks, full GSSAPI, target probes, host tools and no-RPATH')
