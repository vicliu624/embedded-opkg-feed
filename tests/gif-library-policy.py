"""Require current GIF codec source, narrow library payload and notice inputs."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libgif'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='6.1.3-1'" in metadata
assert "PACKAGE_KIND='shared-library'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='COPYING TDVP-COPYRIGHT-NOTICE'" in metadata
assert 'libgif.so libgif.a' in build and 'install-lib install-include' in build
assert 'libgif.so.[0-9]*' in build and 'tdvp_assert_direct_archive_elfs' in build
assert 'install-bin' not in build and 'install-doc' not in build
assert 'extract-source-copyright-notices.py' in build
assert 'libgif.so.7|libgif|6.1.3-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['vision-gif'] == ['libgif']
test = (repo / 'tests/gif-roundtrip-runtime-smoke.c').read_text()
assert 'EGifPutLine' in test and 'DGifSlurp' in test and 'GIF89a' in test
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('GIF provider policy: PASS current source, library-only payload, component notices and codec regression')
