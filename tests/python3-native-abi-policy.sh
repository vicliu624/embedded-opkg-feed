#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# These payloads contain CPython 3.13 native extensions, regardless of whether
# their build helper currently records PACKAGE_PYTHON_NATIVE.
for name in numpy scipy pillow opencv onnx onnxruntime cffi protobuf pyyaml; do
  source "$repo_root/packages/python3-$name/package.env"
  [[ "$PACKAGE_DEPENDS" == 'python3 (>= 3.13.3-2), python3 (<< 3.14~)'* ]] || {
    echo "python3-$name lacks the CPython 3.13 native ABI boundary" >&2
    exit 1
  }
done
# All wheel-helper native recipes must be covered, including future additions.
for recipe in "$repo_root"/packages/python3-*/package.env; do
  unset PACKAGE_PYTHON_NATIVE
  source "$recipe"
  if [[ ${PACKAGE_PYTHON_NATIVE:-0} == 1 ]]; then
    [[ "$PACKAGE_DEPENDS" == *'python3 (<< 3.14~)'* ]] || {
      echo "$PACKAGE native recipe permits a different CPython minor ABI" >&2
      exit 1
    }
  fi
done
grep -Fxq 'Requires-Dist: onnx==1.17.0' "$repo_root/packages/python3-onnxruntime/files/METADATA"
echo 'Native CPython minor ABI boundaries and ORT ONNX dependency metadata: PASS'
