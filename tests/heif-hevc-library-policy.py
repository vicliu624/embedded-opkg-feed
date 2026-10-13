"""Check HEIF codec ownership, development inputs and offline build policy."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
groups = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']
assert groups['vision-hevc'] == ['libde265', 'libx265']
assert groups['vision-heif'] == ['libheif']
for package, version, soname in (
    ('libde265', '1.1.3-1', 'libde265.so.0'),
    ('libx265', '4.3-1', 'libx265.so.217'),
    ('libheif', '1.23.6-1', 'libheif.so.1'),
):
    directory = repo / 'packages' / package
    assert "VERSION='" + version + "'" in (directory / 'package.env').read_text()
    assert '|'.join((soname, package, version)) in owners
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
heif = (repo / 'packages/libheif/build.sh').read_text()
metadata = (repo / 'packages/libheif/package.env').read_text()
assert "PACKAGE_BUILD_DEPENDS='libde265 libx265 libaom libopenjp2 libopenjph libwebp-7'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
for codec in ('LIBDE265', 'X265', 'AOM_ENCODER', 'AOM_DECODER', 'JPEG_ENCODER',
              'JPEG_DECODER', 'OpenJPEG_ENCODER', 'OpenJPEG_DECODER', 'OPENJPH_ENCODER'):
    assert '-DWITH_' + codec + '=ON' in heif
    assert '-DWITH_' + codec + '_PLUGIN=OFF' in heif
assert '-DWITH_LIBSHARPYUV=ON' in heif and 'usr/include/webp/sharpyuv/sharpyuv.h' in heif
assert '-DFETCHCONTENT_FULLY_DISCONNECTED=ON' in heif
x265 = (repo / 'packages/libx265/build.sh').read_text()
for archive in ('libx265_main.a', 'libx265_main10.a', 'libx265_main12.a'):
    assert 'ADDLIB ' + archive in x265
assert '--source "$source_root"' not in x265
assert '"$source_root/TDVP-COPYRIGHT-NOTICE" "${notice_args[@]}"' in x265
consumer = (repo / 'tests/heif-codec-runtime-smoke.c').read_text()
assert 'heif_compression_HEVC' in consumer and 'heif_compression_AV1' in consumer
assert 'rejected.code == heif_error_Ok' in consumer
print('HEIF/HEVC provider policy: PASS codec dependencies, multilib, source locks and negative fixture')
