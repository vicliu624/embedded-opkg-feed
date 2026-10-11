"""Require complete Boost dependencies and runtime/development separation."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libboost'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='1.82.0-1'" in metadata
assert "PACKAGE_DEPENDS='libpython3.13 (= 3.13.3-2)'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libpython3.13 libicuuc libicui18n libicudata libicuio libbz2 liblzma libzstd'" in metadata
assert "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libz'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert 'env -u CC -u CXX' in build and 'python=3.13' in build
assert '-march=rv64imafdc -mabi=lp64d' in build
assert 'python3.13/pyconfig.h' in build and 'bzlib.h lzma.h zstd.h' in build
assert 'libraries[@]} -ge 38' in build
assert 'libboost_*.so.1.82.0' in build
assert 'cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"' in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
boost = [line for line in owners if '|libboost|' in line]
assert len(boost) == 38 and all(line.endswith('|1.82.0-1') for line in boost)
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['common-boost'] == ['libboost']
compression = (repo / 'tests/boost-compression-runtime-smoke.cpp').read_text()
for codec in ('gzip', 'bzip2', 'lzma', 'zstd'):
    assert codec + '_compressor' in compression and codec + '_decompressor' in compression
assert 'find_package(Boost 1.82.0 EXACT CONFIG' in (repo / 'tests/boost-cmake-development-smoke/CMakeLists.txt').read_text()
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('Boost provider policy: PASS dependencies, native bootstrap isolation, CPU0, 38 owners and development fixtures')
