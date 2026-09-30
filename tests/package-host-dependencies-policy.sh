#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/scripts/feed-platform.sh"
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
printf "PACKAGE_HOST_DEPENDS='bash sh'\n" > "$fixture/package.env"
tdvp_assert_package_host_dependencies "$fixture"
[[ "$IFS" == $'\n\t' ]]
printf "PACKAGE_HOST_DEPENDS='tdvp_nonexistent_host_tool_20260930'\n" > "$fixture/package.env"
if tdvp_assert_package_host_dependencies "$fixture"; then
  echo 'missing host tool was accepted' >&2
  exit 1
else
  [[ "$?" == 78 ]]
fi
printf "PACKAGE_HOST_DEPENDS='../bash'\n" > "$fixture/package.env"
if tdvp_assert_package_host_dependencies "$fixture"; then
  echo 'invalid tool path was accepted' >&2
  exit 1
fi
printf "PACKAGE='legacy-fixture'\n" > "$fixture/package.env"
tdvp_assert_package_host_dependencies "$fixture"
echo 'package-host-dependencies-policy: PASS'
