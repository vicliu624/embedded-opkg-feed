"""Exercise trust decisions without contacting any model repository."""
import hashlib
from pathlib import Path
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

import onnx
from onnx import TensorProto, helper, hub

for operation in (hub.load, hub.download_model_with_test_data):
    with patch.object(hub, "get_model_info") as metadata, patch.object(hub, "_download_file") as download, patch("builtins.input") as prompt:
        try:
            operation("fixture", repo="untrusted/models:main", silent=True)
        except ValueError as error:
            assert "silent=True" in str(error)
        else:
            raise AssertionError("silent mode bypassed model trust")
        metadata.assert_not_called()
        download.assert_not_called()
        prompt.assert_not_called()
    with patch.object(hub, "get_model_info") as metadata, patch.object(hub, "_download_file") as download, patch("builtins.input", return_value="n") as prompt:
        assert operation("fixture", repo="untrusted/models:main", silent=False) is None
        prompt.assert_called_once()
        metadata.assert_not_called()
        download.assert_not_called()
    with patch.object(hub, "get_model_info", side_effect=RuntimeError("metadata-after-consent")) as metadata, patch("builtins.input", return_value="y") as prompt:
        try:
            operation("fixture", repo="untrusted/models:main", silent=False)
        except RuntimeError as error:
            assert str(error) == "metadata-after-consent"
        else:
            raise AssertionError("explicit confirmation did not continue")
        metadata.assert_called_once()
        prompt.assert_called_once()

model = helper.make_model(helper.make_graph(
    [helper.make_node("Identity", ["X"], ["Y"])], "trusted-fixture",
    [helper.make_tensor_value_info("X", TensorProto.FLOAT, [1])],
    [helper.make_tensor_value_info("Y", TensorProto.FLOAT, [1])]),
    opset_imports=[helper.make_opsetid("", 13)], ir_version=8)
model_bytes = model.SerializeToString()
digest = hashlib.sha256(model_bytes).hexdigest()
info = SimpleNamespace(model="fixture", model_path="fixture/tiny.onnx", model_sha=digest)
previous = hub.get_dir()
with tempfile.TemporaryDirectory(prefix="tdvp-hub-trust-") as directory:
    hub.set_dir(directory)
    try:
        with patch.object(hub, "get_model_info", return_value=info), patch.object(hub, "_download_file", side_effect=lambda url, path: Path(path).write_bytes(model_bytes)) as download, patch("builtins.input") as prompt:
            loaded = hub.load("fixture", repo="onnx/models:main", silent=True)
            onnx.checker.check_model(loaded)
            download.assert_called_once()
            prompt.assert_not_called()
        with patch.object(hub, "get_model_info", return_value=info), patch.object(hub, "_download_file") as download, patch("builtins.input") as prompt:
            loaded = hub.load("fixture", repo="onnx/models:main", silent=True)
            assert loaded.SerializeToString() == model_bytes
            download.assert_not_called()
            prompt.assert_not_called()
        # Even when the exact model is cached, its bytes grant no repository trust.
        with patch.object(hub, "get_model_info", return_value=info) as metadata:
            try:
                hub.load("fixture", repo="untrusted/models:main", silent=True)
            except ValueError:
                pass
            else:
                raise AssertionError("cached model bypassed repository trust")
            metadata.assert_not_called()
    finally:
        hub.set_dir(previous)
print("ONNX hub trust: PASS both silent/decline gates, explicit consent, trusted download/cache, cached untrusted rejection; no network")
