"""Require every protoc consumer to prepare its declared native Abseil input."""
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
consumers = []
for path in sorted((repo / "packages").glob("*/build.sh")):
    text = path.read_text()
    if "tdvp_prepare_native_cmake_input" not in text or "bin/protoc" not in text:
        continue
    consumers.append(path.parent.name)
    start = text.index("bin/protoc")
    assert "lib/cmake/absl/abslConfig.cmake" in text[:start], str(path)
    assert "-DABSL_PROPAGATE_CXX_STD=ON" in text[:start], str(path)
assert set(consumers) >= {"libprotobuf", "libonnx", "libonnxruntime", "python3-onnx"}, consumers
print("Serialization native provider policy: PASS", ", ".join(consumers))
