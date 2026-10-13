"""Ensure tested ONNX fixes are installable upgrades with matching dependencies."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
metadata = {}
for name in ("libonnx", "python3-onnx", "python3-onnxruntime"):
    metadata[name] = dict(re.findall(r"^([A-Z0-9_]+)='([^']*)'$", (repo / "packages" / name / "package.env").read_text(), re.M))
for name, base, minimum in (("libonnx", "1.17.0", 2), ("python3-onnx", "1.17.0", 3),
                            ("python3-onnxruntime", "1.21.0", 3)):
    version, revision = metadata[name]["VERSION"].rsplit("-", 1)
    assert version == base and int(revision) >= minimum, "security revision not an upgrade: " + name
assert "libonnx (= " + metadata["libonnx"]["VERSION"] + ")" in metadata["python3-onnx"]["PACKAGE_DEPENDS"]
assert "python3-onnx (= " + metadata["python3-onnx"]["VERSION"] + ")" in metadata["python3-onnxruntime"]["PACKAGE_DEPENDS"]
print("ONNX security revisions: PASS core/Python upgrades and exact dependent references")
