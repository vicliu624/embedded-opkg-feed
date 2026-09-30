#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for package in libyaml-0-2 libmxml-1 libmicrohttpd-12 libubootenv-0; do
  (
    source "$repo_root/packages/$package/package.env"
    [[ "$PACKAGE" == "$package" && "$VERSION" == 2025.02.1-2 ]]
    [[ "$PACKAGE_KIND" == shared-library && "$PACKAGE_AUTO_RUNTIME_DEPENDS" == 1 ]]
    [[ "$PACKAGE_BASE_OVERLAY" == deny ]]
    bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$repo_root/packages/$package"
    [[ "$package" != libubootenv-0 ]] || {
      [[ "$PACKAGE_BUILD_DEPENDS" == 'libyaml-0-2 libz' ]]
      [[ " $PACKAGE_HOST_DEPENDS " == *' cmake '* ]]
    }
  )
done
if [[ -n "${TDVP_TEST_OPKG:-}" ]]; then
  "$TDVP_TEST_OPKG" compare-versions 2025.02.1-2 '>>' 2025.02.1-1
fi
echo 'historical-library-migration-policy: PASS'
