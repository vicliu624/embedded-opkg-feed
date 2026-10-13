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
[[ -f "$sdk_root/tdvp-sdk-manifest.json" && -d "$TDVP_FEED_STAGING_ROOT/usr" ]] || exit 65
work=$(mktemp -d /tmp/tdvp-ldap-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/sysroot"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
[[ -f "$work/sysroot/usr/include/sasl/sasl.h" ]] || exit 66
for probe in pthread-select libc-memcmp; do
  "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" --sysroot="$work/sysroot" \
    -O1 -fno-builtin-memcmp -pthread "$package_dir/$probe-probe.c" -o "$work/$probe"
  qemu-riscv64 -L "$work/sysroot" "$work/$probe"
done
source "$sdk_root/environment-setup.sh"
export CC="$CC --sysroot=$work/sysroot" CFLAGS="$CFLAGS -fPIC -O1"
export CPPFLAGS="-I$work/sysroot/usr/include" LDFLAGS="-Wl,-rpath-link,$work/sysroot/usr/lib -L$work/sysroot/usr/lib"
export PKG_CONFIG_SYSROOT_DIR="$work/sysroot" PKG_CONFIG_LIBDIR="$work/sysroot/usr/lib/pkgconfig" PKG_CONFIG_PATH=''
cd "$source_root"
ac_cv_func_memcmp_working=yes ./configure --host=riscv64-unknown-linux-gnu \
  --prefix=/usr --libdir=/usr/lib --enable-shared --disable-static --disable-slapd \
  --disable-lloadd --with-tls=openssl --with-cyrus-sasl=yes --with-yielding_select=yes \
  --with-sysroot="$work/sysroot"
patch --directory="$source_root" -p1 --fuzz=0 --forward < "$package_dir/libtool-no-runtime-path.patch"
make depend
make -j"${TDVP_JOBS:-4}"
# Runtime packages need the verified target libraries, not libtool relinking
# against /usr/lib on the host. Preserve public development interfaces separately.
make -C include DESTDIR="$work/install" install
mkdir -p "$work/install/usr/lib/pkgconfig"
cp libraries/libldap/ldap.pc libraries/liblber/lber.pc "$work/install/usr/lib/pkgconfig/"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a libraries/libldap/.libs/libldap.so.[0-9]* libraries/liblber/.libs/liblber.so.[0-9]* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
while IFS= read -r -d '' elf; do
  strings "$elf" > "$work/runtime-strings.txt"
  if grep -Fq -- "$work" "$work/runtime-strings.txt"; then
    echo "Private build path retained in LDAP runtime: $elf" >&2
    exit 67
  fi
done < <(find "$payload/usr/lib" -type f -print0)
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file LICENSE --license-file COPYRIGHT
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/include" "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig"
cp -a "$work/install/usr/include/." "$TDVP_FEED_STAGING_ROOT/usr/include/"
cp -a "$work/install/usr/lib/pkgconfig/." "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
ln -sfn libldap.so.2 "$TDVP_FEED_STAGING_ROOT/usr/lib/libldap.so"
ln -sfn liblber.so.2 "$TDVP_FEED_STAGING_ROOT/usr/lib/liblber.so"
echo "libldap source payload ready: $payload"
