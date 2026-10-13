"""Notice collection must preserve bytes and expose uncovered modules."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/install-go-package-notices.py"
with tempfile.TemporaryDirectory(prefix="tdvp-go-notices-") as directory:
    root = Path(directory)
    source = root / "source"
    vendor = source / "vendor/example.org/module"
    vendor.mkdir(parents=True)
    (source / "LICENSE").write_bytes(b"Upstream fixture\r\n")
    (vendor / "LICENCE-MIT").write_bytes(b"Vendor fixture\n")
    uncovered = source / "vendor/example.org/uncovered"
    uncovered.mkdir()
    (uncovered / "code.go").write_text("package fixture\n")
    (source / "vendor/modules.txt").write_text("# example.org/module v1.0.0\n## explicit\n# example.org/uncovered v2.0.0\n## explicit\n# example.org/not-vendored v3.0.0\n## explicit\n")
    go = root / "go"
    go.mkdir()
    (go / "LICENSE").write_text("Go fixture\n")
    output = root / "output"
    command = [sys.executable, str(script), "--source", str(source), "--go-root", str(go), "--output", str(output)]
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    inventory = json.loads((output / "notice-inventory.json").read_text())
    assert inventory["modules_without_direct_notice"] == ["example.org/uncovered"]
    assert inventory["modules_without_vendor_sources"] == ["example.org/not-vendored"]
    assert (output / "LICENSE").read_bytes() == (source / "LICENSE").read_bytes()
    assert (output / "vendor/example.org/module/LICENCE-MIT").read_bytes() == (vendor / "LICENCE-MIT").read_bytes()
    for record in inventory["notice_files"]:
        assert hashlib.sha256((output / record["path"]).read_bytes()).hexdigest() == record["sha256"]
    rejected = subprocess.run(command, capture_output=True, text=True)
    assert rejected.returncode != 0 and "refusing existing" in rejected.stderr
    (vendor / "NOTICE").symlink_to(go / "LICENSE")
    rejected = subprocess.run(command[:-1] + [str(root / "unsafe-output")], capture_output=True, text=True)
    assert rejected.returncode != 0 and "unsafe notice" in rejected.stderr
    assert not (root / "unsafe-output").exists()
print("Go package notices: PASS bytes, hashes, uncovered module report, no overwrite and symlink rejection")
