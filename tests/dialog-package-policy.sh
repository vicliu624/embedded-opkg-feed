#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grep -Fqx "PACKAGE='dialog'" "$repo_root/packages/dialog/package.env"
grep -Fqx "PACKAGE_DEPENDS='libncursesw (= 6.4-20230603-1)'" "$repo_root/packages/dialog/package.env"
grep -Fq 'BR2_USE_MMU=y BR2_ENABLE_LOCALE=y BR2_PACKAGE_NCURSES=y' "$repo_root/packages/dialog/build.sh"
grep -Fq 'DIALOG_VERSION = 1.3-20220117' "$repo_root/packages/dialog/build.sh"
grep -Fq 'does not select the optional libiconv closure' "$repo_root/packages/dialog/source.lock"
grep -Fq "SOURCE_ARTIFACT_2_FILE='pkgconf-2.3.0.tar.xz'" "$repo_root/packages/dialog/source.lock"
echo 'locked-source dialog policy: PASS'
