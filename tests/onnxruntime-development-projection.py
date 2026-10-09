"""Check portable core development projection identity and corruption gates."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/onnxruntime-development-export.py"
with tempfile.TemporaryDirectory(prefix="tdvp-ort-development-policy-") as directory:
    root = Path(directory)
    for name in ("sdk", "package", "core/build", "core/source/ort/include", "core/source/ort/onnxruntime/python"):
        (root / name).mkdir(parents=True)
    sdk = root / "sdk/tdvp-sdk-manifest.json"
    sdk.write_text('{"fixture":1}\n')
    lock = root / "package/source.lock"
    lock.write_text("UPSTREAM_VERSION='1.21.0'\n")
    source = root / "core/source/ort"
    (source / "LICENSE").write_text("Fixture notice\n")
    (source / "ThirdPartyNotices.txt").write_text("Fixture third-party notice\n")
    (source / "include/fixture.h").write_text("int fixture;\n")
    (root / "core/.prepared").write_text(str(source) + "\n")
    cache = root / "core/build/CMakeCache.txt"
    cache.write_text("onnxruntime_DISABLE_RTTI:BOOL=OFF\n")
    for component in "session optimizer providers lora framework graph util mlas common flatbuffers".split():
        (root / ("core/build/libonnxruntime_" + component + ".a")).write_bytes(b"fixture archive")
    (root / "core/build/unrelated.o").write_bytes(b"not exported")
    record = root / "core.json"
    record.write_text(json.dumps({"schema": 1, "rtti": True, "work": str(root / "core"),
                                 "sdk_manifest_sha256": hashlib.sha256(sdk.read_bytes()).hexdigest()}))
    common = ["--sdk", str(root / "sdk"), "--package", str(root / "package")]
    export = [sys.executable, str(script), "export", str(root / "export"), *common, "--core-record", str(record)]
    verify = [sys.executable, str(script), "verify", str(root / "export"), *common]
    assert subprocess.run(export, capture_output=True).returncode == 0
    assert not (root / "export/build/unrelated.o").exists()
    assert (root / "export/source/ThirdPartyNotices.txt").read_text() == "Fixture third-party notice\n"
    assert subprocess.run(verify, capture_output=True).returncode == 0
    assert subprocess.run(export, capture_output=True).returncode != 0
    sdk.write_text('{"fixture":2}\n')
    assert subprocess.run(verify, capture_output=True).returncode != 0
    sdk.write_text('{"fixture":1}\n')
    original_lock = lock.read_bytes()
    lock.write_text("UPSTREAM_VERSION='other'\n")
    assert subprocess.run(verify, capture_output=True).returncode != 0
    lock.write_bytes(original_lock)
    target = root / "export/source/include/fixture.h"
    original = target.read_bytes()
    target.write_bytes(b"tampered")
    assert subprocess.run(verify, capture_output=True).returncode != 0
    target.write_bytes(original)
    extra = root / "export/build/extra.a"
    extra.write_bytes(b"unexpected")
    assert subprocess.run(verify, capture_output=True).returncode != 0
    extra.unlink()
    target.unlink()
    assert subprocess.run(verify, capture_output=True).returncode != 0
print("ORT development projection policy: PASS identity, corruption, missing/extra files, overwrite and object exclusion")
