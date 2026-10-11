"""Check second-pass common libraries before any source batch starts."""
import json
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[1]
expected = {
    "libdeflate": {"libdeflate.so.0"}, "libsnappy": {"libsnappy.so.1"},
    "libmpfr": {"libmpfr.so.6"}, "libmpc": {"libmpc.so.3"},
    "libcap-ng": {"libcap-ng.so.0"}, "libattr": {"libattr.so.1"},
    "libacl": {"libacl.so.1"}, "libaio": {"libaio.so.1"},
    "liburing": {"liburing.so.2", "liburing-ffi.so.2"},
    "libssh2": {"libssh2.so.1"}, "libnghttp3": {"libnghttp3.so.9"},
    "libngtcp2": {"libngtcp2.so.16", "libngtcp2_crypto_gnutls.so.8"},
}
owners = {}
for row in (repo / "platforms/tdvp-k230-r1/extra-runtime-owners.tsv").read_text().splitlines():
    if row and not row.startswith("#"):
        soname, package, version = row.split("|")
        assert soname not in owners, soname
        owners[soname] = (package, version)
contract = json.loads((repo / "support/ai-common-library-cohort.json").read_text())
delivery = [name for group in contract["groups"].values() for name in group]
assert len(delivery) == len(set(delivery))
for package, sonames in expected.items():
    assert package in delivery, package
    directory = repo / "packages" / package
    metadata = (directory / "package.env").read_text()
    version = re.search(r"^VERSION='([^']+)'", metadata, re.M)[1]
    assert f"PACKAGE='{package}'" in metadata
    assert "PACKAGE_AUTO_RUNTIME_DEPENDS=1" in metadata
    assert "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert {name for name, owner in owners.items() if owner[0] == package} == sonames
    assert all(owners[name] == (package, version) for name in sonames)
    subprocess.run(["bash", "-n", str(directory / "build.sh")], check=True)
    subprocess.run(["bash", str(repo / "scripts/verify-source-lock.sh"), "--package-dir", str(directory)], check=True)
snappy = (repo / "packages/libsnappy/build.sh").read_text()
assert "-DSNAPPY_RVV_1=0" in snappy and "-DSNAPPY_RVV_0_7=0" in snappy
acl = (repo / "packages/libacl/package.env").read_text()
assert "PACKAGE_BUILD_DEPENDS='libattr'" in acl and "PACKAGE_USE_FEED_DEVELOPMENT=1" in acl
mpc = (repo / "packages/libmpc/package.env").read_text()
assert "PACKAGE_BUILD_DEPENDS='libmpfr'" in mpc and "PACKAGE_DEPENDS='libmpfr (= 4.2.2-1)'" in mpc
cap = (repo / "packages/libcap-ng/package.env").read_text()
assert "PACKAGE_AUTORECONF=1" in cap and "PACKAGE_BOOTSTRAP_SCRIPT='autogen.sh'" in cap
for command in ("autoreconf", "autoconf", "automake", "libtoolize"):
    assert command in re.search(r"^PACKAGE_HOST_DEPENDS='([^']*)'", cap, re.M)[1].split()
quic = (repo / "packages/libngtcp2/build.sh").read_text()
ssh = (repo / "packages/libssh2/package.env").read_text()
assert "PACKAGE_REPRODUCIBLE_SOURCE_PATHS=1" in ssh and "VERSION='1.11.1-2'" in ssh
assert "-DENABLE_GNUTLS=ON" in quic and "-DENABLE_OPENSSL=OFF" in quic
assert "libngtcp2_crypto_gnutls.so*" in quic
print("Common system/network policy: PASS 12 recipes, 14 SONAMEs, source locks, scalar and dependency contracts")
