"""Run the real binding selection prefix and prove valid core export skips build."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
hook = (repo / "packages/python3-onnxruntime/build.sh").read_text()
boundary = 'source "$package_dir/source.lock"'
assert boundary in hook
with tempfile.TemporaryDirectory(prefix="tdvp-ort-binding-reuse-") as directory:
    root = Path(directory)
    for name in ("scripts", "support", "packages/libonnxruntime", "packages/python3-onnxruntime", "sdk", "stage"):
        (root / name).mkdir(parents=True)
    shutil.copy2(repo / "scripts/onnxruntime-development-export.py", root / "scripts/onnxruntime-development-export.py")
    (root / "scripts/feed-platform.sh").write_text('tdvp_assert_package_host_dependencies() { :; }\n')
    for name in ("source-archive-library.sh", "elf-runtime-policy.sh"):
        (root / "support" / name).write_text("# Fixture\n")
    sdk = root / "sdk/tdvp-sdk-manifest.json"
    sdk.write_text("{}\n")
    lock = root / "packages/libonnxruntime/source.lock"
    lock.write_text("UPSTREAM_VERSION='1.21.0'\n")
    core = root / "stage/usr/share/tdvp-build/onnxruntime"
    (core / "source").mkdir(parents=True)
    license_file = core / "source/LICENSE"
    license_file.write_text("Fixture notice\n")
    manifest = {"schema": 1, "kind": "onnxruntime-binding-development", "rtti": True,
                "sdk_manifest_sha256": hashlib.sha256(sdk.read_bytes()).hexdigest(),
                "source_lock_sha256": hashlib.sha256(lock.read_bytes()).hexdigest(),
                "files": {"source/LICENSE": hashlib.sha256(license_file.read_bytes()).hexdigest()}}
    (core / "manifest.json").write_text(json.dumps(manifest))
    log = root / "core-build.log"
    (root / "packages/libonnxruntime/build.sh").write_text('printf "called\\n" >> "$TDVP_FIXTURE_CORE_LOG"\nexit 99\n')
    target = root / "packages/python3-onnxruntime/build.sh"
    target.write_text(hook.split(boundary)[0])
    command = ["bash", str(target), "--platform", "tdvp-k230-r1", "--sdk-root", str(root / "sdk")]
    env = dict(os.environ, TDVP_FEED_STAGING_ROOT=str(root / "stage"), TDVP_FIXTURE_CORE_LOG=str(log))
    result = subprocess.run(command, env=env, capture_output=True)
    assert result.returncode == 0, result.stderr
    assert not log.exists(), "valid development projection rebuilt core"
    license_file.write_text("tampered")
    result = subprocess.run(command, env=env, capture_output=True)
    assert result.returncode != 0 and b"bytes differ" in result.stderr
    assert not log.exists(), "corrupt projection silently rebuilt core"
    shutil.move(core, root / "saved-projection")
    result = subprocess.run(command, env=env, capture_output=True)
    assert result.returncode == 99 and log.read_text().strip() == "called"
print("Actual ORT binding selection: PASS core-build skip, corrupt input rejection, missing input preparation")
