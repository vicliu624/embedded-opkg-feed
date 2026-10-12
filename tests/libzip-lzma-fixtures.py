"""Create small ZIP inputs with normal and oversized declared LZMA dictionaries."""
import argparse
from pathlib import Path
import struct
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("output", type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
normal = args.output / "host-lzma.zip"
with zipfile.ZipFile(normal, "w", compression=zipfile.ZIP_LZMA) as archive:
    archive.writestr("payload.txt", b"TDVP LZMA bounded decoder test")
data = bytearray(normal.read_bytes())
assert data[:4] == b"PK\x03\x04"
assert struct.unpack_from("<H", data, 8)[0] == zipfile.ZIP_LZMA
name_length, extra_length = struct.unpack_from("<HH", data, 26)
offset = 30 + name_length + extra_length
assert struct.unpack_from("<H", data, offset + 2)[0] == 5
# ZIP LZMA has a four-byte wrapper, then lc/lp/pb and dictionary properties.
assert struct.unpack_from("<I", data, offset + 5)[0] < 67108864
struct.pack_into("<I", data, offset + 5, 134217728)
(args.output / "oversized-lzma.zip").write_bytes(data)
# Prove the changed dictionary declaration is valid data, not a malformed
# archive: an independent unbounded host decoder returns the original bytes.
with zipfile.ZipFile(args.output / "oversized-lzma.zip") as archive:
    assert archive.read("payload.txt") == b"TDVP LZMA bounded decoder test"
print("ZIP LZMA fixtures: normal archive and 128 MiB declared dictionary")
