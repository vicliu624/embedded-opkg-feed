"""Exercise the native checker binding and model-file checker path policy."""
import os
from pathlib import Path
import tempfile

import onnx
from onnx import TensorProto, helper
from onnx.onnx_cpp2py_export import checker as native_checker

with tempfile.TemporaryDirectory(prefix="tdvp-onnx-cpp-paths-") as directory:
    root = Path(directory)
    base = root / "model"
    base.mkdir()
    outside = root / "outside"
    outside.mkdir()
    victim = outside / "data.bin"
    victim.write_bytes(b"OUTSIDE!")
    (base / "normal.bin").write_bytes(b"NORMAL!!")
    (base / "nested").mkdir()
    (base / "nested/data.bin").write_bytes(b"NESTED!!")
    (base / "#valid.bin").write_bytes(b"HASHNAME")
    (base / "leaf-link").symlink_to(victim)
    (base / "parent-link").symlink_to(outside, target_is_directory=True)
    os.link(victim, base / "hardlink")
    os.mkfifo(base / "fifo")
    (base / "directory").mkdir()
    cases = [(name, True) for name in ("normal.bin", "nested/data.bin", "#valid.bin")]
    cases += [(name, False) for name in ("leaf-link", "parent-link/data.bin", "hardlink", "fifo", "directory",
                                        "../outside/data.bin", str(victim), "", "missing", "#missing", "nested/../normal.bin")]
    before = len(os.listdir("/proc/self/fd"))
    for location, accepted in cases:
        for mode in ("resolve", "model-check"):
            if mode == "model-check":
                tensor = TensorProto(name="X", data_type=TensorProto.UINT8, dims=[8], data_location=TensorProto.EXTERNAL)
                entry = tensor.external_data.add()
                entry.key, entry.value = "location", location
                graph = helper.make_graph([helper.make_node("Identity", ["X"], ["Y"])], "external-check", [],
                                          [helper.make_tensor_value_info("Y", TensorProto.UINT8, [8])], [tensor])
                model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 13)], ir_version=8)
                (base / "model.onnx").write_bytes(model.SerializeToString())
            try:
                if mode == "resolve":
                    result = native_checker._resolve_external_data_location(str(base), location, "X")
                    assert Path(result) == base / location
                else:
                    onnx.checker.check_model(str(base / "model.onnx"))
            except onnx.checker.ValidationError:
                assert not accepted, (mode, location, "valid external file rejected")
            else:
                assert accepted, (mode, location, "unsafe external file accepted")
    assert len(os.listdir("/proc/self/fd")) == before, "native checker leaked descriptors"
    assert victim.read_bytes() == b"OUTSIDE!"
print("Native ONNX checker: PASS direct/model APIs, valid nested/hash filenames, traversal/links/special/missing rejection and fd cleanup")
