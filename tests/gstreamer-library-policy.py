"""Check the source-locked GStreamer core/tool split without building firmware."""
from pathlib import Path
import json
import re

repo = Path(__file__).resolve().parents[1]
packages = repo / 'packages'
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert cohort['groups']['multimedia-pipeline-core'] == ['libgstreamer', 'gstreamer-tools']
for name, kind in (('libgstreamer', 'runtime'), ('gstreamer-tools', 'application')):
    directory = packages / name
    env = (directory / 'package.env').read_text()
    lock = (directory / 'source.lock').read_text()
    assert f"PACKAGE='{name}'" in env and f"PACKAGE_KIND='{kind}'" in env
    assert "VERSION='1.28.7-1'" in env and 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in env
    assert "SOURCE_ARTIFACT_1_SHA256='787329b2c5758e228a71d926a6dcf960bceaacca3cadd63874ba665dfcda013e'" in lock
core = (packages / 'libgstreamer/build.sh').read_text()
tools = (packages / 'gstreamer-tools/build.sh').read_text()
assert '--wrap-mode=nodownload' in core
assert '-Dlibunwind=enabled -Dlibdw=enabled' in core
assert 'glib-mkenums' in core and 'glib-genmarshal' in core
assert 'libgst*.so.[0-9]*' in core and 'gst-plugin-scanner' not in tools
assert '"$payload/usr/bin"' not in core
assert "PACKAGE_BUILD_DEPENDS='libgstreamer'" in (packages / 'gstreamer-tools/package.env').read_text()
assert 'extract-split-provider.py' in tools and 'origin[\'notice_sha256\']' in tools
assert 'meson compile' not in tools
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
for soname in ('libgstreamer-1.0.so.0', 'libgstbase-1.0.so.0', 'libgstcontroller-1.0.so.0', 'libgstnet-1.0.so.0'):
    assert f'{soname}|libgstreamer|1.28.7-1' in owners
print('GStreamer policy: PASS source lock, core/tool split, dependencies and CPU0 build policy')
