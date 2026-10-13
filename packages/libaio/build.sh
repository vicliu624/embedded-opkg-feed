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
work=$(mktemp -d /tmp/tdvp-libaio-build.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
cd "$source_root"
export CFLAGS="$CFLAGS -fPIC -O1"
make -j"${TDVP_JOBS:-2}" CC="$CC" AR="$AR" RANLIB="$RANLIB"
install_root="$work/install"
make DESTDIR="$install_root" prefix=/usr libdir=/usr/lib install
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib"
cp -a "$install_root/usr/lib/"libaio.so* "$payload_dir/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
printf 'libaio source payload ready: %s\n' "$payload_dir"
