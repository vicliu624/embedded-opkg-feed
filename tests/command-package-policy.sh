#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for package in make pkgconf patch diffutils strace; do
  env_file="$repo_root/packages/$package/package.env"
  grep -Fqx "PACKAGE='$package'" "$env_file"
  grep -Fqx "PACKAGE_RELEASES='r9 r10'" "$env_file"
  grep -Fq 'tdvp_buildroot_command_package' "$repo_root/packages/$package/build.sh"
done
grep -Fq '/usr/libexec/tdvp-' "$repo_root/support/buildroot-command-package.sh"
grep -Fq 'BR2_PACKAGE_BUSYBOX_SHOW_OTHERS' "$repo_root/support/buildroot-command-package.sh"
grep -Fq "'pkgconf pkg-config'" "$repo_root/packages/pkgconf/build.sh"
grep -Fq "'diff cmp diff3 sdiff'" "$repo_root/packages/diffutils/build.sh"
