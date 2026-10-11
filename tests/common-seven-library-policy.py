"""Validate the new common-library cohort's recipe and SONAME contracts."""
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[1]
expected = {
    "libbrotli": ("1.2.0-1", {"libbrotlicommon.so.1", "libbrotlidec.so.1", "libbrotlienc.so.1"}),
    "libcbor": ("0.14.0-1", {"libcbor.so.0.14"}),
    "libedit": ("20260512-1", {"libedit.so.0"}),
    "libidn2": ("2.3.8-1", {"libidn2.so.0"}),
    "libpsl": ("0.23.3-1", {"libpsl.so.5"}),
    "librhash": ("1.4.6-1", {"librhash.so.1"}),
    "libunwind": ("1.8.3-1", {"libunwind.so.8", "libunwind-riscv.so.8", "libunwind-coredump.so.0", "libunwind-ptrace.so.0", "libunwind-setjmp.so.0"}),
}
owners = {}
for row in (repo / "platforms/tdvp-k230-r1/extra-runtime-owners.tsv").read_text().splitlines():
    if row and not row.startswith("#"):
        soname, package, version = row.split("|")
        assert soname not in owners, f"duplicate SONAME {soname}"
        owners[soname] = (package, version)
for package, (version, sonames) in expected.items():
    directory = repo / "packages" / package
    metadata = directory.joinpath("package.env").read_text()
    for declaration in (f"PACKAGE='{package}'", f"VERSION='{version}'", "PACKAGE_AUTO_RUNTIME_DEPENDS=1", "PACKAGE_BASE_OVERLAY='deny'"):
        assert declaration in metadata, (package, declaration)
    assert {name for name, owner in owners.items() if owner[0] == package} == sonames, package
    for soname in sonames:
        assert owners[soname] == (package, version)
    subprocess.run(["bash", "-n", str(directory / "build.sh")], check=True)
    subprocess.run(["bash", str(repo / "scripts/verify-source-lock.sh"), "--package-dir", str(directory)], check=True)
psl = (repo / "packages/libpsl/package.env").read_text()
assert "PACKAGE_BUILD_DEPENDS='libidn2'" in psl
assert "PACKAGE_DEPENDS='libidn2 (= 2.3.8-1)'" in psl
assert "PACKAGE_USE_FEED_DEVELOPMENT=1" in psl
assert "--enable-runtime=libidn2 --enable-builtin" in (repo / "packages/libpsl/build.sh").read_text()
helper = (repo / "support/source-archive-library.sh").read_text()
assert 'if [[ ${PACKAGE_USE_FEED_DEVELOPMENT:-0} == 1 ]]; then' in helper
assert 'sysroot="$work_root/sysroot"' in helper
assert 'export PKG_CONFIG=/usr/bin/pkg-config' in helper
print("Common seven-library policy: PASS recipes, 13 SONAMEs, locks and explicit IDNA development dependency")
