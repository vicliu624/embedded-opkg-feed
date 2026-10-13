"""Verify notice identity, path containment and missing-notice rejection."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / "support/install-source-licenses.py"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    package = root / "package"
    package.mkdir()
    (package / "package.env").write_text("PACKAGE='license-fixture'\n")
    (package / "source.lock").write_text("UPSTREAM_LICENSE='MIT'\nUPSTREAM_VERSION='1.0'\n")
    source = root / "source"
    payload = root / "payload"
    source.mkdir()
    payload.mkdir()
    command = [sys.executable, str(script), str(source), str(package), str(payload)]
    missing = subprocess.run(command, capture_output=True)
    assert missing.returncode != 0 and not (payload / "usr").exists()
    (source / "LICENSE").write_bytes(b"Fixture license notice\n")
    subprocess.run(command, check=True, capture_output=True)
    destination = payload / "usr/share/licenses/license-fixture"
    assert (destination / "LICENSE").read_bytes() == (source / "LICENSE").read_bytes()
    origin = json.loads((destination / "SOURCE.json").read_text())
    assert origin["declared_license"] == "MIT" and origin["source"]["UPSTREAM_VERSION"] == "1.0"
    subprocess.run(command, check=True, capture_output=True)
    for malicious in ("../outside", "/etc/passwd"):
        result = subprocess.run(command + ["--license-file", malicious], capture_output=True)
        assert result.returncode != 0
    (source / "LICENSE").unlink()
    (source / "LICENSE").symlink_to(package / "source.lock")
    assert subprocess.run(command, capture_output=True).returncode != 0
print("Source license projection: PASS identity, idempotence, missing notices and unsafe paths")
