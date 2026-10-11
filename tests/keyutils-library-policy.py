"""Require stable locked keyutils source, separate runtime and fixed build marker."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libkeyutils'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
lock = (package / 'source.lock').read_text()
assert "VERSION='1.6.3-2'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENCE.LGPL TDVP-COPYRIGHT-NOTICE'" in metadata
assert 'https://sources.buildroot.net/keyutils/keyutils-1.6.3.tar.gz' in lock
assert "SOURCE_ARTIFACT_1_SHA256='a61d5706136ae4c05bd48f86186bcfdbd88dd8bd5107e3e195c924cfc1b39bb4'" in lock
assert 'tdvp_unpack_locked_source_archive' in build
assert 'source-locked' in build and '-ffile-prefix-map=' in build
assert 'LIBDIR=/usr/lib USRLIBDIR=/usr/lib BUILDFOR=' in build
assert 'libkeyutils.so libkeyutils.a pkgconfig' in build
assert ' install' not in build
assert 'libkeyutils.so.[0-9]*' in build
assert '--file keyutils.c --file keyutils.h' in build
assert '0001-defer-rpm-only-probes.patch' in build and 'SOURCE_PATCH_1_SHA256=' in lock
assert 'libkeyutils.so.1|libkeyutils|1.6.3-2' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-kernel-key-management'] == ['libkeyutils']
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('Keyutils provider policy: PASS stable source, fixed marker, notices and runtime separation')
