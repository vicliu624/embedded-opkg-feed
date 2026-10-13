"""Keep third-pass runtime providers and the parallel XML ABI explicit."""
import json
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[1]
expected = {
    "libev": {"libev.so.4"}, "libjansson": {"libjansson.so.4"},
    "libzip": {"libzip.so.5"}, "libmnl": {"libmnl.so.0"},
    "libnftnl": {"libnftnl.so.11"}, "liblzo2": {"liblzo2.so.2"},
    "libxml2-16": {"libxml2.so.16"}, "libxslt": {"libxslt.so.1", "libexslt.so.0"},
}
owners = {}
for line in (repo / "platforms/tdvp-k230-r1/extra-runtime-owners.tsv").read_text().splitlines():
    if line and not line.startswith("#"):
        soname, package, version = line.split("|")
        assert soname not in owners, soname
        owners[soname] = (package, version)
cohort = json.loads((repo / "support/ai-common-library-cohort.json").read_text())
assert set(cohort["groups"]["common-event-data-network"]) == set(expected)
for package, sonames in expected.items():
    directory = repo / "packages" / package
    metadata = (directory / "package.env").read_text()
    version = re.search(r"^VERSION='([^']+)'", metadata, re.M)[1]
    assert "PACKAGE_AUTO_RUNTIME_DEPENDS=1" in metadata
    assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert {name for name, owner in owners.items() if owner[0] == package} == sonames
    assert all(owners[name] == (package, version) for name in sonames)
    subprocess.run(["bash", "-n", str(directory / "build.sh")], check=True)
    subprocess.run(["bash", str(repo / "scripts/verify-source-lock.sh"), "--package-dir", str(directory)], check=True)
assert "'libxml2.so.16*'" in (repo / "packages/libxml2-16/build.sh").read_text()
assert "PACKAGE_BUILD_DEPENDS='libxml2-16'" in (repo / "packages/libxslt/package.env").read_text()
assert "PACKAGE_BUILD_DEPENDS='libmnl'" in (repo / "packages/libnftnl/package.env").read_text()
assert "PACKAGE_USE_FEED_DEVELOPMENT=1" in (repo / "packages/libnftnl/package.env").read_text()
print("Third-pass policy: PASS eight recipes, nine SONAMEs, parallel XML ABI and build dependencies")
