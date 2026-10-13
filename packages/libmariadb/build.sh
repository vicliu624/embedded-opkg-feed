#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libmariadb.so.[0-9]*' \
 -DINSTALL_LIBDIR=lib -DINSTALL_INCLUDEDIR=include/mariadb \
 -DINSTALL_PLUGINDIR=lib/mariadb/plugin -DWITH_SSL=OPENSSL \
 -DWITH_EXTERNAL_ZLIB=ON -DWITH_CURL=ON -DWITH_DYNCOL=ON \
 -DDEFAULT_SSL_VERIFY_SERVER_CERT=ON -DWITH_UNIT_TESTS=OFF \
 -DWITH_TOOLS=OFF -DWITH_DOCS=OFF -DGSSAPI_LIBS=gssapi_krb5 \
 -DGSSAPI_FLAVOR=MIT -DCLIENT_PLUGIN_AUTH_GSSAPI_CLIENT=DYNAMIC
payload=$(cd -- "$package_dir/root" && pwd -P)
plugin_dir="$TDVP_FEED_STAGING_ROOT/usr/lib/mariadb/plugin"
for plugin in dialog client_ed25519 caching_sha2_password sha256_password auth_gssapi_client; do
 [[ -f "$plugin_dir/$plugin.so" ]] || { echo "MariaDB authentication plugin missing: $plugin" >&2; exit 66; }
done
mkdir -p "$payload/usr/lib/mariadb/plugin"
cp -a "$plugin_dir/"*.so "$payload/usr/lib/mariadb/plugin/"
source "$package_dir/../../support/elf-runtime-policy.sh"
source "$package_dir/../../support/source-archive-library.sh"
header_work=$(mktemp -d /tmp/tdvp-mariadb-public-header.XXXXXX)
trap 'rm -rf -- "$header_work"' EXIT
mkdir "$header_work/source"
header_source=$(tdvp_unpack_locked_source_archive "$package_dir" "$header_work/source")
# The public mysql/client_plugin.h includes this header, omitted by upstream install.
cp -a "$header_source/include/ma_compress.h" "$TDVP_FEED_STAGING_ROOT/usr/include/mariadb/"
patch --directory="$TDVP_FEED_STAGING_ROOT/usr/include/mariadb" -p1 --fuzz=0 --forward \
 < "$package_dir/public-compression-header.patch"
tdvp_assert_direct_archive_elfs "$4/bin/riscv64-unknown-linux-gnu-readelf" "$4/bin/riscv64-unknown-linux-gnu-strip" "$payload"
cp -a "$payload/usr/lib/mariadb/plugin/." "$plugin_dir/"
echo "MariaDB client runtime, authentication plugins and development projection ready: $payload"
