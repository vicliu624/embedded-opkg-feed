"""Require scalar target JPEG2000 library delivery and codec regression inputs."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libopenjp2'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='2.5.4-1'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE'" in metadata
assert 'libopenjp2.so.[0-9]*' in build and '-DBUILD_SHARED_LIBS=ON' in build
assert 'libopenjp2.so.7|libopenjp2|2.5.4-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['vision-jpeg2000'] == ['libopenjp2']
assert (repo / 'tests/openjpeg-lossless-input.pgm').read_text().startswith('P2\n4 4\n255\n')
codec_test = (repo / 'tests/openjpeg-codec-roundtrip.py').read_text()
assert 'bytes(range(0, 256, 17))' in codec_test
assert 'rejected.returncode != 0' in codec_test and "not (work / 'invalid.pgm').exists()" in codec_test
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('OpenJPEG provider policy: PASS locked source, runtime owner, library payload and codec regressions')
