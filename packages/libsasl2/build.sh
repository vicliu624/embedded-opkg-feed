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
work=$(mktemp -d /tmp/tdvp-sasl-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/sysroot"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
for source_patch in "$package_dir/patches/"*.patch; do
  patch --directory="$source_root" -p1 --fuzz=0 --forward --dry-run < "$source_patch"
  patch --directory="$source_root" -p1 --fuzz=0 --forward < "$source_patch"
done
cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
# Shared consumers use ELF/pkg-config; inherited libtool archives can inject
# private dependency install paths into the new runtime's string table.
[[ $(realpath -e "$work/sysroot") == "$work/sysroot" ]] || exit 65
find "$work/sysroot/usr" -type f -name '*.la' -delete
[[ -f "$work/sysroot/usr/include/gssapi/gssapi.h" && -f "$work/sysroot/usr/include/gdbm.h" ]] || exit 66
source "$sdk_root/environment-setup.sh"
export CC="$CC --sysroot=$work/sysroot" CXX="$CXX --sysroot=$work/sysroot"
export CFLAGS="$CFLAGS -fPIC -O1" CPPFLAGS="-I$work/sysroot/usr/include"
export LDFLAGS="-Wl,-rpath-link,$work/sysroot/usr/lib -L$work/sysroot/usr/lib"
export PKG_CONFIG_SYSROOT_DIR="$work/sysroot" PKG_CONFIG_LIBDIR="$work/sysroot/usr/lib/pkgconfig" PKG_CONFIG_PATH=''
"$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" --sysroot="$work/sysroot" \
  "$package_dir/gssapi-spnego-probe.c" -Wl,-rpath-link,"$work/sysroot/usr/lib" \
  -lgssapi_krb5 -o "$work/spnego-probe"
qemu-riscv64 -L "$work/sysroot" -E "LD_LIBRARY_PATH=$work/sysroot/usr/lib" "$work/spnego-probe"
cd "$source_root"
autoreconf -fi
andrew_cv_runpath_switch=none ac_cv_gssapi_supports_spnego=yes ./configure --host=riscv64-unknown-linux-gnu \
  --prefix=/usr --libdir=/usr/lib --enable-shared --disable-static \
  --with-plugindir=/usr/lib/sasl2 --with-saslauthd=no --with-ldap=no \
  --with-gss_impl=mit --enable-gssapi --with-dblib=gdbm --with-openssl="$work/sysroot/usr"
# The native generator must not inherit target headers through CPPFLAGS.
make -C include makemd5 CPPFLAGS=
make -j"${TDVP_JOBS:-4}"
make DESTDIR="$work/install" install
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
strip_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-strip"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib/sasl2"
cp -a "$work/install/usr/lib/"libsasl2.so.[0-9]* "$payload/usr/lib/"
cp -a "$work/install/usr/lib/sasl2/"*.so* "$payload/usr/lib/sasl2/"
while IFS= read -r -d '' elf; do
  tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$elf"
  tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$elf"
  "$strip_tool" --strip-unneeded "$elf"
  strings "$elf" > "$work/runtime-strings.txt"
  if grep -Fq -- "$work" "$work/runtime-strings.txt"; then
    echo "Private build path retained in SASL runtime: $elf" >&2
    exit 67
  fi
done < <(find "$payload/usr/lib" -type f -print0)
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file COPYING
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/include" "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig"
cp -a "$work/install/usr/include/." "$TDVP_FEED_STAGING_ROOT/usr/include/"
cp -a "$work/install/usr/lib/pkgconfig/." "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
ln -sfn libsasl2.so.3 "$TDVP_FEED_STAGING_ROOT/usr/lib/libsasl2.so"
echo "libsasl2 source payload ready: $payload"
