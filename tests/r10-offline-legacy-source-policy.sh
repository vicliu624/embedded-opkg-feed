#!/usr/bin/env bash
# r10 must rebuild legacy source recipes from the immutable cache when offline;
# it may not download a historical IPK, clone a sibling checkout, or let
# Buildroot fall back to its upstream mirrors.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

for package in audacious-core audacious-plugins libmgba sdl2 sdl2-ttf tdvp-gba tdvp-netsurf; do
  test -f "$repo_root/packages/$package/source.lock"
done
grep -Fq 'reuse_published_payloads=0' "$repo_root/scripts/build-all.sh"
grep -Fq 'tdvp_unpack_locked_source_archive()' "$repo_root/support/source-archive-library.sh"

for package in libmgba sdl2 sdl2-ttf tdvp-gba; do
  build="$repo_root/packages/$package/build.sh"
  grep -Fq 'tdvp_unpack_locked_source_archive' "$build"
  if grep -Eq 'git clone|tdvp_verify_git_source' "$build"; then
    echo "$package retains a mutable Git source path" >&2
    exit 1
  fi
done

for package in audacious-core audacious-plugins tdvp-netsurf; do
  build="$repo_root/packages/$package/build.sh"
  grep -Fq 'tdvp_prepare_locked_buildroot_download' "$build"
  grep -Fq 'BR2_PRIMARY_SITE_ONLY=y' "$build"
done

echo 'r10 offline legacy source policy: PASS'
