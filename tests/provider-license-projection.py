"""Verify provider lock identity, version, paths, digests and idempotence."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / "support/install-provider-licenses.py"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    provider = root / "notices"
    core = root / "core"
    package = root / "consumer"
    payload = root / "payload"
    for path in (provider, core, package, payload):
        path.mkdir()
    lock = b"UPSTREAM_LICENSE='Apache-2.0'\nUPSTREAM_VERSION='1.0'\nSOURCE_ARTIFACT_1_SHA256='fixture'\n"
    (core / "package.env").write_text("PACKAGE='core'\n")
    (core / "source.lock").write_bytes(lock)
    (package / "package.env").write_text("PACKAGE='consumer'\n")
    (package / "source.lock").write_bytes(lock)
    notice = b"Fixture source license text\n"
    (provider / "LICENSE").write_bytes(notice)
    origin = {"schema": 1, "package": "core", "declared_license": "Apache-2.0",
              "source_lock_sha256": hashlib.sha256(lock).hexdigest(),
              "source": {"UPSTREAM_VERSION": "1.0", "SOURCE_ARTIFACT_1_SHA256": "fixture"},
              "notice_sha256": {"LICENSE": hashlib.sha256(notice).hexdigest()}}
    (provider / "SOURCE.json").write_text(json.dumps(origin))
    command = [sys.executable, str(script), str(provider), str(package), str(payload),
               "--provider-package", str(core)]
    subprocess.run(command, check=True, capture_output=True)
    subprocess.run(command, check=True, capture_output=True)
    for key, value in (("package", "other"), ("source_lock_sha256", "0" * 64)):
        changed = dict(origin, **{key: value})
        (provider / "SOURCE.json").write_text(json.dumps(changed))
        assert subprocess.run(command, capture_output=True).returncode != 0
    (provider / "SOURCE.json").write_text(json.dumps(origin))
    (package / "source.lock").write_bytes(lock.replace(b"'1.0'", b"'2.0'"))
    assert subprocess.run(command, capture_output=True).returncode != 0
    (package / "source.lock").write_bytes(lock)
    (provider / "LICENSE").write_bytes(b"tampered")
    assert subprocess.run(command, capture_output=True).returncode != 0
    (provider / "LICENSE").write_bytes(notice)
    for relative in ("../outside", "/etc/passwd"):
        changed = dict(origin, notice_sha256={relative: hashlib.sha256(notice).hexdigest()})
        (provider / "SOURCE.json").write_text(json.dumps(changed))
        assert subprocess.run(command, capture_output=True).returncode != 0
print("Provider license regression: PASS identity, lock, version, digest, path and idempotence")
