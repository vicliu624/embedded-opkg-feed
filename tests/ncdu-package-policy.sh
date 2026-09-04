#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grep -Fqx "PACKAGE='ncdu'" "$repo_root/packages/ncdu/package.env"
grep -Fqx "PACKAGE_DEPENDS='libncursesw (= 6.4-20230603-1)'" "$repo_root/packages/ncdu/package.env"
grep -Fq 'BR2_USE_MMU=y BR2_PACKAGE_NCURSES=y' "$repo_root/packages/ncdu/build.sh"
grep -Fq "SOURCE_ARTIFACT_2_FILE='pkgconf-2.3.0.tar.xz'" "$repo_root/packages/ncdu/source.lock"
echo 'locked-source ncdu policy: PASS'
