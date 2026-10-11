#!/usr/bin/env bash
# Prepare the source-locked native interpreter and an offline pinned build venv.
set -Eeuo pipefail
[[ $# -eq 3 ]] || {
  echo 'usage: prepare-ai-python-host.sh <native-prefix> <new-venv> <verified-wheelhouse>' >&2
  exit 64
}
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || {
  echo 'AI package host requires native Linux x86_64' >&2; exit 65;
}
for variable in CC CXX AR CFLAGS CXXFLAGS CPPFLAGS LDFLAGS PKG_CONFIG_SYSROOT_DIR _PYTHON_SYSCONFIGDATA_NAME _PYTHON_HOST_PLATFORM PYTHONHOME PYTHONPATH; do
  [[ -z ${!variable:-} ]] || {
    echo "prepare native host before activating target environment: $variable is set" >&2
    exit 66
  }
done
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
native=$(realpath -m -- "$1")
venv=$(realpath -m -- "$2")
wheelhouse=$(realpath -e -- "$3")
[[ ! -e "$venv" && ! -L "$venv" && "$native" != "$venv" ]] || {
  echo "refusing to overwrite venv: $venv" >&2; exit 67;
}
[[ -d "$wheelhouse" ]] || { echo 'wheelhouse must be a directory' >&2; exit 68; }
fingerprint=$(python3 - "$repo_root/packages/python3/source.lock" "$native" <<'PY'
import hashlib, json, platform, subprocess, sys
from pathlib import Path
print(json.dumps({"schema": 1, "policy": "tdvp-ai-native-python-v1",
                  "source_lock_sha256": hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest(),
                  "prefix": sys.argv[2], "machine": platform.machine(),
                  "os": platform.freedesktop_os_release(),
                  "compiler": subprocess.check_output(["cc", "--version"], text=True)}, sort_keys=True))
PY
)
marker="$native/.tdvp-ai-native-source.json"
if [[ -e "$native" || -L "$native" ]]; then
  [[ -f "$marker" && ! -L "$marker" && $(< "$marker") == "$fingerprint" ]] || {
    echo 'native prefix has no matching source/host fingerprint; choose a new prefix' >&2
    exit 69
  }
  [[ -x "$native/bin/python3.13" ]] || { echo 'cached native interpreter is missing' >&2; exit 70; }
else
  mkdir -p -- "$(dirname -- "$native")"
  source "$repo_root/support/published-native-inputs.sh"
  tdvp_sdk_host_python "$repo_root/packages/python3" "$native"
fi
"$native/bin/python3.13" - <<'PY'
import bz2, ctypes, lzma, platform, ssl, sys, zlib
assert sys.version_info[:3] == (3, 13, 3), sys.version
assert platform.machine() == "x86_64", platform.machine()
print("Native Python 3.13.3 standard-library closure: PASS")
PY
# This is a generated build-output marker, never a repository source edit.
printf '%s\n' "$fingerprint" > "$marker"
"$native/bin/python3.13" -m venv "$venv"
"$venv/bin/python3" -m pip install --no-index --find-links="$wheelhouse" \
  --only-binary=:all: --require-hashes -r "$repo_root/support/python-wheel-host-requirements.txt"
PATH="$venv/bin:$PATH" "$venv/bin/python3" "$repo_root/scripts/verify-ai-python-host.py"
printf 'Verified AI Python host: %s\n' "$venv"
