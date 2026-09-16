#!/usr/bin/env bash
set -Eeuo pipefail
package_dir=$1
sdk_root=$2
component=$(basename "$package_dir")
source "$package_dir/../../support/published-sdk-build.sh"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
install_root=$(mktemp -d)
trap 'rm -rf -- "$install_root"' EXIT
build_component=tdvp-audacious-plugins
[[ "$component" != audacious-core ]] || build_component=tdvp-audacious
tdvp_sdk_install "$package_dir" "$sdk_root" "$build_component" "$install_root"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
if [[ "$component" == audacious-core ]]; then
  for library in libaudcore.so.6 libaudtag.so.4 libaudgui.so.7; do
    test -e "$install_root/usr/lib/$library"
    cp -a "$install_root/usr/lib/$library"* "$payload/usr/lib/"
  done
  test -s "$TDVP_FEED_STAGING_ROOT/usr/lib/pkgconfig/audacious.pc"
else
  test -d "$install_root/usr/lib/audacious"
  cp -a "$install_root/usr/lib/audacious" "$payload/usr/lib/"
fi
install -Dm0644 "$install_root/usr/share/licenses/$build_component/COPYING" \
  "$payload/usr/share/licenses/$component/COPYING"
while IFS= read -r -d '' elf; do
  tdvp_remove_elf_runtime_search_paths "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$elf"
done < <(find "$payload/usr/lib" -type f -name '*.so*' -print0)
