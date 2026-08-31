#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
env_file="$repo_root/packages/tdvp-dev-tools/package.env"
grep -Fqx "PACKAGE='tdvp-dev-tools'" "$env_file"
grep -Fqx "PACKAGE_RELEASES='r9 r10'" "$env_file"
grep -Fqx "PACKAGE_DEPENDS='archive-tools (= 1.0-1), git (= 2.48.1-1), gh (= 2.98.0-1), python3 (= 3.13.3-1), vim (= 9.1.0145-1), make (= 4.4.1-1), pkgconf (= 2.3.0-1), patch (= 2.7.6-1), diffutils (= 3.10-1), strace (= 6.13-1)'" "$env_file"
grep -Fq 'independently versioned' "$repo_root/packages/tdvp-dev-tools/README"
