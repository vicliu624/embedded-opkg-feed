"""Verify the MP2 runtime provider and its exact archive identity."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libtwolame'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='0.4.0-1'" in env and "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "PACKAGE_LICENSE_FILES='COPYING AUTHORS'" in env
assert "SOURCE_ARTIFACT_1_SHA256='cc35424f6019a88c6f52570b63e1baf50f62963a3eac52a03a800bb070d7c87d'" in lock
assert '--disable-sndfile' in build
assert 'libtwolame.so.0|libtwolame|0.4.0-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['audio-mpeg-layer2'] == ['libtwolame']
print('TwoLAME policy: PASS archive identity, library-only payload, license and independent provider')
