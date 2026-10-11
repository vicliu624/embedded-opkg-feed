"""Check network/container plugin selection and runtime data delivery."""
from pathlib import Path
import json
import re

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/gstreamer-plugins-good'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='1.28.7-2'" in env and "PACKAGE_KIND='runtime'" in env
assert "PACKAGE_BUILD_DEPENDS='libgstreamer gstreamer-plugins-base libvpx gstreamer-plugins-bad'" in env
assert 'gstreamer-plugins-bad (>= 1.28.7-1)' in env
assert 'gstreamer-plugins-base (>= 1.28.7-2)' in env
assert "SOURCE_ARTIFACT_1_SHA256='87256969c82cf3bc8574301f3e7044a90de0ac500a5a27d8ba38c4dde894dd8b'" in lock
features = re.search(r"^PACKAGE_GSTREAMER_FEATURES='([^']+)'", env, re.M)[1].split()
for feature in ('isomp4', 'matroska', 'avi', 'rtp', 'rtpmanager', 'rtsp', 'udp', 'wavenc', 'wavparse', 'jpeg', 'png', 'flac', 'vpx'):
    assert feature in features
assert '--wrap-mode=nodownload' in build and '-march=rv64imafdc -mabi=lp64d' in build
assert '-Dv4l2=disabled' in build and '-Dgtk3=disabled' in build
assert '"$work/install/usr/share/gstreamer-1.0"' in build
assert '"$payload/usr/share/"' in build
providers = (repo / 'platforms/tdvp-k230-r1/sdk-development-providers.tsv').read_text()
dependencies = re.search(r"^PACKAGE_SDK_DEVELOPMENT_DEPENDS='([^']+)'", env, re.M)[1].split()
for dependency in dependencies:
    assert any(line.startswith(dependency + '|') for line in providers.splitlines()), dependency
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert cohort['groups']['multimedia-pipeline-network-containers'] == ['gstreamer-plugins-good']
print('GStreamer good policy: PASS locked source, media/network features, SDK reuse, presets and camera boundary')
