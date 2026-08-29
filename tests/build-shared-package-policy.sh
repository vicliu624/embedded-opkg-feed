#!/usr/bin/env bash
# Portable policy regression test: applications cannot claim /usr/lib, while
# reviewed shared-library metadata can package a SONAME file without touching a
# base-image-owned path.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

make_recipe() {
  local directory=$1
  local name=$2
  local kind=$3
  mkdir -p -- "$directory/root/usr/lib"
  printf 'fixture\n' >"$directory/root/usr/lib/libfixture.so.1"
  cat >"$directory/package.env" <<EOF
PACKAGE='$name'
VERSION='1-1'
PACKAGE_ARCH='riscv64'
MAINTAINER='TDVP Test <tests@example.invalid>'
DESCRIPTION='Portable package policy fixture'
SUPPORTED_PLATFORMS='tdvp-k230-r1'
PACKAGE_KIND='$kind'
PACKAGE_RELEASES='r2'
PACKAGE_DEPENDS=''
PACKAGE_BUILD_DEPENDS=''
EOF
}

shared_recipe="$work_root/shared"
application_recipe="$work_root/application"
base_root="$work_root/base"
mkdir -p -- "$base_root/usr/lib"
make_recipe "$shared_recipe" fixture-shared shared-library
make_recipe "$application_recipe" fixture-application application

TDVP_FEED_BASE_ROOT="$base_root" \
  "$repo_root/scripts/build-ipk.sh" --platform tdvp-k230-r1 "$shared_recipe" "$work_root/feed"
ar p "$work_root/feed/fixture-shared_1-1_riscv64.ipk" control.tar.gz | \
  tar -xzO ./control | grep -qx 'Section: libraries'

if TDVP_FEED_BASE_ROOT="$base_root" \
  "$repo_root/scripts/build-ipk.sh" --platform tdvp-k230-r1 "$application_recipe" "$work_root/application-feed"; then
  echo 'application package unexpectedly wrote /usr/lib' >&2
  exit 1
fi

touch "$base_root/usr/lib/libfixture.so.1"
if TDVP_FEED_BASE_ROOT="$base_root" \
  "$repo_root/scripts/build-ipk.sh" --platform tdvp-k230-r1 "$shared_recipe" "$work_root/collision-feed"; then
  echo 'shared library unexpectedly replaced a base-image file' >&2
  exit 1
fi

echo 'shared package policy test passed'
