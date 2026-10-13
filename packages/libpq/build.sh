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
[[ -f "$sdk_root/tdvp-sdk-manifest.json" && -d "${TDVP_FEED_STAGING_ROOT:?}/usr" ]] || exit 65
work=$(mktemp -d /tmp/tdvp-libpq-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/sysroot" "$work/build"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
source "$sdk_root/environment-setup.sh"
export CFLAGS="$CFLAGS --sysroot=$work/sysroot -march=rv64imafdc -mabi=lp64d -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libpq"
export CPPFLAGS="--sysroot=$work/sysroot -I$work/sysroot/usr/include"
export LDFLAGS="--sysroot=$work/sysroot -Wl,-rpath-link,$work/sysroot/usr/lib"
export PKG_CONFIG_SYSROOT_DIR="$work/sysroot"
export PKG_CONFIG_LIBDIR="$work/sysroot/usr/lib/pkgconfig:$work/sysroot/usr/share/pkgconfig"
export PKG_CONFIG_PATH=''
export PKG_CONFIG=/usr/bin/pkg-config
(cd "$work/build" && "$source_root/configure" \
 --host=riscv64-unknown-linux-gnu --build="$(gcc -dumpmachine)" \
 --prefix=/usr --libdir=/usr/lib --with-ssl=openssl --with-gssapi --with-ldap \
 --without-icu --without-readline --disable-rpath \
 && make -C src/interfaces/libpq -j"${TDVP_JOBS:-2}" \
 && make -C src/interfaces/libpq DESTDIR="$work/install" install \
 && make -C src/include DESTDIR="$work/install" install)
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a "$work/install/usr/lib/"libpq.so.[0-9]* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file COPYRIGHT
python3 "$repo_root/support/normalize-pkgconfig-build-paths.py" "$work/install" --sysroot "$work/sysroot" --sysroot "$sdk_root/sysroot"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
echo "PostgreSQL client runtime and development projection ready: $payload"
