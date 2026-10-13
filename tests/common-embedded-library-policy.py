"""Check embedded serial/device-tree/storage providers without touching hardware."""
import json
from pathlib import Path
import re
import subprocess

repo = Path(__file__).resolve().parents[1]
expected = {"libserialport": ("libserialport.so.0", "0.1.2-1"),
            "libfdt": ("libfdt.so.1", "1.8.1-2"),
            "liblmdb": ("liblmdb.so", "0.9.36-2")}
cohort = json.loads((repo / "support/ai-common-library-cohort.json").read_text())
assert set(cohort["groups"]["common-embedded-system"]) == set(expected)
owners = (repo / "platforms/tdvp-k230-r1/extra-runtime-owners.tsv").read_text().splitlines()
for package, (soname, version) in expected.items():
    directory = repo / "packages" / package
    metadata = (directory / "package.env").read_text()
    assert f"VERSION='{version}'" in metadata and "PACKAGE_BASE_OVERLAY='deny'" in metadata
    assert "PACKAGE_AUTO_RUNTIME_DEPENDS=1" in metadata
    assert f"{soname}|{package}|{version}" in owners
    subprocess.run(["bash", "-n", str(directory / "build.sh")], check=True)
    subprocess.run(["bash", str(repo / "scripts/verify-source-lock.sh"), "--package-dir", str(directory)], check=True)
for package in ("libfdt", "liblmdb"):
    build = (repo / "packages" / package / "build.sh").read_text()
    assert "extract-source-copyright-notices.py" in build
    assert "usr/share/licenses" in build
lmdb = (repo / "packages/liblmdb/build.sh").read_text()
assert "MDB_NOLOCK" not in lmdb and "MDB_USE_POSIX_SEM" not in lmdb
pc = (repo / "packages/liblmdb/files/lmdb.pc").read_text()
assert "Version: 0.9.36" in pc and "-llmdb" in pc and "/tmp/" not in pc
assert re.search(r"^PACKAGE_LICENSE_FILES='.*TDVP-COPYRIGHT-NOTICE", (repo / "packages/libfdt/package.env").read_text(), re.M)
print("Embedded common-library policy: PASS three providers, source locks, notices and unchanged lock configuration")
