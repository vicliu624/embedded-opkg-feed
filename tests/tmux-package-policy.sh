#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for package in libevent tmux; do test -f "$repo_root/packages/$package/source.lock"; done
grep -Fqx "PACKAGE='libevent'" "$repo_root/packages/libevent/package.env"
grep -Fqx "PACKAGE_KIND='shared-library'" "$repo_root/packages/libevent/package.env"
grep -Fqx "PACKAGE='tmux'" "$repo_root/packages/tmux/package.env"
grep -Fqx "PACKAGE_DEPENDS='libevent (= 2.1.12-1), libncursesw (= 6.4-20230603-1)'" "$repo_root/packages/tmux/package.env"
grep -Fq "'libevent*.so.7*'" "$repo_root/packages/libevent/build.sh"
grep -Fq 'BR2_PACKAGE_OPENSSL' "$repo_root/packages/libevent/build.sh"
grep -Fq "LIBEVENT_CONF_OPTS=--disable-libevent-regress --disable-samples --disable-openssl" "$repo_root/packages/libevent/build.sh"
grep -Fq "LIBEVENT_DEPENDENCIES='" "$repo_root/packages/libevent/build.sh"
grep -Fq 'archive-library --make-variable requires one safe NAME=value assignment' "$repo_root/support/buildroot-archive-library.sh"
grep -Fq 'libevent OpenSSL support are excluded' "$repo_root/packages/tmux/source.lock"
grep -Fq 'BR2_USE_MMU=y BR2_USE_WCHAR=y BR2_ENABLE_LOCALE=y BR2_PACKAGE_NCURSES=y' "$repo_root/packages/tmux/build.sh"
grep -Fq 'BR2_PACKAGE_OPENSSL BR2_PACKAGE_SYSTEMD BR2_PACKAGE_UTF8PROC' "$repo_root/packages/tmux/build.sh"
grep -Fq "'tmux'" "$repo_root/packages/tmux/build.sh"
grep -Fqx 'libevent-2.1.so.7|libevent|2.1.12-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
grep -Fqx 'libevent_pthreads-2.1.so.7|libevent|2.1.12-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
echo 'locked-source libevent/tmux policy: PASS'
