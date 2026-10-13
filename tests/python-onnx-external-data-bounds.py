"""Exercise external-data metadata and file bounds without large allocations."""
from pathlib import Path
import tempfile
import warnings

from onnx import TensorProto
from onnx.external_data_helper import ExternalDataInfo, load_external_data_for_tensor

with tempfile.TemporaryDirectory(prefix="tdvp-onnx-external-bounds-") as directory:
    root = Path(directory)
    data = b"abcdefgh"
    (root / "tensor.bin").write_bytes(data)
    tensor = TensorProto(name="unknown-keys", data_type=TensorProto.UINT8, dims=[8], data_location=TensorProto.EXTERNAL)
    for key, value in (("location", "tensor.bin"), ("__class__", "injected"), ("unexpected", "ignored")):
        entry = tensor.external_data.add()
        entry.key, entry.value = key, value
    with warnings.catch_warnings(record=True) as recorded:
        warnings.simplefilter("always")
        info = ExternalDataInfo(tensor)
    assert type(info) is ExternalDataInfo and not hasattr(info, "unexpected")
    assert len(recorded) == 1 and "Ignoring unknown" in str(recorded[0].message)
    for key in ("offset", "length"):
        for value in ("-1", "invalid"):
            tensor = TensorProto(name="invalid-metadata")
            entry = tensor.external_data.add()
            entry.key, entry.value = key, value
            try:
                ExternalDataInfo(tensor)
            except ValueError:
                pass
            else:
                raise AssertionError("invalid external metadata accepted: " + key + "=" + value)
    for offset, length, expected in ((0, None, data), (2, 3, b"cde"), (0, 0, b""), (8, 0, b"")):
        tensor = TensorProto(name="valid-read", data_type=TensorProto.UINT8, dims=[8], data_location=TensorProto.EXTERNAL)
        fields = [("location", "tensor.bin"), ("offset", str(offset))]
        if length is not None:
            fields.append(("length", str(length)))
        for key, value in fields:
            entry = tensor.external_data.add()
            entry.key, entry.value = key, value
        load_external_data_for_tensor(tensor, str(root))
        assert tensor.raw_data == expected
    for offset, length in ((9, 0), (0, 9), (2, 7), (0, 9_000_000_000_000_000), (9_000_000_000_000_000, 0)):
        tensor = TensorProto(name="bounded-read", data_type=TensorProto.UINT8, dims=[8], data_location=TensorProto.EXTERNAL)
        for key, value in (("location", "tensor.bin"), ("offset", str(offset)), ("length", str(length))):
            entry = tensor.external_data.add()
            entry.key, entry.value = key, value
        try:
            load_external_data_for_tensor(tensor, str(root))
        except ValueError as error:
            assert "exceeds" in str(error), str(error)
        else:
            raise AssertionError("out-of-bounds external read accepted")
        assert tensor.raw_data == b"" and (root / "tensor.bin").read_bytes() == data
print("ONNX external metadata/bounds: PASS injection, invalid numbers, oversized reads, zero length and valid slices")
