"""Validate VPX runtime providers and parser source-input identity."""
import hashlib
import json
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
required = {package for packages in cohort['groups'].values() for package in packages}
for name in ('libvpx', 'gstreamer-plugins-bad'):
    package = repo / 'packages' / name
    env = (package / 'package.env').read_text()
    lock = (package / 'source.lock').read_text()
    build = (package / 'build.sh').read_text()
    assert name in required
    assert "PACKAGE_AUTO_RUNTIME_DEPENDS=1" in env
    assert "PACKAGE_BASE_OVERLAY='deny'" in env
    assert '-march=rv64imafdc' in build and '-mabi=lp64d' in build
    assert re.search(r"SOURCE_ARTIFACT_1_SHA256='[0-9a-f]{64}'", lock)
assert 'libvpx.so.12|libvpx|' in owners
bad = repo / 'packages/gstreamer-plugins-bad'
lock = (bad / 'source.lock').read_text()
patch_name = re.search(r"SOURCE_BUILD_INPUT_1_FILE='([^']+)'", lock)[1]
digest = re.search(r"SOURCE_BUILD_INPUT_1_SHA256='([^']+)'", lock)[1]
assert hashlib.sha256((bad / patch_name).read_bytes()).hexdigest() == digest
assert 'libgstcodecparsers-1.0.so.0|gstreamer-plugins-bad|' in owners
env = (bad / 'package.env').read_text()
assert "PACKAGE_BUILD_DEPENDS='libgstreamer gstreamer-plugins-base'" in env
assert 'videoparsers' in env and 'gstreamer-plugins-good' not in env
print('VPX library policy: PASS CPU0, provider closure, locked parser patch and acyclic build dependencies')
