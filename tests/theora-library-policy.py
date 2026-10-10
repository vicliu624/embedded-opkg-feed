"""Verify Theora source lock, codec selection and release-specific ABI owners."""
from pathlib import Path
import json

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libtheora'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='1.2.0-1'" in env and "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libogg-0'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "SOURCE_ARTIFACT_1_SHA256='ebdf77a8f5c0a8f7a9e42323844fa09502b34eb1d1fece7b5f54da41fe2122ec'" in lock
assert '--disable-asm' in build and '--disable-encode' not in build
assert 'libtheora*.so*' in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
for soname in ('libtheora.so.1', 'libtheoradec.so.2', 'libtheoraenc.so.2'):
    assert f'{soname}|libtheora|1.2.0-1' in owners
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert cohort['groups']['vision-theora'] == ['libtheora']
print('Theora policy: PASS official source lock, encoder/decoder, SDK Ogg reuse and actual ABI ownership')
