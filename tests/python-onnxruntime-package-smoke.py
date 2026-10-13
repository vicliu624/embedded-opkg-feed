"""Exercise the installed Python inference API, including invalid input rejection."""
import ctypes

# Verify the public runtime provider before importing Python's extension. CPU
# inference can otherwise pass while ORT only logs a missing bridge warning.
provider_bridge = ctypes.CDLL("libonnxruntime_providers_shared.so")
assert provider_bridge.Provider_SetHost is not None

import numpy as np
import onnx
import onnxruntime as ort
from onnx import TensorProto, helper, numpy_helper

assert ort.__version__ == "1.21.0"
assert "CPUExecutionProvider" in ort.get_available_providers()
weights = np.array([[2.0, -1.0], [0.5, 3.0]], dtype=np.float32)
bias = np.array([0.25, -0.5], dtype=np.float32)
model = helper.make_model(
    helper.make_graph(
        [helper.make_node("MatMul", ["x", "w"], ["product"]),
         helper.make_node("Add", ["product", "b"], ["y"])],
        "tdvp-python-inference",
        [helper.make_tensor_value_info("x", TensorProto.FLOAT, [None, 2])],
        [helper.make_tensor_value_info("y", TensorProto.FLOAT, [None, 2])],
        [numpy_helper.from_array(weights, "w"), numpy_helper.from_array(bias, "b")],
    ),
    opset_imports=[helper.make_opsetid("", 13)], ir_version=8,
)
onnx.checker.check_model(model, full_check=True)
options = ort.SessionOptions()
options.intra_op_num_threads = 1
options.inter_op_num_threads = 1
session = ort.InferenceSession(
    model.SerializeToString(), sess_options=options,
    providers=["CPUExecutionProvider"],
)
for rows in (1, 3):
    inputs = np.arange(rows * 2, dtype=np.float32).reshape(rows, 2)
    outputs = session.run(["y"], {"x": inputs})
    assert len(outputs) == 1
    np.testing.assert_allclose(outputs[0], inputs @ weights + bias, rtol=1e-6)
try:
    session.run(["y"], {"x": np.zeros((1, 3), dtype=np.float32)})
except ort.capi.onnxruntime_pybind11_state.InvalidArgument:
    pass
else:
    raise AssertionError("ONNX Runtime accepted an invalid input shape")
print("Python ONNX Runtime CPU inference, dynamic batch and invalid input rejection: PASS")
