#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$repo_root/scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$repo_root/support/source-archive-library.sh"
source "$repo_root/support/elf-runtime-policy.sh"
work=$(mktemp -d /tmp/tdvp-libvpx-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/build"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
export CC="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc"
export CXX="$sdk_root/bin/riscv64-unknown-linux-gnu-g++"
export AR="$sdk_root/bin/riscv64-unknown-linux-gnu-ar"
export LD="$CC"
export RANLIB="$sdk_root/bin/riscv64-unknown-linux-gnu-ranlib"
export STRIP="$sdk_root/bin/riscv64-unknown-linux-gnu-strip"
export CFLAGS="--sysroot=$sdk_root/sysroot -march=rv64imafdc -mabi=lp64d -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libvpx"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="--sysroot=$sdk_root/sysroot -Wl,-rpath-link,$sdk_root/sysroot/usr/lib"
export PKG_CONFIG_SYSROOT_DIR="$sdk_root/sysroot"
export PKG_CONFIG_LIBDIR="$sdk_root/sysroot/usr/lib/pkgconfig:$sdk_root/sysroot/usr/share/pkgconfig"
export PKG_CONFIG_PATH=''
(cd "$work/build" && "$source_root/configure" --prefix=/usr --libdir=/usr/lib \
 --target=generic-gnu --enable-shared --disable-static --enable-pic \
 --enable-vp8 --enable-vp9 --enable-vp9-highbitdepth --disable-runtime-cpu-detect \
 --disable-unit-tests --disable-examples --disable-tools --disable-docs \
 --disable-install-docs --disable-install-bins --disable-webm-io \
 && make -j"${TDVP_JOBS:-2}" && make DESTDIR="$work/install" install)
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a "$work/install/usr/lib/"libvpx.so.[0-9]* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file LICENSE --license-file PATENTS --license-file AUTHORS
python3 "$repo_root/support/normalize-pkgconfig-build-paths.py" "$work/install" --sysroot "$sdk_root/sysroot"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
echo "libvpx runtime and development projection ready: $payload"
