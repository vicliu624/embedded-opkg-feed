"""Require full allocator/profiler features and a declared unwind provider."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libgperftools'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='2.18.1-1'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libunwind'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert '--enable-libunwind' in build and 'usr/include/libunwind.h' in build
for flag in ('--enable-minimal', '--disable-cpu-profiler', '--disable-heap-profiler', '--disable-debugalloc'):
    assert flag not in build
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for soname in ('libtcmalloc.so.4', 'libtcmalloc_debug.so.4', 'libtcmalloc_minimal.so.4',
               'libtcmalloc_minimal_debug.so.4', 'libtcmalloc_and_profiler.so.4', 'libprofiler.so.0'):
    assert soname + '|libgperftools|2.18.1-1' in owners
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['common-allocation-profiling'] == ['libgperftools']
consumer = (repo / 'tests/gperftools-runtime-smoke.c').read_text()
for symbol in ('tc_realloc', 'GetHeapProfile', 'ProfilerStart', 'samples_gathered'):
    assert symbol in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('gperftools provider policy: PASS full allocator/profiler features, unwind dependency and ownership')
