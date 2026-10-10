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
work=$(mktemp -d /tmp/tdvp-x265-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
common=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$sdk_root/toolchain.cmake" \
  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="$CFLAGS -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libx265" \
  -DCMAKE_CXX_FLAGS="$CXXFLAGS -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libx265" \
  -DCMAKE_C_FLAGS_RELEASE= -DCMAKE_CXX_FLAGS_RELEASE= -DCMAKE_SKIP_RPATH=ON \
  -DENABLE_ASSEMBLY=OFF -DENABLE_CLI=OFF -DENABLE_LIBNUMA=OFF)
cmake -S "$source_root/source" -B "$work/build12" "${common[@]}" \
  -DHIGH_BIT_DEPTH=ON -DMAIN12=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF
cmake --build "$work/build12" --parallel "${TDVP_JOBS:-4}"
cmake -S "$source_root/source" -B "$work/build10" "${common[@]}" \
  -DHIGH_BIT_DEPTH=ON -DEXPORT_C_API=OFF -DENABLE_SHARED=OFF
cmake --build "$work/build10" --parallel "${TDVP_JOBS:-4}"
mkdir "$work/build8"
ln -s "$work/build10/libx265.a" "$work/build8/libx265_main10.a"
ln -s "$work/build12/libx265.a" "$work/build8/libx265_main12.a"
cmake -S "$source_root/source" -B "$work/build8" "${common[@]}" \
  -DENABLE_SHARED=ON -DLINKED_10BIT=ON -DLINKED_12BIT=ON \
  '-DEXTRA_LIB=x265_main10.a;x265_main12.a' "-DEXTRA_LINK_FLAGS=-L$work/build8"
cmake --build "$work/build8" --parallel "${TDVP_JOBS:-4}"
mv "$work/build8/libx265.a" "$work/build8/libx265_main.a"
# Match upstream build/linux/multilib.sh for static development consumers.
(cd "$work/build8" && "$sdk_root/bin/riscv64-unknown-linux-gnu-ar" -M <<'MRI'
CREATE libx265.a
ADDLIB libx265_main.a
ADDLIB libx265_main10.a
ADDLIB libx265_main12.a
SAVE
END
MRI
)
DESTDIR="$work/install" cmake --install "$work/build8"
# Upstream drops pthread from the generated private flags. Our glibc 2.33
# keeps libpthread separate, so static consumers still need this declaration.
pc="$work/install/usr/lib/pkgconfig/x265.pc"
[[ $(grep -c '^Libs.private:' "$pc") == 1 ]] || exit 66
sed -i '/^Libs.private:/s/$/ -pthread/' "$pc"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a "$work/install/usr/lib/"libx265.so.[0-9]* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
notice_args=()
while IFS= read -r -d '' file; do
  if grep -Eiq 'copyright|SPDX-License-Identifier' "$file"; then notice_args+=(--file "${file#"$source_root/"}"); fi
done < <(find "$source_root/source" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -print0)
python3 "$repo_root/support/extract-source-copyright-notices.py" "$source_root" \
  "$source_root/TDVP-COPYRIGHT-NOTICE" "${notice_args[@]}"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" \
  --license-file COPYING --license-file TDVP-COPYRIGHT-NOTICE
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
echo "libx265 multilib source payload ready: $payload"
