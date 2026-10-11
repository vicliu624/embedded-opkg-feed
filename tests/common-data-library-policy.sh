#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
for name in libjsoncpp libpugixml libtinyxml2 libxxhash; do
  source "$repo_root/packages/$name/package.env"
  [[ "$PACKAGE" == "$name" && "$PACKAGE_KIND" == shared-library && "$PACKAGE_ARCH" == riscv64 ]]
  [[ "$PACKAGE_AUTO_RUNTIME_DEPENDS" == 1 && "$PACKAGE_BASE_OVERLAY" == deny ]]
  [[ " $PACKAGE_HOST_DEPENDS " == *' cmake '* && " $PACKAGE_HOST_DEPENDS " == *' ninja '* ]]
  grep -Fq 'tdvp_build_cmake_source_library' "$repo_root/packages/$name/build.sh"
  bash -n "$repo_root/packages/$name/build.sh"
  bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$repo_root/packages/$name"
done
grep -Fq -- '-DPUGIXML_NO_XPATH=OFF' "$repo_root/packages/libpugixml/build.sh"
grep -Fq -- '-DBUILD_STATIC_LIBS=OFF' "$repo_root/packages/libjsoncpp/build.sh"
grep -Fq -- '-DXXHASH_BUILD_XXHSUM=OFF' "$repo_root/packages/libxxhash/build.sh"
echo 'Common JSON/XML/hash shared runtime recipe and locked source policy: PASS'
