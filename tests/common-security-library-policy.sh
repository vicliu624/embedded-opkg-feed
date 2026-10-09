#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
for name in libsodium libseccomp; do
  source "$repo_root/packages/$name/package.env"
  [[ "$PACKAGE" == "$name" && "$PACKAGE_KIND" == shared-library && "$PACKAGE_ARCH" == riscv64 ]]
  [[ "$PACKAGE_AUTO_RUNTIME_DEPENDS" == 1 && "$PACKAGE_BASE_OVERLAY" == deny ]]
  [[ " $PACKAGE_HOST_DEPENDS " == *' make '* && " $PACKAGE_HOST_DEPENDS " == *' gcc '* ]]
  grep -Fq 'tdvp_assert_package_host_dependencies' "$repo_root/packages/$name/build.sh"
  grep -Fq 'tdvp_build_direct_archive_library' "$repo_root/packages/$name/build.sh"
  bash -n "$repo_root/packages/$name/build.sh"
  bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$repo_root/packages/$name"
done
source "$repo_root/packages/libseccomp/package.env"
[[ " $PACKAGE_HOST_DEPENDS " == *' gperf '* ]]
grep -Fq -- '--disable-minimal' "$repo_root/packages/libsodium/build.sh"
echo 'Common security shared runtime recipe and locked source policy: PASS'
