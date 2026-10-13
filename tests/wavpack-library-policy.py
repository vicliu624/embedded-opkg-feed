"""Keep the lossless audio provider reproducible and portable."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libwavpack'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='5.9.0-1'" in env and "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "PACKAGE_LICENSE_FILES='COPYING'" in env
assert "SOURCE_ARTIFACT_1_SHA256='b5291bc4e6d69ebbd3da3800c5bf4a70f19bb92679b23e09b3b612c1e648d1ff'" in lock
for option in ('--disable-apps', '--disable-asm', '--disable-rpath', '--enable-threads', '--enable-dsd', '--enable-legacy'):
    assert option in build
assert 'libwavpack.so.1|libwavpack|5.9.0-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert 'libwavpack' in json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['audio']
print('WavPack policy: PASS release digest, portable codec, license and runtime provider')
