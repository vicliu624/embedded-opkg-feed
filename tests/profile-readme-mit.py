"""Build isolated profile payloads and verify the approved README-only license."""
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
versions = {
    "tdvp-dev-tools": "1.0-6",
    "tdvp-diagnostics": "1.1-3",
    "tdvp-nodejs-tools": "1.0-7",
    "tdvp-source-tools": "1.6-3",
}
with tempfile.TemporaryDirectory(prefix="tdvp-profile-mit-") as temporary:
    for name, version in versions.items():
        source = repo / "packages" / name
        isolated = Path(temporary) / name
        isolated.mkdir()
        for filename in ("build.sh", "README", "LICENSE"):
            shutil.copyfile(source / filename, isolated / filename)
        subprocess.run(["bash", str(isolated / "build.sh"), "--platform",
                        "tdvp-k230-r1", "--sdk-root", temporary], check=True)
        payload = isolated / "root"
        notice = payload / "usr/share/licenses" / name
        assert (notice / "LICENSE").read_bytes() == (source / "LICENSE").read_bytes()
        assert (notice / "LICENSE").read_text().startswith("MIT License\n")
        assert "README only" in (notice / "SCOPE").read_text()
        assert (payload / "usr/share/doc" / name / "README").read_bytes() == (source / "README").read_bytes()
        assert len(list(payload.rglob("*"))) > 0
        metadata = (source / "package.env").read_text()
        assert f"VERSION='{version}'" in metadata, name
        assert "PACKAGE_LICENSE='MIT'" in metadata, name
assert "tdvp-dev-tools (= 1.0-6)" in (repo / "packages/tdvp-nodejs-tools/package.env").read_text()
print("Profile README MIT: PASS four isolated builds, license scope and revision dependency")
