"""Require independent AVIF codecs and scalar YUV development/runtime providers."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
avif = repo / 'packages/libavif'
yuv = repo / 'packages/libyuv'
metadata = (avif / 'package.env').read_text()
build = (avif / 'build.sh').read_text()
assert "VERSION='1.4.2-1'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libaom libyuv'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE'" in metadata
for flag in ('AVIF_CODEC_AOM=SYSTEM', 'AVIF_LIBYUV=SYSTEM', 'AVIF_CODEC_AOM_ENCODE=ON', 'AVIF_CODEC_AOM_DECODE=ON', 'FETCHCONTENT_FULLY_DISCONNECTED=ON'):
    assert flag in build
yuv_metadata = (yuv / 'package.env').read_text()
yuv_build = (yuv / 'build.sh').read_text()
assert "VERSION='1924-1'" in yuv_metadata and "PACKAGE_KIND='runtime'" in yuv_metadata
assert 'LIBYUV_DISABLE_RVV' in yuv_build and "'libyuv.so'" in yuv_build
assert "PACKAGE_LICENSE_FILES='LICENSE PATENTS AUTHORS'" in yuv_metadata
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert 'libavif.so.16|libavif|1.4.2-1' in owners and 'libyuv.so|libyuv|1924-1' in owners
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['vision-avif'] == ['libavif'] and groups['common-image-conversion'] == ['libyuv']
consumer = (repo / 'tests/avif-lossless-runtime-smoke.c').read_text()
assert 'qualityAlpha' in consumer and 'avifImageYUVToRGB' in consumer and 'data.data, 12' in consumer
yuv_consumer = (repo / 'tests/yuv-conversion-runtime-smoke.cpp').read_text()
assert 'I420ToARGB' in yuv_consumer and 'ARGBScale' in yuv_consumer and 'I420Rotate' in yuv_consumer
for package in (avif, yuv):
    subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('AVIF/libyuv provider policy: PASS external codecs, scalar conversion, ownership and runtime fixtures')
