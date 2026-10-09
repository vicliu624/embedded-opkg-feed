#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
[[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 64
[[ -f "$sdk_root/tdvp-sdk-manifest.json" ]] || exit 65
work=$(mktemp -d /tmp/tdvp-lz4-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
make -C "$source_root/lib" -j"${TDVP_JOBS:-4}" \
  CC="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
  AR="$sdk_root/bin/riscv64-unknown-linux-gnu-ar" \
  CFLAGS="$CFLAGS -fPIC -O1" BUILD_STATIC=no BUILD_SHARED=yes
make -C "$source_root/lib" PREFIX=/usr LIBDIR=/usr/lib \
  DESTDIR="$work/install" BUILD_STATIC=no BUILD_SHARED=yes install
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib"
cp -a "$work/install/usr/lib/"liblz4.so* "$payload_dir/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" \
  "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
printf '%s\n' "liblz4 source payload ready: $payload_dir"
