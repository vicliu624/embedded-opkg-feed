#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grep -Fqx "PACKAGE='ncdu'" "$repo_root/packages/ncdu/package.env"
grep -Fqx "PACKAGE_DEPENDS='libncursesw-6 (= 2025.02.1-1)'" "$repo_root/packages/ncdu/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$repo_root/packages/ncdu/package.env"
grep -Fqx "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libncursesw-6'" "$repo_root/packages/ncdu/package.env"
grep -Fq 'BR2_USE_MMU=y BR2_PACKAGE_NCURSES=y' "$repo_root/packages/ncdu/build.sh"
grep -Fq "SOURCE_ARTIFACT_2_FILE='pkgconf-2.3.0.tar.xz'" "$repo_root/packages/ncdu/source.lock"
echo 'locked-source ncdu policy: PASS'
