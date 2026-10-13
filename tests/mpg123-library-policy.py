"""Ensure the MPEG decoder provider uses locked source and generic CPU0 code."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libmpg123'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='1.33.7-1'" in env and "PACKAGE_KIND='shared-library'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "PACKAGE_LICENSE_FILES='COPYING AUTHORS'" in env
assert "SOURCE_ARTIFACT_1_SHA256='31d0e35a4ca567ec9b5ebda6c3062bb4435d6d3eacd6ef0d95cadd7854dc03ee'" in lock
assert 'D021FF8ECF4BE09719D61A27231C4CBC60D5CAFE' in lock
for option in ('--disable-components', '--enable-libmpg123', '--disable-programs',
               '--disable-libout123', '--disable-libout123-modules', '--disable-libsyn123',
               '--disable-modules', '--with-cpu=generic'):
    assert option in build
assert 'libmpg123.so.0|libmpg123|1.33.7-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert 'libmpg123' in json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['audio']
print('mpg123 policy: PASS signed upstream identity, generic decoder, library-only provider')
