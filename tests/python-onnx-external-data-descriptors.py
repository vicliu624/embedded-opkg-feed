"""Check descriptor-anchored external reads/writes, including path swaps."""
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

from onnx import TensorProto
from onnx.external_data_helper import load_external_data_for_tensor, save_external_data


def make_external_tensor(location, raw=b"payload"):
    tensor = TensorProto(name="descriptor-test", data_type=TensorProto.UINT8, dims=[len(raw)],
                         data_location=TensorProto.EXTERNAL, raw_data=raw)
    entry = tensor.external_data.add()
    entry.key, entry.value = "location", location
    return tensor


with tempfile.TemporaryDirectory(prefix="tdvp-onnx-descriptor-test-") as directory:
    root = Path(directory)
    base = root / "model"
    base.mkdir()
    outside = root / "outside"
    outside.mkdir()
    victim = outside / "data.bin"
    victim.write_bytes(b"OUTSIDE-FIXTURE")
    (base / "leaf-link").symlink_to(victim)
    (base / "parent-link").symlink_to(outside, target_is_directory=True)
    os.link(victim, base / "hardlink")
    os.mkfifo(base / "fifo")
    (base / "directory").mkdir()
    count_before = len(os.listdir("/proc/self/fd"))
    locations = ("../outside/data.bin", str(victim), "leaf-link", "parent-link/data.bin",
                 "hardlink", "fifo", "directory", "", "./data.bin", "nested/../data.bin")
    for location in locations:
        for operation in (load_external_data_for_tensor, save_external_data):
            tensor = make_external_tensor(location)
            try:
                operation(tensor, str(base))
            except (OSError, ValueError):
                pass
            else:
                raise AssertionError("unsafe external data accepted: " + location)
            assert victim.read_bytes() == b"OUTSIDE-FIXTURE"
    assert len(os.listdir("/proc/self/fd")) == count_before, "descriptor leaked on rejection"
    (base / "nested").mkdir()
    normal = make_external_tensor("nested/normal.bin", b"abc")
    save_external_data(normal, str(base))
    assert (base / "nested/normal.bin").read_bytes() == b"abc"
    load_external_data_for_tensor(normal, str(base))
    assert normal.raw_data == b"abc"
    for writing in (False, True):
        race_base = root / ("write-race" if writing else "read-race")
        race_base.mkdir()
        nested = race_base / "nested"
        nested.mkdir()
        (nested / "data.bin").write_bytes(b"INSIDE-FIXTURE")
        held = race_base / "held"
        original_open = os.open

        def racing_open(path, flags, *args, **kwargs):
            descriptor = original_open(path, flags, *args, **kwargs)
            if path == "nested" and "dir_fd" in kwargs:
                nested.rename(held)
                nested.symlink_to(outside, target_is_directory=True)
            return descriptor

        tensor = make_external_tensor("nested/data.bin", b"NEW")
        with patch("os.open", side_effect=racing_open):
            (save_external_data if writing else load_external_data_for_tensor)(tensor, str(race_base))
        assert victim.read_bytes() == b"OUTSIDE-FIXTURE", "path swap escaped anchored directory"
        if writing:
            assert (held / "data.bin").read_bytes() == b"INSIDE-FIXTURENEW"
        else:
            assert tensor.raw_data == b"INSIDE-FIXTURE"
print("ONNX external descriptors: PASS traversal, links, FIFO/directory, fd cleanup, normal IO and parent path swaps")
