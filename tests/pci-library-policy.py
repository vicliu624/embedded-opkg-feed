"""Require PCI runtime data, fixed source and complete target feature inputs."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libpci'
metadata = (package / 'package.env').read_text()
build = (package / 'build.sh').read_text()
lock = (package / 'source.lock').read_text()
assert "VERSION='3.15.0-1'" in metadata
assert "PACKAGE_KIND='runtime'" in metadata
assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
assert "PACKAGE_LICENSE_FILES='COPYING TDVP-COPYRIGHT-NOTICE TDVP-PCI-ID-NOTICE'" in metadata
assert 'SOURCE_ARTIFACT_1_SHA256=\'c02940f430841ecf158d5d9a50007afc4d5353c8678a2455003ca0b2c4e9f5ff\'' in lock
assert 'HOST=riscv64-linux SHARED=yes PREFIX=/usr LIBDIR=/usr/lib' in build
assert 'ZLIB=yes DNS=yes HWDB=yes LIBKMOD=yes' in build
assert 'install-lib' in build and 'gzip -n -c' in build
assert 'payload_dir/usr/share/pci.ids.gz' in build
assert 'libpci.so.[0-9]*' in build and 'TDVP-PCI-ID-NOTICE' in build
assert 'libpci.so.3|libpci|3.15.0-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['common-pci-access'] == ['libpci']
subprocess.run(['bash', '-n', str(package / 'build.sh')], check=True)
subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(package)], check=True)
print('PCI provider policy: PASS features, locked data, deterministic gzip, notices and runtime owner')
