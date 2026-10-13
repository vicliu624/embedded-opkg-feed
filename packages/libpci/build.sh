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
stage_root=${TDVP_FEED_STAGING_ROOT:?}
[[ -d "$stage_root" && ! -L "$stage_root" ]] || exit 64
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-pciutils-build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
options=(HOST=riscv64-linux SHARED=yes PREFIX=/usr LIBDIR=/usr/lib
  CC="$CC" AR="$AR" RANLIB="$RANLIB" PKG_CONFIG="$PKG_CONFIG"
  "OPT=$CFLAGS -fPIC -O1 -ffile-prefix-map=$source_root=/usr/src/pciutils"
  "LDFLAGS=$LDFLAGS" ZLIB=yes DNS=yes HWDB=yes LIBKMOD=yes)
make -C "$source_root" -j"${TDVP_JOBS:-2}" "${options[@]}" lib/libpci.so.3.15.0
make -C "$source_root" "${options[@]}" DESTDIR="$work/install" install-lib
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$payload_dir/usr/share" "$stage_root/usr/share"
cp -a "$work/install/usr/lib/"libpci.so.[0-9]* "$payload_dir/usr/lib/"
gzip -n -c "$source_root/pci.ids" > "$payload_dir/usr/share/pci.ids.gz"
cp -a "$work/install/usr/." "$stage_root/usr/"
cp "$payload_dir/usr/share/pci.ids.gz" "$stage_root/usr/share/pci.ids.gz"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
notice_args=()
while IFS= read -r file; do notice_args+=(--file "${file#"$source_root/"}"); done < <(grep -ilE 'copyright|SPDX-License-Identifier' "$source_root/lib/"*.c "$source_root/lib/"*.h)
python3 "$package_dir/../../support/extract-source-copyright-notices.py" "$source_root" "$source_root/TDVP-COPYRIGHT-NOTICE" "${notice_args[@]}"
sed -n '1,/^# Vendors/p' "$source_root/pci.ids" > "$source_root/TDVP-PCI-ID-NOTICE"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" --license-file COPYING --license-file TDVP-COPYRIGHT-NOTICE --license-file TDVP-PCI-ID-NOTICE
mkdir -p "$stage_root/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$stage_root/usr/share/licenses/"
printf 'libpci library, identifier database and development staging ready: %s\n' "$payload_dir"
