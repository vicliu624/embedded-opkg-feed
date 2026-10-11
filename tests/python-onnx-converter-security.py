"""Require safe rejection of malformed converter inputs in isolated processes."""
import argparse
import os
import resource
import shlex
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--case")
args = parser.parse_args()
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
cases = ("upsample", "cast", "softmax", "group-normalization", "gemm-7-6", "gemm-6-7", "normal", "normal-group-normalization")
if args.case is None:
    prefix = shlex.split(os.environ.get("TDVP_TEST_PYTHON_PREFIX", ""))
    executable = os.environ.get("TDVP_TEST_PYTHON_EXECUTABLE", sys.executable)
    for case in cases:
        result = subprocess.run([*prefix, executable, __file__, "--case", case], capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, (case, result.returncode, result.stdout, result.stderr)
    print("ONNX converter security: PASS missing inputs, Gemm ranks, valid conversion; isolated subprocesses")
else:
    import onnx
    from onnx import helper, TensorProto, version_converter

    inputs = []
    values = []
    attributes = {}
    if args.case.startswith("gemm"):
        before, after = (7, 6) if args.case == "gemm-7-6" else (6, 7)
        operation = "Gemm"
        values = [helper.make_tensor_value_info(name, TensorProto.FLOAT, shape)
                  for name, shape in (("A", [2, 3]), ("B", [3]), ("C", [2, 4]))]
        inputs = ["A", "B", "C"]
    elif args.case == "normal-group-normalization":
        before, after, operation = 20, 21, "GroupNormalization"
        inputs = ["X", "scale", "bias"]
        values = [helper.make_tensor_value_info(name, TensorProto.FLOAT, shape)
                  for name, shape in (("X", [1, 2, 2, 2]), ("scale", [1]), ("bias", [1]))]
        attributes = {"num_groups": 1}
    elif args.case == "normal":
        before, after, operation = 9, 8, "Cast"
        inputs = ["X"]
        values = [helper.make_tensor_value_info("X", TensorProto.FLOAT, [1])]
        attributes = {"to": TensorProto.FLOAT}
    else:
        before, after, operation = {"upsample": (6, 7, "Upsample"), "cast": (9, 8, "Cast"),
                                    "softmax": (12, 13, "Softmax"),
                                    "group-normalization": (20, 21, "GroupNormalization")}[args.case]
        if args.case == "upsample":
            attributes = {"width_scale": 2.0, "height_scale": 2.0}
        elif args.case == "cast":
            attributes = {"to": TensorProto.FLOAT}
        elif args.case == "group-normalization":
            attributes = {"num_groups": 1}
    model = helper.make_model(helper.make_graph(
        [helper.make_node(operation, inputs, ["Y"], **attributes)], "converter-security", values,
        [helper.make_tensor_value_info("Y", TensorProto.FLOAT,
                                      [1, 2, 2, 2] if args.case == "normal-group-normalization" else [1])]),
        opset_imports=[helper.make_opsetid("", before)], ir_version=8)
    if args.case.startswith("normal"):
        converted = version_converter.convert_version(model, after)
        assert converted.opset_import[0].version == after
        if args.case == "normal-group-normalization":
            onnx.checker.check_model(converted, full_check=True)
            assert any(node.op_type == "Expand" for node in converted.graph.node), "dedicated GroupNormalization adapter was bypassed"
    else:
        try:
            version_converter.convert_version(model, after)
        except (RuntimeError, onnx.shape_inference.InferenceError) as error:
            assert "input" in str(error).lower() or "dimension" in str(error).lower(), str(error)
        else:
            raise AssertionError("malformed converter model was accepted: " + args.case)
