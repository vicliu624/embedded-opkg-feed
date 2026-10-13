"""Require a scalar versioned OpenJPH runtime with separate development files."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libopenjph'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='0.32.0-1'" in metadata
assert "PACKAGE_KIND='shared-library'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE'" in metadata
assert 'libopenjph.so.[0-9]*' in build
for option in ('-DOJPH_BUILD_EXECUTABLES=OFF', '-DOJPH_BUILD_TESTS=OFF', '-DOJPH_DISABLE_SIMD=ON'):
    assert option in build
assert 'libopenjph.so.0.32|libopenjph|0.32.0-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['vision-htj2k'] == ['libopenjph']
consumer = (repo / 'tests/openjph-codec-roundtrip.py').read_text()
assert 'libpthread.so.0' in consumer and 'pixels' in consumer and 'failure.returncode != 0' in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('OpenJPH provider policy: PASS scalar runtime, development separation and codec fixture')
