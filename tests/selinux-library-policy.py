"""Keep CIL, PCRE2 and the non-ELF-inferred sepol dependency in delivery."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
cohort = json.loads((repo / 'support/ai-common-library-cohort.json').read_text())
assert cohort['groups']['common-security-policy'] == ['libsepol', 'libselinux']
owners = (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text().splitlines()
for package, soname in [('libsepol', 'libsepol.so.2'), ('libselinux', 'libselinux.so.1')]:
    directory = repo / 'packages' / package
    metadata = (directory / 'package.env').read_text()
    assert "VERSION='3.11-2'" in metadata
    assert 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' in metadata
    assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert soname + '|' + package + '|3.11-2' in owners
    subprocess.run(['bash', '-n', str(directory / 'build.sh')], check=True)
    subprocess.run(['bash', str(repo / 'scripts/verify-source-lock.sh'), '--package-dir', str(directory)], check=True)
metadata = (repo / 'packages/libselinux/package.env').read_text()
assert "PACKAGE_DEPENDS='libsepol (= 3.11-2)'" in metadata
assert "PACKAGE_BUILD_DEPENDS='libsepol'" in metadata
assert 'PACKAGE_USE_FEED_DEVELOPMENT=1' in metadata
helper = (repo / 'support/build-selinux-library.sh').read_text()
assert 'DISABLE_CIL=n' in helper and 'PCRE_LDLIBS=-lpcre2-8' in helper
assert 'libsepol development staging' in helper
assert 'source_root/src' in helper and 'source_root/include' in helper
assert 'relabel' not in helper.replace('# Standalone userspace libraries. No policy loading, relabeling or service setup.', '')
assert 'TDVP-COPYRIGHT-NOTICE' in helper
subprocess.run(['bash', '-n', str(repo / 'support/build-selinux-library.sh')], check=True)
print('SELinux provider policy: PASS CIL, PCRE2, explicit dynamic dependency, notices and runtime ownership')
