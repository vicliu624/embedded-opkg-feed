"""Check actual emitted IPK control, not only recipe or helper source text."""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import tarfile
import io

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    package = root / "package"
    payload = package / "root/usr/share/dependency-range-fixture"
    payload.mkdir(parents=True)
    (payload / "marker").write_text("test")
    (package / "package.env").write_text("""PACKAGE='dependency-range-fixture'
VERSION='1-1'
DESCRIPTION='Test range preservation'
MAINTAINER='TDVP test'
SUPPORTED_PLATFORMS='tdvp-k230-r1'
PACKAGE_KIND='runtime'
PACKAGE_DEPENDS='python3 (>= 3.13.3-2), python3 (<< 3.14~), python3 (>= 3.13.3-2), python3-numpy (>= 2.2.6-2), python3-numpy (<< 2.5~)'
""")
    environment = {key: value for key, value in os.environ.items()
                   if not key.startswith("TDVP_")}
    subprocess.run(["bash", str(repo / "scripts/build-ipk.sh"), "--platform", "tdvp-k230-r1",
                    str(package), str(root / "ipks")], env=environment, check=True)
    package_file = next((root / "ipks").glob("*.ipk"))
    archive = subprocess.check_output(["ar", "p", str(package_file), "control.tar.gz"])
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as control:
        text = control.extractfile("./control").read().decode()
    depends = next(line[9:] for line in text.splitlines() if line.startswith("Depends: "))
    for clause in ("python3 (>= 3.13.3-2)", "python3 (<< 3.14~)",
                   "python3-numpy (>= 2.2.6-2)", "python3-numpy (<< 2.5~)"):
        assert depends.split(",").count(clause) + depends.split(",").count(" " + clause) == 1, depends
print("Actual IPK lower/upper dependency preservation and exact deduplication: PASS")
