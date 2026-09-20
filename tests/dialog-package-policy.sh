#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grep -Fqx "PACKAGE='dialog'" "$repo_root/packages/dialog/package.env"
grep -Fqx "PACKAGE_DEPENDS='libncursesw (= 6.4-20230603-1)'" "$repo_root/packages/dialog/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$repo_root/packages/dialog/package.env"
grep -Fqx "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libncursesw'" "$repo_root/packages/dialog/package.env"
grep -Fqx "PACKAGE_SDK_DEVELOPMENT_FILES='usr/include/curses.h usr/lib/pkgconfig/ncursesw.pc usr/lib/libncursesw.so'" "$repo_root/packages/libncursesw/package.env"
grep -Fqx 'PACKAGE_SOURCE_STAGING=0' "$repo_root/packages/libncursesw/package.env"
grep -Fq 'BR2_USE_MMU=y BR2_ENABLE_LOCALE=y BR2_PACKAGE_NCURSES=y' "$repo_root/packages/dialog/build.sh"
grep -Fq 'DIALOG_VERSION = 1.3-20220117' "$repo_root/packages/dialog/build.sh"
grep -Fq 'dialog) options+=(--with-curses-lib=ncursesw) ;;' "$repo_root/support/published-sdk-build.sh"
grep -Fq 'does not select the optional libiconv closure' "$repo_root/packages/dialog/source.lock"
grep -Fq "SOURCE_ARTIFACT_2_FILE='pkgconf-2.3.0.tar.xz'" "$repo_root/packages/dialog/source.lock"
echo 'locked-source dialog policy: PASS'
