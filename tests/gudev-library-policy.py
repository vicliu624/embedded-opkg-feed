"""Check the reusable GUdev runtime provider and SDK reuse contract."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libgudev'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='238-1'" in env and "PACKAGE_LICENSE_FILES='COPYING'" in env
assert "PACKAGE_BUILD_DEPENDS=''" in env
assert "SOURCE_ARTIFACT_1_SHA256='61266ab1afc9d73dbc60a8b2af73e99d2fdff47d99544d085760e4fa667b5dd1'" in lock
assert 'glib-mkenums' in build and 'glib-genmarshal' in build
for option in ('--wrap-mode=nodownload', '-Dtests=disabled', '-Dintrospection=disabled'):
    assert option in build
assert 'libgudev-1.0.so.0|libgudev|238-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-gobject-device-discovery'] == ['libgudev']
print('GUdev policy: PASS archive identity, SDK reuse, host generator and provider')
