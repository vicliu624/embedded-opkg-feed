#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
sdk_root=$4
[[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 64
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-keyutils-build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
patch --batch --forward -d "$source_root" -p1 < "$package_dir/patches/0001-defer-rpm-only-probes.patch"
source "$sdk_root/environment-setup.sh"
make -C "$source_root" -j"${TDVP_JOBS:-2}" CC="$CC" AR="$AR" \
  CFLAGS="$CFLAGS -fPIC -ffile-prefix-map=$source_root=/usr/src/keyutils" \
  LDFLAGS="$LDFLAGS" LIBDIR=/usr/lib USRLIBDIR=/usr/lib BUILDFOR= \
  'VCPPFLAGS=-DPKGBUILD=\"source-locked\" -DPKGVERSION=\"keyutils-1.6.3\" -DAPIVERSION=\"libkeyutils-1.10\"' \
  libkeyutils.so libkeyutils.a pkgconfig
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig" "$TDVP_FEED_STAGING_ROOT/usr/include"
cp -a "$source_root/"libkeyutils.so.[0-9]* "$payload_dir/usr/lib/"
cp -a "$source_root/"libkeyutils.so* "$source_root/libkeyutils.a" "$TDVP_FEED_STAGING_ROOT/usr/lib/"
cp "$source_root/keyutils.h" "$TDVP_FEED_STAGING_ROOT/usr/include/"
cp "$source_root/libkeyutils.pc" "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
python3 "$package_dir/../../support/extract-source-copyright-notices.py" "$source_root" "$source_root/TDVP-COPYRIGHT-NOTICE" --file keyutils.c --file keyutils.h
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" --license-file LICENCE.LGPL --license-file TDVP-COPYRIGHT-NOTICE
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
printf 'keyutils runtime and development staging ready: %s\n' "$payload_dir"
