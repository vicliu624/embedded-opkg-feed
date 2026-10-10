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
work=$(mktemp -d /tmp/tdvp-dav1d-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
# Generated Meson configuration is a build artifact, not a host compiler fallback.
python3 - "$sdk_root" "$work/cross.ini" <<'PY'
import json
from pathlib import Path
import sys
sdk = Path(sys.argv[1]).resolve(strict=True)
def quote(value):
    return json.dumps(str(value)).replace('"', "'")
text = '[binaries]\n'
for key, command in (('c', 'gcc'), ('cpp', 'g++'), ('ar', 'ar'), ('strip', 'strip')):
    text += key + ' = ' + quote(sdk / 'bin' / ('riscv64-unknown-linux-gnu-' + command)) + '\n'
text += "pkgconfig = '/usr/bin/pkg-config'\n[properties]\nneeds_exe_wrapper = true\n"
text += 'sys_root = ' + quote(sdk / 'sysroot') + '\n'
text += "[host_machine]\nsystem = 'linux'\ncpu_family = 'riscv64'\ncpu = 'riscv64'\nendian = 'little'\n"
Path(sys.argv[2]).write_text(text)
PY
export PKG_CONFIG_SYSROOT_DIR="$sdk_root/sysroot"
export PKG_CONFIG_LIBDIR="$sdk_root/sysroot/usr/lib/pkgconfig:$sdk_root/sysroot/usr/share/pkgconfig"
export PKG_CONFIG_PATH=''
meson setup "$work/build" "$source_root" --cross-file "$work/cross.ini" \
  --prefix=/usr --libdir=lib --buildtype=plain --default-library=shared \
  "-Dc_args=--sysroot=$sdk_root/sysroot -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libdav1d" \
  "-Dc_link_args=--sysroot=$sdk_root/sysroot" \
  -Denable_asm=false -Denable_tools=false -Denable_tests=false \
  -Denable_examples=false -Denable_docs=false -Dtestdata_tests=false
meson compile -C "$work/build" -j "${TDVP_JOBS:-4}"
DESTDIR="$work/install" meson install -C "$work/build" --no-rebuild
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a "$work/install/usr/lib/"libdav1d.so.[0-9]* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file COPYING
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
echo "dav1d source payload ready: $payload"
