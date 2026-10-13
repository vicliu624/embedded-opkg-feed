"""Run the real ORT native-input prefix against an empty imported host stage."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
hook = (source / "packages/libonnxruntime/build.sh").read_text()
boundary = '# Fingerprint declared development providers'
assert hook.count(boundary) == 1
with tempfile.TemporaryDirectory(prefix="tdvp-ort-host-order-") as directory:
    root = Path(directory)
    for name in ("libonnxruntime", "libflatbuffers", "libprotobuf", "libabseil-cpp"):
        (root / "packages" / name).mkdir(parents=True)
    for name in ("scripts", "support", "sdk", "stage"):
        (root / name).mkdir()
    shutil.copy2(source / "packages/libonnxruntime/package.env", root / "packages/libonnxruntime/package.env")
    (root / "sdk/tdvp-sdk-manifest.json").write_text("{}")
    (root / "scripts/feed-platform.sh").write_text('tdvp_assert_package_host_dependencies() { :; }\n')
    for name in ("source-archive-library.sh", "elf-runtime-policy.sh"):
        (root / "support" / name).write_text("# Fixture\n")
    (root / "support/native-cmake-input.sh").write_text('''tdvp_prepare_native_cmake_input() {
  local package=$1 destination=$2 expected=$3
  if [[ "$expected" == bin/protoc ]]; then
    [[ -f "$(dirname "$destination")/abseil/lib/cmake/absl/abslConfig.cmake" ]] || return 77
  fi
  mkdir -p "$destination/$(dirname "$expected")"
  if [[ "$expected" == bin/protoc ]]; then
    printf '#!/bin/sh\\nprintf "libprotoc 29.3\\\\n"\\n' > "$destination/$expected"
    chmod +x "$destination/$expected"
  else
    touch "$destination/$expected"
  fi
  printf '%s\\n' "$(basename "$package")" >> "$TDVP_FIXTURE_NATIVE_LOG"
}
''')
    target = root / "packages/libonnxruntime/build.sh"
    target.write_text(hook.split(boundary)[0])
    log = root / "native.log"
    env = dict(os.environ, TDVP_FEED_STAGING_ROOT=str(root / "stage"), TDVP_FIXTURE_NATIVE_LOG=str(log))
    for name in ("TDVP_NATIVE_CMAKE_CACHE_ROOT", "TDVP_NATIVE_PROTOBUF_ROOT"):
        env.pop(name, None)
    result = subprocess.run(["bash", str(target), "--platform", "tdvp-k230-r1", "--sdk-root", str(root / "sdk")],
                            env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert log.read_text().splitlines() == ["libflatbuffers", "libabseil-cpp", "libprotobuf"]
print("ORT native-input order: PASS empty host stage prepares Abseil before protoc")
