import sys
from pathlib import Path
import flatbuffers
from flatbuffers import encode, packer, table, number_types
from google.protobuf import struct_pb2
from google.protobuf.internal import api_implementation
from google.protobuf.message import DecodeError
from packaging.version import Version
from packaging.markers import Marker
from typing_extensions import TypeIs

assert api_implementation.Type() == "upb", "native protobuf extension was not loaded"
message = struct_pb2.Struct()
message.update({"counter": 42, "label": "tdvp", "nested": {"ok": True}})
wire = message.SerializeToString()
copy = struct_pb2.Struct.FromString(wire)
assert copy == message
try:
    struct_pb2.Struct.FromString(b"\xff")
except DecodeError:
    pass
else:
    raise AssertionError("malformed protobuf was accepted")
if len(sys.argv) == 2:
    Path(sys.argv[1]).write_bytes(wire)

builder = flatbuffers.Builder(64)
label = builder.CreateString("tdvp")
builder.StartObject(2)
builder.PrependInt32Slot(0, 42, 0)
builder.PrependUOffsetTRelativeSlot(1, label, 0)
root = builder.EndObject()
builder.Finish(root, file_identifier=b"TDVP")
buffer = builder.Output()
assert bytes(buffer[4:8]) == b"TDVP"
record = table.Table(buffer, encode.Get(packer.uoffset, buffer, 0))
assert record.Get(number_types.Int32Flags, record.Pos + record.Offset(4)) == 42
assert record.String(record.Pos + record.Offset(6)) == b"tdvp"
assert Version("1.2rc1") < Version("1.2")
assert Marker("python_version >= '3.13'").evaluate({"python_version": "3.13"})
assert TypeIs is not None
print("Python native upb, malformed-message rejection, FlatBuffers roundtrip and package utilities: PASS")
