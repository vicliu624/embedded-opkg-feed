"""Exercise both import orders with one shared ONNX/ORT schema registry."""
import sys

import numpy as np

if len(sys.argv) > 1 and sys.argv[1] == "reference-first":
    from onnx.reference import ReferenceEvaluator
    import onnxruntime as ort
else:
    import onnxruntime as ort
    from onnx.reference import ReferenceEvaluator

import onnxruntime.quantization
import onnxruntime.transformers
from onnx import TensorProto, helper
from onnx.reference.op_run import _build_schemas

schemas = _build_schemas()
assert schemas[("", "Trilu")].domain == ""
assert schemas[("com.microsoft", "Trilu")].domain == "com.microsoft"
model = helper.make_model(
    helper.make_graph(
        [helper.make_node("Identity", ["x"], ["y"])], "shared-registry",
        [helper.make_tensor_value_info("x", TensorProto.FLOAT, [2])],
        [helper.make_tensor_value_info("y", TensorProto.FLOAT, [2])],
    ), opset_imports=[helper.make_opsetid("", 13)], ir_version=8,
)
inputs = np.array([1.0, 3.0], dtype=np.float32)
np.testing.assert_array_equal(ReferenceEvaluator(model).run(None, {"x": inputs})[0], inputs)
options = ort.SessionOptions()
options.intra_op_num_threads = 1
options.inter_op_num_threads = 1
session = ort.InferenceSession(model.SerializeToString(), options, providers=["CPUExecutionProvider"])
np.testing.assert_array_equal(session.run(None, {"x": inputs})[0], inputs)
print("Shared registry domains, import ordering, quantization imports and dual execution: PASS")
