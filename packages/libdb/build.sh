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
[[ -f "$sdk_root/tdvp-sdk-manifest.json" && -d "${TDVP_FEED_STAGING_ROOT:?}" ]] || exit 65
work=$(mktemp -d /tmp/tdvp-berkeleydb-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/build"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
export CFLAGS="$CFLAGS -march=rv64imafdc -mabi=lp64d -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libdb"
export CXXFLAGS="$CXXFLAGS -march=rv64imafdc -mabi=lp64d -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libdb"
(cd "$work/build" && "$source_root/dist/configure" \
 --host=riscv64-unknown-linux-gnu --build="$(gcc -dumpmachine)" \
 --prefix=/usr --libdir=/usr/lib --enable-shared --disable-static \
 --enable-cxx --enable-compat185 --enable-posixmutexes \
 --disable-java --disable-tcl \
 && make -j"${TDVP_JOBS:-2}" \
 && make DESTDIR="$work/install" install_include install_lib)
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
for library in libdb-18.1.so libdb_cxx-18.1.so; do
 [[ -f "$work/install/usr/lib/$library" ]] || exit 66
 cp -a "$work/install/usr/lib/$library" "$payload/usr/lib/"
done
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file LICENSE --license-file EXAMPLES-LICENSE
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/include" "$TDVP_FEED_STAGING_ROOT/usr/lib"
cp -a "$work/install/usr/include/." "$TDVP_FEED_STAGING_ROOT/usr/include/"
cp -a "$work/install/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
echo "Berkeley DB C/C++ runtime and development projection ready: $payload"
