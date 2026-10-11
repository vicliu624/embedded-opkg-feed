#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
[[ -f "$sdk_root/sysroot/usr/include/tdvp/tdvp_ai_abi.h" && -d ${TDVP_FEED_STAGING_ROOT:-} ]] || exit 65
source "$sdk_root/environment-setup.sh"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/share/licenses/libtdvp-ai-client"
install -m 0644 "$package_dir/LICENSE" "$payload/usr/share/licenses/libtdvp-ai-client/LICENSE"
mkdir -p "$payload/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig" "$TDVP_FEED_STAGING_ROOT/usr/include/tdvp"
"$CC" -std=c11 -O1 -fPIC -shared -Wall -Wextra -Werror \
  -I"$package_dir/src" "$package_dir/src/tdvp_ai_client.c" \
  -Wl,-soname,libtdvp-ai-client.so.1 -o "$payload/usr/lib/libtdvp-ai-client.so.1.0.0"
ln -s libtdvp-ai-client.so.1.0.0 "$payload/usr/lib/libtdvp-ai-client.so.1"
ln -s libtdvp-ai-client.so.1 "$payload/usr/lib/libtdvp-ai-client.so"
tdvp_assert_direct_archive_elfs "$READELF" "$STRIP" "$payload"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
cp "$package_dir/src/tdvp_ai_client.h" "$TDVP_FEED_STAGING_ROOT/usr/include/tdvp/"
printf 'prefix=/usr\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\nName: tdvp-ai-client\nDescription: Published CPU1 AI protocol client\nVersion: 0.1.0\nLibs: -L${libdir} -ltdvp-ai-client\nCflags: -I${includedir}\n' >"$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig/tdvp-ai-client.pc"
