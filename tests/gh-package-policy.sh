#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/packages/gh/package.env"
grep -Fqx "PACKAGE='gh'" "$env_file"
grep -Fqx "PACKAGE_RELEASES='r9'" "$env_file"
grep -Fqx "PACKAGE_AUTO_RUNTIME_DEPENDS=0" "$env_file"
grep -Fq "PACKAGE_DEPENDS='git (= 2.48.1-1), ca-certificates (= 2025.02.1-1)'" "$env_file"
grep -Fq 'GOOS=linux GOARCH=riscv64 CGO_ENABLED=0' "$repo_root/packages/gh/build.sh"
grep -Fq 'github.com/cli/cli/archive/$SOURCE_REVISION.tar.gz' "$repo_root/packages/gh/build.sh"
grep -Fq 'Shared library:' "$repo_root/packages/gh/build.sh"
if grep -Eq '(releases/download|\.deb|\.rpm)' "$repo_root/packages/gh/build.sh"; then
  echo 'gh recipe must not download a prebuilt package' >&2
  exit 1
fi
