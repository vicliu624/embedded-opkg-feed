#!/usr/bin/env bash
# Build/run upstream internal protocol tests; leaves published runtime IPKs unchanged.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 2 && $1 == --sdk-root ]] || exit 64
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sdk_root=$(realpath -e -- "$2")
[[ -f "$sdk_root/tdvp-sdk-manifest.json" && -f "$sdk_root/environment-setup.sh" ]] || exit 65
source "$repo_root/support/source-archive-library.sh"
archive=$(tdvp_source_archive_locked_file "$repo_root/packages/libnghttp3")
task_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-nghttp3-protocol.XXXXXXXX")
printf 'Upstream protocol test artifacts: %s\n' "$task_root"
tar -xf "$archive" -C "$task_root"
source "$sdk_root/environment-setup.sh"
cmake -S "$task_root/nghttp3-1.18.0" -B "$task_root/build" -G Ninja \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_SYSROOT="$sdk_root/sysroot" -DCMAKE_FIND_ROOT_PATH="$sdk_root/sysroot" \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_C_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
  -DCMAKE_C_FLAGS="$CFLAGS -O1" -DENABLE_LIB_ONLY=ON -DENABLE_STATIC_LIB=ON \
  -DENABLE_SHARED_LIB=OFF -DBUILD_TESTING=ON > "$task_root/configure.log" 2>&1
cmake --build "$task_root/build" --target main -j2 > "$task_root/build.log" 2>&1
python3 "$repo_root/scripts/verify-published-sdk-payload.py" "$sdk_root" "$task_root/build/tests"
timeout 60 qemu-riscv64 -L "$sdk_root/sysroot" "$task_root/build/tests/main" > "$task_root/protocol-suite.log" 2>&1
tail -6 "$task_root/protocol-suite.log"
grep -Fq '61 of 61 (100%) tests successful, 0 (0%) test skipped.' "$task_root/protocol-suite.log"
echo 'Upstream nghttp3 internal protocol suite: PASS; HTTP3 network acceptance remains separate'
