"""Keep NUMA capability reporting separate and prohibit toolchain path export."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libnuma'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='2.0.19-1'" in metadata
assert "PACKAGE_KIND='shared-library'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='LICENSE.LGPL2.1 LICENSE.GPL2 TDVP-COPYRIGHT-NOTICE'" in metadata
assert 'libnuma.la' in build and 'install-libLTLIBRARIES install-includeHEADERS install-pkgconfigDATA' in build
assert 'tdvp_assert_direct_archive_elfs' in build
assert build.index('tdvp_assert_direct_archive_elfs') < build.index('cp -a "$payload_dir/usr/lib/." "$stage_root/usr/lib/"')
assert 'libnuma.so.1|libnuma|2.0.19-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-numa-compatibility'] == ['libnuma']
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('NUMA provider policy: PASS target library only, notices, clean consumer library and runtime owner')
