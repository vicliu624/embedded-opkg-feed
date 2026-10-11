"""Exercise real source-built protoc and flatc without target libraries."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("native_root", type=Path)
args = parser.parse_args()
native = args.native_root.resolve(strict=True)
protoc = native / "protobuf/bin/protoc"
flatc = native / "flatbuffers/bin/flatc"
assert subprocess.check_output([str(protoc), "--version"], text=True).strip() == "libprotoc 29.3"
assert subprocess.check_output([str(flatc), "--version"], text=True).strip() == "flatc version 24.12.23"
with tempfile.TemporaryDirectory(prefix="tdvp-native-schema-") as directory:
    root = Path(directory)
    proto = root / "sample.proto"
    proto.write_text('syntax = "proto3"; package fixture; message Sample { int32 value = 1; string label = 2; }\n')
    subprocess.run([str(protoc), "-I", str(root), "--cpp_out=" + str(root),
                    "--descriptor_set_out=" + str(root / "sample.pb"), str(proto)], check=True)
    assert (root / "sample.pb.h").stat().st_size > 0
    assert (root / "sample.pb.cc").stat().st_size > 0
    assert (root / "sample.pb").stat().st_size > 0
    encoded = subprocess.check_output([str(protoc), "-I", str(root), "--encode=fixture.Sample", str(proto)],
                                      input=b'value: 42\nlabel: "fixture"\n')
    decoded = subprocess.check_output([str(protoc), "-I", str(root), "--decode=fixture.Sample", str(proto)], input=encoded)
    assert b"value: 42" in decoded and b'label: "fixture"' in decoded
    schema = root / "sample.fbs"
    schema.write_text('namespace fixture; table Sample { value:int; label:string; } root_type Sample;\n')
    data = root / "sample.json"
    data.write_text(json.dumps({"value": 42, "label": "fixture"}))
    subprocess.run([str(flatc), "--cpp", "--binary", "-o", str(root), str(schema), str(data)], check=True)
    assert (root / "sample_generated.h").stat().st_size > 0
    decoded_root = root / "decoded"
    decoded_root.mkdir()
    subprocess.run([str(flatc), "--json", "--strict-json", "--raw-binary", "-o", str(decoded_root),
                    str(schema), "--", str(root / "sample.bin")], check=True)
    assert json.loads((decoded_root / "sample.json").read_text()) == {"value": 42, "label": "fixture"}
print("Actual native schemas: PASS protoc descriptor/C++/encode/decode and flatc C++/binary/JSON roundtrip")
