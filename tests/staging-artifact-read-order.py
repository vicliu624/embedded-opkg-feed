"""Bound gzip rewinds independently of timing and verify nested payload bytes."""
import argparse
import gzip
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--size-mib", type=int, default=10)
parser.add_argument("--files", type=int, default=40)
parser.add_argument("--module", type=Path, default=Path(__file__).resolve().parents[1] / "scripts/staging-artifact.py")
args = parser.parse_args()
assert args.size_mib > 0 and args.files > 0
spec = importlib.util.spec_from_file_location("transport", args.module)
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
with tempfile.TemporaryDirectory(prefix="tdvp-staging-read-order-") as temporary:
    base = Path(temporary)
    root = base / "stage"
    root.mkdir()
    for index in range(args.files):
        path = root / "usr" / ("group%04d" % index)
        for depth in range(index % 4):
            path /= "nested"
        path /= "payload"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(os.urandom(args.size_mib * 1048576 // args.files))
        path.chmod(0o644)
    receipt = {"schema": 1, "development_files": transport.inventory(root)}
    (root / "tdvp-build-staging-receipt.json").write_text(json.dumps(receipt))
    archive = base / "stage.tar.gz"
    start = time.monotonic()
    transport.pack(root, archive)
    pack_seconds = time.monotonic() - start
    original_seek = gzip.GzipFile.seek
    counters = {"backwards": 0, "calls": 0}

    def observed_seek(stream, offset, whence=0):
        counters["calls"] += 1
        if whence == 0 and offset < stream.tell():
            counters["backwards"] += 1
        return original_seek(stream, offset, whence)

    gzip.GzipFile.seek = observed_seek
    try:
        start = time.monotonic()
        transport.unpack(archive, base / "restored")
        unpack_seconds = time.monotonic() - start
    finally:
        gzip.GzipFile.seek = original_seek
    assert transport.inventory(base / "restored") == receipt["development_files"]
    print(json.dumps({"files": args.files, "size_mib": args.size_mib, "gzip": counters,
                      "pack_seconds": round(pack_seconds, 3), "unpack_seconds": round(unpack_seconds, 3)}))
    # One rewind is expected after the complete member validation pass.
    # Payload extraction must never add per-file/depth-dependent rewinds.
    assert counters["backwards"] <= 1, "gzip payload reads repeatedly rewind"
print("staging-artifact-read-order: PASS")
