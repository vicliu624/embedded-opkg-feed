#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 1 ]] || exit 64
sdk_root=$1
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/packages/libcjson/package.env"
source "$repo_root/support/cmake-source-library.sh"
stage=$(mktemp -d /tmp/tdvp-cmake-subdir-policy.XXXXXX)
trap 'rm -rf -- "$stage"' EXIT
export TDVP_FEED_STAGING_ROOT="$stage"
for invalid in '../outside' '/tmp' 'contrib/../../outside' '.'; do
  export PACKAGE_CMAKE_SUBDIR="$invalid"
  if tdvp_build_cmake_source_library "$repo_root/packages/libcjson" "$sdk_root" 'libcjson.so*'; then
    echo "accepted unsafe CMake subdirectory: $invalid" >&2
    exit 1
  else
    rc=$?
    [[ $rc -eq 69 ]] || { echo "unexpected rejection code: $rc" >&2; exit 1; }
  fi
done
unset PACKAGE_CMAKE_SUBDIR
tdvp_build_cmake_source_library "$repo_root/packages/libcjson" "$sdk_root" 'libcjson*.so*' \
  -DENABLE_CJSON_TEST=OFF -DENABLE_CUSTOM_COMPILER_FLAGS=OFF \
  -DENABLE_CJSON_UTILS=ON -DBUILD_SHARED_AND_STATIC_LIBS=OFF
echo 'CMake source subdirectory rejection and default build: PASS'
