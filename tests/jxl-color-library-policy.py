"""Require independent JPEG XL dependencies and portable CPU0 vector support."""
import hashlib
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['vision-jpeg-xl'] == ['libjxl']
assert groups['vision-color-management'] == ['liblcms2']
assert groups['common-portable-vector-infrastructure'] == ['libhwy']
for package, version, sonames in (
    ('libhwy', '1.2.0-1', ('libhwy.so.1', 'libhwy_contrib.so.1')),
    ('liblcms2', '2.19.1-1', ('liblcms2.so.2',)),
    ('libjxl', '0.12.0-1', ('libjxl.so.0.12', 'libjxl_cms.so.0.12', 'libjxl_threads.so.0.12')),
):
    directory = repo / 'packages' / package
    assert "VERSION='" + version + "'" in (directory / 'package.env').read_text()
    for soname in sonames:
        assert '|'.join((soname, package, version)) in owners
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
build = (repo / 'packages/libjxl/build.sh').read_text()
metadata = (repo / 'packages/libjxl/package.env').read_text()
assert "PACKAGE_BUILD_DEPENDS='libhwy liblcms2 libbrotli'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
for flag in ('JPEGXL_FORCE_SYSTEM_HWY=ON', 'JPEGXL_FORCE_SYSTEM_BROTLI=ON',
             'JPEGXL_FORCE_SYSTEM_LCMS2=ON', 'JPEGXL_ENABLE_TRANSCODE_JPEG=ON',
             'JPEGXL_ENABLE_BOXES=ON', 'FETCHCONTENT_FULLY_DISCONNECTED=ON'):
    assert flag in build
hwy_build = (repo / 'packages/libhwy/build.sh').read_text()
assert 'HWY_ENABLE_CONTRIB=ON' in hwy_build
assert 'HWY_CMAKE_RVV=OFF' in hwy_build
assert '-DCMAKE_CXX_FLAGS=' not in hwy_build
assert 'HWY_COMPILE_ONLY_EMU128' in (repo / 'packages/libhwy/cpu0-scalar.cmake').read_text()
for package, filename in (('libhwy', 'cpu0-scalar.cmake'), ('libjxl', 'cpu0-emulated.cmake')):
    policy = (repo / 'packages' / package / filename).read_text()
    assert 'add_compile_options(-march=rv64imafdc -mabi=lp64d)' in policy
    assert 'add_link_options(-march=rv64imafdc -mabi=lp64d)' in policy
assert hashlib.sha256((repo / 'packages/libhwy/cpu0-scalar.cmake').read_bytes()).digest() == hashlib.sha256((repo / 'packages/libjxl/cpu0-emulated.cmake').read_bytes()).digest()
assert 'memcmp(input, output' in (repo / 'tests/jxl-lossless-runtime-smoke.c').read_text()
assert 'cmsOpenProfileFromMem(bytes, 12)' in (repo / 'tests/lcms-profile-runtime-smoke.c').read_text()
assert 'VQSort' in (repo / 'tests/highway-runtime-smoke.cpp').read_text()
print('JPEG XL/color provider policy: PASS independent dependencies, CPU0 emulation, source locks and consumer fixtures')
