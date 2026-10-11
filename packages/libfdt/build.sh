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
work=$(mktemp -d /tmp/tdvp-libfdt-build.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
make -C "$source_root" -j"${TDVP_JOBS:-2}" libfdt CC="$CC" AR="$AR" NO_PYTHON=1 NO_YAML=1 CFLAGS="$CFLAGS -fPIC -O1"
install_root="$work/install"
make -C "$source_root" DESTDIR="$install_root" PREFIX=/usr LIBDIR=/usr/lib INCLUDEDIR=/usr/include NO_PYTHON=1 NO_YAML=1 install-lib install-includes
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$install_root/usr/lib/"libfdt.so* "$payload_dir/usr/lib/"
cp -a "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
notice_source_args=()
for source_file in "$source_root/libfdt/"*.c "$source_root/libfdt/"*.h; do
  notice_source_args+=(--file "${source_file#"$source_root/"}")
done
python3 "$package_dir/../../support/extract-source-copyright-notices.py" "$source_root" "$source_root/TDVP-COPYRIGHT-NOTICE" "${notice_source_args[@]}"
IFS=' ' read -r -a notice_files <<< "$PACKAGE_LICENSE_FILES"
notice_args=()
for notice in "${notice_files[@]}"; do notice_args+=(--license-file "$notice"); done
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" "${notice_args[@]}"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
printf 'libfdt source payload ready: %s\n' "$payload_dir"
