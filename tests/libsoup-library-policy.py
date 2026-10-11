"""Check libsoup source identity and explicit runtime/development closure."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libsoup3'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='3.6.6-1'" in env and "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_DEPENDS='glib-networking'" in env
assert "PACKAGE_BUILD_DEPENDS='libnghttp2 libpsl libsqlite3-0 libbrotli libkrb5'" in env
assert "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libglib-2.0-0 libz'" in env
assert "SOURCE_ARTIFACT_1_SHA256='51ed0ae06f9d5a40f401ff459e2e5f652f9a510b7730e1359ee66d14d4872740'" in lock
for option in ('--wrap-mode=nodownload', '-march=rv64imafdc -mabi=lp64d',
               '-Dbrotli=enabled', '-Dgssapi=enabled', '-Dtls_check=false', '-Dtests=false'):
    assert option in build
assert 'support/elf-runtime-policy.sh' in build
assert 'libsoup-3.0.so.0|libsoup3|3.6.6-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-glib-http'] == ['libsoup3']
print('libsoup policy: PASS source lock, TLS runtime provider, build closure and CPU0 ABI')
