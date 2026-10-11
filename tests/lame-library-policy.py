"""Check the independently installable MP3 encoder contract."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libmp3lame'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='4.0-1'" in env
assert "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "PACKAGE_LICENSE_FILES='COPYING'" in env
assert "SOURCE_ARTIFACT_1_SHA256='3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb'" in lock
assert 'no independent upstream checksum or signature verified' in lock
for option in ('--disable-frontend', '--disable-decoder', '--disable-nasm'):
    assert option in build
assert 'libmp3lame.so.0|libmp3lame|4.0-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['audio-mpeg-layer3'] == ['libmp3lame']
print('LAME policy: PASS archive identity, provenance limitation, library-only provider')
