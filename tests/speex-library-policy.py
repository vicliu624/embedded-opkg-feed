"""Keep the speech codec distinct from the DSP provider and CPU0-safe."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libspeex'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "PACKAGE='libspeex'" in env and "VERSION='1.2.1-1'" in env
assert "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "PACKAGE_LICENSE_FILES='COPYING'" in env
assert "SOURCE_ARTIFACT_1_SHA256='4b44d4f2b38a370a2d98a78329fefc56a0cf93d1c1be70029217baae6628feea'" in lock
for option in ('--disable-binaries', '--disable-sse', '--disable-arm4-asm',
               '--disable-arm5e-asm', '--disable-blackfin-asm', '--disable-ti-c55x'):
    assert option in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert 'libspeex.so.1|libspeex|1.2.1-1' in owners
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert 'libspeex' in cohort['groups']['audio']
assert 'libspeexdsp-1' in cohort['groups']['audio']
print('Speex policy: PASS locked source, independent codec provider, generic CPU0 implementation')
