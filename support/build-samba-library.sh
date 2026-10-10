#!/usr/bin/env bash
# Build the locked standalone C libraries, using target-executed Waf probes.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 2 ]] || exit 64
package_dir=$(cd -- "$1" && pwd)
sdk_root=$2
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
tdvp_require_k230_sdk "$sdk_root"
[[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 65
case "$PACKAGE" in libtalloc) component=talloc;; libtevent) component=tevent;; libtdb) component=tdb;; *) exit 66;; esac
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-samba-library.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/sysroot"
archive=$(tdvp_source_archive_locked_file "$package_dir" "$component-$SOURCE_REVISION.tar.gz")
tar -xf "$archive" -C "$work/source"
source_root="$work/source/$component-$SOURCE_REVISION"
[[ -d "$source_root" && ! -L "$source_root" ]] || exit 67
cp -a --reflink=auto "$TDVP_K230_SYSROOT/." "$work/sysroot/"
if [[ -d "$TDVP_FEED_STAGING_ROOT/usr" ]]; then
  cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
fi
source "$sdk_root/environment-setup.sh"
export CC="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc --sysroot=$work/sysroot"
# Waf uses PKGCONFIG, while Autotools uses PKG_CONFIG.
export PKGCONFIG=/usr/bin/pkg-config
export PKG_CONFIG_SYSROOT_DIR="$work/sysroot"
export PKG_CONFIG_LIBDIR="$work/sysroot/usr/lib/pkgconfig:$work/sysroot/usr/share/pkgconfig"
unset PKG_CONFIG_PATH
export LDFLAGS="-L$work/sysroot/usr/lib -Wl,-rpath-link,$work/sysroot/usr/lib"
options=()
[[ "$PACKAGE" != libtevent ]] || options+=(--bundled-libraries='!talloc')
(
  cd "$source_root"
  ./configure --prefix=/usr --libdir=/usr/lib --with-libiconv="$work/sysroot/usr" \
    --disable-python --disable-rpath --disable-rpath-install --disable-rpath-private-install \
    --cross-compile --cross-execute="qemu-riscv64 -L $work/sysroot" "${options[@]}"
  make -j"${TDVP_JOBS:-2}"
  make DESTDIR="$work/install" install
)
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$work/install/usr/lib/""$PACKAGE".so.[0-9]* "$payload_dir/usr/lib/"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
tdvp_assert_direct_archive_elfs "$TDVP_K230_READELF" "$TDVP_K230_STRIP" "$payload_dir"
gpl=$(tdvp_source_archive_locked_file "$package_dir" GPL-3.0.txt)
cp "$gpl" "$source_root/GPL-3.0.txt"
notice_args=()
notice_files=("$source_root/"*.c "$source_root/"*.h)
if [[ "$PACKAGE" == libtdb ]]; then
  notice_files+=("$source_root/common/"*.c "$source_root/include/"*.h "$source_root/lib/replace/"*.c "$source_root/lib/replace/"*.h)
fi
for file in "${notice_files[@]}"; do
  [[ -f "$file" ]] || continue
  if grep -qi copyright "$file"; then notice_args+=(--file "${file#"$source_root/"}"); fi
done
python3 "$package_dir/../../support/extract-source-copyright-notices.py" "$source_root" "$source_root/TDVP-COPYRIGHT-NOTICE" "${notice_args[@]}"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" \
  --license-file LICENSE --license-file GPL-3.0.txt --license-file TDVP-COPYRIGHT-NOTICE
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
printf '%s standalone C library payload ready: %s\n' "$PACKAGE" "$payload_dir"
