"""Require signed-source identity and the full SSH library feature selection."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libssh'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
lock = (package / 'source.lock').read_text()
assert "VERSION='0.12.2-1'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libkrb5'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert "PACKAGE_LICENSE_FILES='COPYING BSD AUTHORS'" in metadata
for feature in ('GSSAPI', 'ZLIB', 'SFTP', 'SERVER', 'PCAP', 'SYMBOL_VERSIONING'):
    assert '-DWITH_' + feature + '=ON' in build
assert "'libssh.so.[0-9]*'" in build
assert '88A228D89B07C2C77D0C780903D5DF8CFDD3E8E7' in lock
assert '49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f' in lock
assert 'libssh.so.4|libssh|0.12.2-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['common-ssh-client-server'] == ['libssh']
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('libssh provider policy: PASS source identity, feature selection, licenses and runtime ownership')
