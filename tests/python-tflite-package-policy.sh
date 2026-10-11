#!/usr/bin/env bash
set -Eeuo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$repo/packages/python3-tflite-runtime/package.env"
[[ "$PACKAGE" == python3-tflite-runtime && "$PACKAGE_KIND" == runtime && "$PACKAGE_PYTHON_NATIVE" == 1 ]]
[[ "$PACKAGE_DEPENDS" == *'python3 (<< 3.14~)'* && "$PACKAGE_DEPENDS" == *'python3-numpy (<< 3~)'* ]]
[[ "$PACKAGE_DEPENDS" == *'libtensorflow-lite (= 2.18.0-1)'* ]]
[[ " $PACKAGE_BUILD_DEPENDS " == *' libtensorflow-lite '* && " $PACKAGE_BUILD_DEPENDS " == *' pybind11-dev '* ]]
source "$repo/packages/libtensorflow-lite/source.lock"
core_sha=$SOURCE_ARTIFACT_1_SHA256
source "$repo/packages/python3-tflite-runtime/source.lock"
[[ "$SOURCE_ARTIFACT_1_SHA256" == "$core_sha" ]]
bash -n "$repo/packages/python3-tflite-runtime/build.sh"
bash "$repo/scripts/verify-source-lock.sh" --package-dir "$repo/packages/python3-tflite-runtime"
grep -Fq 'metrics_interface.py' "$repo/packages/python3-tflite-runtime/build.sh"
grep -Fq 'metrics_portable.py' "$repo/packages/python3-tflite-runtime/build.sh"
grep -Fq -- '-Wl,--no-undefined' "$repo/support/python-tflite-binding/CMakeLists.txt"
! grep -Fq 'packages/libtensorflow-lite/build.sh' "$repo/packages/python3-tflite-runtime/build.sh"
echo 'TFLite Python shared-core source, native ABI and runtime module policy: PASS'
