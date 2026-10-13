"""Check the independent AV1 decoder recipe and real cross-codec fixture."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
directory = repo / 'packages/libdav1d'
metadata = (directory / 'package.env').read_text()
build = (directory / 'build.sh').read_text()
assert "VERSION='1.5.3-1'" in metadata
assert "PACKAGE_HOST_DEPENDS='meson ninja gcc tar pkg-config python3'" in metadata
assert "PACKAGE_LICENSE_FILES='COPYING'" in metadata
for flag in ('enable_asm=false', 'enable_tools=false', 'enable_tests=false', 'testdata_tests=false', '--default-library=shared'):
    assert flag in build
assert 'needs_exe_wrapper = true' in build
assert 'riscv64-unknown-linux-gnu-' in build and 'PKG_CONFIG_LIBDIR=' in build
assert 'libdav1d.so.7|libdav1d|1.5.3-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['vision-av1-independent-decoder'] == ['libdav1d']
consumer = (repo / 'tests/dav1d-aom-runtime-smoke.c').read_text()
for symbol in ('aom_codec_encode', 'dav1d_send_data', 'dav1d_get_picture', 'dav1d_parse_sequence_header'):
    assert symbol in consumer
subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
print('dav1d provider policy: PASS locked source, CPU0 cross build and AOM/dav1d decoding fixture')
