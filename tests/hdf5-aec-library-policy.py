"""Preserve serial HDF5 language APIs, both compression filters and AEC edges."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['scientific-dataset-storage'] == ['libaec', 'libhdf5']
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for package, version, sonames in [('libaec', '1.1.7-1', ['libaec.so.0', 'libsz.so.2']), ('libhdf5', '2.2.0-1', ['libhdf5.so.320', 'libhdf5_cpp.so.320', 'libhdf5_hl.so.320', 'libhdf5_hl_cpp.so.320'])]:
    directory = repo / 'packages' / package
    metadata = (directory / 'package.env').read_text()
    assert "VERSION='" + version + "'" in metadata
    assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
    for soname in sonames:
        assert soname + '|' + package + '|' + version in owners
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
metadata = (repo / 'packages/libhdf5/package.env').read_text()
assert "PACKAGE_BUILD_DEPENDS='libaec'" in metadata and 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
build = (repo / 'packages/libhdf5/build.sh').read_text()
for option in ('HDF5_BUILD_CPP_LIB=ON', 'HDF5_BUILD_HL_LIB=ON', 'HDF5_ENABLE_ZLIB_SUPPORT=ON', 'HDF5_ENABLE_SZIP_SUPPORT=ON', 'HDF5_ENABLE_SZIP_ENCODING=ON', 'HDF5_USE_LIBAEC_STATIC=OFF', 'HDF5_ALLOW_UNSUPPORTED=OFF'):
    assert option in build
assert 'CMAKE_CROSSCOMPILING_EMULATOR=qemu-riscv64' in build
assert (repo / 'tests/hdf5-compression-runtime-smoke.cpp').is_file()
assert (repo / 'tests/hdf5-packet-table-runtime-smoke.cpp').is_file()
assert (repo / 'tests/aec-buffer-runtime-smoke.c').is_file()
print('HDF5/AEC provider policy: PASS language APIs, compression, explicit build dependency and complete SONAME ownership')
