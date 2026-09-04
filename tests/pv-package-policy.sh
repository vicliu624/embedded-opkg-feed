#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/packages/pv/package.env"
grep -Fqx "PACKAGE='pv'" "$env_file"
grep -Fqx "VERSION='1.9.0-1'" "$env_file"
grep -Fqx "PACKAGE_DEPENDS=''" "$env_file"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$env_file"
grep -Fq 'PV_VERSION = 1.9.0' "$repo_root/packages/pv/build.sh"
grep -Fq "'pv'" "$repo_root/packages/pv/build.sh"
grep -Fq 'no optional target runtime or host helper archive closure' "$repo_root/packages/pv/source.lock"
test -f "$repo_root/packages/pv/source.lock"
echo 'locked-source bounded pv policy: PASS'
