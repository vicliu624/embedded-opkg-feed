"""Check the explicit HDR runtime/development dependency contract."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libopenexr'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='3.5.2-1'" in metadata
assert "PACKAGE_KIND='shared-library'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libimath libopenjph libdeflate libzstd'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
assert '*-3_5.so.[0-9]*' in build
assert 'FETCHCONTENT_FULLY_DISCONNECTED=ON' in build
for header in ('Imath/half.h', 'openjph/ojph_codestream.h', 'libdeflate.h', 'zstd.h'):
    assert header in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for name in ('Iex', 'IlmThread', 'OpenEXR', 'OpenEXRCore', 'OpenEXRUtil'):
    assert f'lib{name}-3_5.so.34|libopenexr|3.5.2-1' in owners
assert 'libopenexr' in json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['vision-hdr']
consumer = (repo / 'tests/openexr-runtime-smoke.cpp').read_text()
for compression in ('ZIP_COMPRESSION', 'ZSTD_COMPRESSION', 'HTJ2K32_COMPRESSION'):
    assert compression in consumer
assert 'truncate(name, 12)' in consumer and 'bits()' in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('OpenEXR provider policy: PASS five SONAME owners, declared development providers and compression fixture')
