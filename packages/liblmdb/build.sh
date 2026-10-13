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
work=$(mktemp -d /tmp/tdvp-liblmdb-build.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
library_root="$source_root/libraries/liblmdb"
make -C "$library_root" -j"${TDVP_JOBS:-2}" liblmdb.so CC="$CC" AR="$AR" OPT="$CFLAGS -fPIC -O1" SOLIBS='-Wl,-soname,liblmdb.so'
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr/include"
cp "$library_root/liblmdb.so" "$payload_dir/usr/lib/"
cp "$library_root/liblmdb.so" "$TDVP_FEED_STAGING_ROOT/usr/lib/"
cp "$library_root/lmdb.h" "$TDVP_FEED_STAGING_ROOT/usr/include/"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig"
cp "$package_dir/files/lmdb.pc" "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
python3 "$package_dir/../../support/extract-source-copyright-notices.py" "$source_root" "$source_root/TDVP-COPYRIGHT-NOTICE" \
  --file libraries/liblmdb/mdb.c --file libraries/liblmdb/midl.c \
  --file libraries/liblmdb/lmdb.h --file libraries/liblmdb/midl.h
IFS=' ' read -r -a notice_files <<< "$PACKAGE_LICENSE_FILES"
notice_args=()
for notice in "${notice_files[@]}"; do notice_args+=(--license-file "$notice"); done
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" "${notice_args[@]}"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
printf 'liblmdb source payload ready: %s\n' "$payload_dir"
