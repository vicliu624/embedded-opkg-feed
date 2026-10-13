import numpy as np
import onnx
from onnx import helper, TensorProto, numpy_helper

assert onnx.__version__ == "1.17.0"
model = helper.make_model(
    helper.make_graph(
        [helper.make_node("Identity", ["x"], ["y"])], "tdvp-python-model",
        [helper.make_tensor_value_info("x", TensorProto.FLOAT, [2])],
        [helper.make_tensor_value_info("y", TensorProto.FLOAT, [2])],
    ), opset_imports=[helper.make_opsetid("", 13)], ir_version=8,
)
onnx.checker.check_model(model, full_check=True)
loaded = onnx.load_model_from_string(model.SerializeToString())
inferred = onnx.shape_inference.infer_shapes(loaded)
assert inferred.graph.output[0].type.tensor_type.shape.dim[0].dim_value == 2
data = np.array([1.25, -3.0], dtype=np.float32)
assert np.array_equal(numpy_helper.to_array(numpy_helper.from_array(data)), data)
invalid = onnx.ModelProto()
invalid.CopyFrom(model)
invalid.graph.node[0].op_type = "DefinitelyMissingTdvpOperator"
try:
    onnx.checker.check_model(invalid)
except onnx.checker.ValidationError:
    pass
else:
    raise AssertionError("invalid ONNX operator was accepted")
print("Complete Python ONNX import, model creation, shape inference and tensor roundtrip: PASS")
