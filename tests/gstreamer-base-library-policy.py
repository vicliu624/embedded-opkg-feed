"""Check base media library source, dependency and owner declarations."""
from pathlib import Path
import json
import re

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/gstreamer-plugins-base'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='1.28.7-1'" in env and "PACKAGE_KIND='runtime'" in env
assert "PACKAGE_BUILD_DEPENDS='libgstreamer'" in env
assert "PACKAGE_DEPENDS='libgstreamer (= 1.28.7-1)'" in env
assert "SOURCE_ARTIFACT_1_SHA256='ed6e5410f496d171818763af2265e7977154bc7f9b827e98acf8c5bed21dd5a7'" in lock
assert '--wrap-mode=nodownload' in build and '-march=rv64imafdc -mabi=lp64d' in build
for feature in ('alsa', 'ogg', 'vorbis', 'opus', 'pango'):
    assert f'-D{feature}=enabled' in build
assert '"$payload/usr/bin"' not in build
providers = (repo / 'platforms/tdvp-k230-r1/sdk-development-providers.tsv').read_text()
dependencies = re.search(r"^PACKAGE_SDK_DEVELOPMENT_DEPENDS='([^']+)'", env, re.M)[1].split()
for dependency in dependencies:
    assert any(line.startswith(dependency + '|') for line in providers.splitlines()), dependency
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
for library in ('allocators', 'app', 'audio', 'fft', 'pbutils', 'riff', 'rtp', 'rtsp', 'sdp', 'tag', 'video'):
    assert f'libgst{library}-1.0.so.0|gstreamer-plugins-base|1.28.7-1' in owners
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert cohort['groups']['multimedia-pipeline-base'] == ['gstreamer-plugins-base']
print('GStreamer base policy: PASS source lock, core dependency, SDK providers and media SONAME ownership')
