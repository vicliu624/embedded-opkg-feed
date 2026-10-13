"""Exercise the public upstream Interpreter API against the shared CPU core."""
from pathlib import Path
import sys
import numpy as np
import tflite_runtime
from tflite_runtime.interpreter import Interpreter

assert tflite_runtime.__version__ == "2.18.0"
model = Path(sys.argv[1]).read_bytes()
for length in (4, 7):
    runtime = Interpreter(model_content=model, num_threads=1)
    inputs = runtime.get_input_details()
    for entry in inputs:
        runtime.resize_tensor_input(entry["index"], [length], strict=True)
    runtime.allocate_tensors()
    inputs = runtime.get_input_details()
    left = np.arange(length, dtype=np.float32)
    right = np.full(length, 0.5, dtype=np.float32)
    runtime.set_tensor(inputs[0]["index"], left)
    runtime.set_tensor(inputs[1]["index"], right)
    runtime.invoke()
    output = runtime.get_output_details()[0]
    np.testing.assert_allclose(runtime.get_tensor(output["index"]), left + right, rtol=1e-6)
    try:
        runtime.set_tensor(inputs[0]["index"], left.astype(np.int32))
    except ValueError:
        pass
    else:
        raise AssertionError("TFLite accepted an incompatible tensor dtype")
try:
    Interpreter(model_content=b"invalid", num_threads=1)
except (ValueError, RuntimeError):
    pass
else:
    raise AssertionError("TFLite accepted an invalid model")
try:
    Interpreter(model_content=model, num_threads=1,
                experimental_default_delegate_latest_features=True)
except ValueError as error:
    assert "XNNPACK" in str(error), error
else:
    raise AssertionError("TFLite advertised an unavailable XNNPACK option")
print("Python TFLite shared-core inference, tensor resize/read/write, invalid input and unavailable delegate rejection: PASS")
