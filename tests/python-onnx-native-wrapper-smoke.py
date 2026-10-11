"""Check the wrapper projection before packaging the complete Python module."""
import sys
from pathlib import Path
import onnx_cpp2py_export as native

wire = Path(sys.argv[1]).read_bytes()
native.checker.check_model(wire, full_check=True)
assert len(native.defs.get_all_schemas()) > 100
try:
    native.checker.check_model(b"invalid protobuf")
except Exception:
    pass
else:
    raise AssertionError("invalid model was accepted")
print("RISC-V ONNX wrapper, public schema registry and model validation: PASS")
