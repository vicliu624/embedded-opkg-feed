"""Verify TagLib C/C++ delivery, bundled notices and SDK zlib reuse."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libtag'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='2.3.2-1'" in env and "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libz'" in env
assert "PACKAGE_LICENSE_FILES='COPYING.LGPL COPYING.MPL AUTHORS 3rdparty/utfcpp/LICENSE'" in env
assert "SOURCE_ARTIFACT_1_SHA256='3ca2d8afaa7f1cf7f6ed10e511ebc368bfacd6dcaa3dbfa690b89e502e8963dc'" in lock
for option in ('-DBUILD_BINDINGS=ON', '-DBUILD_TESTING=OFF', '-DBUILD_EXAMPLES=OFF', '-DWITH_ZLIB=ON'):
    assert option in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert 'libtag.so.2|libtag|2.3.2-1' in owners
assert 'libtag_c.so.2|libtag|2.3.2-1' in owners
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['multimedia-metadata'] == ['libtag']
print('TagLib policy: PASS locked source, C/C++ ABI, bundled license and SDK development reuse')
