"""Pin the network database reader and keep its source review explicit."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
directory = repo / 'packages/libmaxminddb'
metadata = (directory / 'package.env').read_text()
lock = (directory / 'source.lock').read_text()
assert "VERSION='1.14.1-1'" in metadata
assert "PACKAGE_AUTO_RUNTIME_DEPENDS=1" in metadata
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE'" in metadata
assert 'ca5c87d41339f8bc4daabb53e8a9356b3c995f2d2419b85d7bff823b2ecc252d' in lock
assert "UPSTREAM_VERSION='1.14.1'" in lock
assert 'libmaxminddb.so.0|libmaxminddb|1.14.1-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-network-database'] == ['libmaxminddb']
subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
print('MMDB provider policy: PASS version, locked source, license projection and runtime owner')
