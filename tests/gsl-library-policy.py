"""Check GNU GSL runtime identity independently of Microsoft GSL headers."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libgsl'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
assert "VERSION='2.8-1'" in env and "PACKAGE_LICENSE_FILES='COPYING'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "UPSTREAM_LICENSE='GPL-3.0-or-later'" in lock
assert "SOURCE_ARTIFACT_1_SHA256='6a99eeed15632c6354895b1dd542ed5a855c0f15d9ad1326c6fe2b2c9e423190'" in lock
assert '245FB74BAE05B3E9' in lock
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
for soname in ('libgsl.so.28', 'libgslcblas.so.0'):
    assert soname + '|libgsl|2.8-1' in owners
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['scientific-numerical-algorithms'] == ['libgsl']
print('GNU GSL policy: PASS archive, GPL license, scientific and CBLAS providers')
