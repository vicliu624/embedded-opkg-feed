"""Keep AV1 encode/decode scalar and track runtime/development ownership."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libaom'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='3.13.3-1'" in metadata
assert "PACKAGE_KIND='shared-library'" in metadata
assert 'LICENSE PATENTS AUTHORS' in metadata and 'third_party/libyuv/LICENSE' in metadata
assert 'libaom.so.[0-9]*' in build
assert '-DAOM_TARGET_CPU=generic' in build and '-DCONFIG_RUNTIME_CPU_DETECT=0' in build
assert '-DCONFIG_AV1_ENCODER=0' not in build and '-DCONFIG_AV1_DECODER=0' not in build
for option in ('-DENABLE_TESTS=OFF', '-DENABLE_EXAMPLES=OFF', '-DENABLE_TOOLS=OFF'):
    assert option in build
assert 'libaom.so.3|libaom|3.13.3-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['vision-av1-codec'] == ['libaom']
consumer = (repo / 'tests/aom-lossless-runtime-smoke.c').read_text()
assert 'AV1E_SET_LOSSLESS' in consumer and 'AOM_IMG_FMT_HIGHBITDEPTH' in consumer
assert 'aom_codec_decode(&decoder, frame->data.frame.buf, 3' in consumer
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('AOM provider policy: PASS scalar AV1 encoder/decoder, notices, owner and codec fixture')
