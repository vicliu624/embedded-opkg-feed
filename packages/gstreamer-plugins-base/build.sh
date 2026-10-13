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
work=$(mktemp -d /tmp/tdvp-gst-base-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/sysroot"
cp -a "$sdk_root/sysroot/." "$work/sysroot/"
cp -a "$TDVP_FEED_STAGING_ROOT/." "$work/sysroot/"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
patch --batch --forward -d "$source_root" -p1 < "$package_dir/ogg-push-segment-seqnum.patch"
python3 - "$sdk_root" "$work/sysroot" "$work/cross.ini" "$work/native.ini" <<'PY'
import json, shutil, sys
from pathlib import Path
sdk, sysroot = (Path(value).resolve(strict=True) for value in sys.argv[1:3])
text = '[binaries]\n'
for key, tool in (('c', 'gcc'), ('cpp', 'g++'), ('ar', 'ar'), ('strip', 'strip')):
    text += key + ' = ' + json.dumps(str(sdk / 'bin' / ('riscv64-unknown-linux-gnu-' + tool))).replace('"', "'") + '\n'
native = '[binaries]\n'
for tool in ('glib-mkenums', 'glib-genmarshal'):
    script = sdk / 'sysroot/usr/bin' / tool
    assert script.is_file() and script.read_bytes().startswith(b'#!')
    native += tool + ' = ' + json.dumps([shutil.which('python3'), str(script)]).replace('"', "'") + '\n'
text += native.removeprefix('[binaries]\n')
text += "pkg-config = '/usr/bin/pkg-config'\n[properties]\nneeds_exe_wrapper = true\n"
text += 'sys_root = ' + json.dumps(str(sysroot)).replace('"', "'") + '\n'
text += "[host_machine]\nsystem = 'linux'\ncpu_family = 'riscv64'\ncpu = 'riscv64'\nendian = 'little'\n"
Path(sys.argv[3]).write_text(text)
Path(sys.argv[4]).write_text(native)
PY
export PKG_CONFIG_SYSROOT_DIR="$work/sysroot"
export PKG_CONFIG_LIBDIR="$work/sysroot/usr/lib/pkgconfig:$work/sysroot/usr/share/pkgconfig"
export PKG_CONFIG_PATH=''
meson setup "$work/build" "$source_root" --cross-file "$work/cross.ini" --native-file "$work/native.ini" \
 --wrap-mode=nodownload --prefix=/usr --libdir=lib --buildtype=plain --default-library=shared \
 "-Dc_args=--sysroot=$work/sysroot -march=rv64imafdc -mabi=lp64d -fPIC -O1 -ffile-prefix-map=$work=/usr/src/tdvp/gstreamer-plugins-base" \
 "-Dc_link_args=--sysroot=$work/sysroot -Wl,-rpath-link,$work/sysroot/usr/lib" \
 -Dalsa=enabled -Dogg=enabled -Dvorbis=enabled -Dopus=enabled -Dpango=enabled \
 -Dgl=disabled -Ddrm=disabled -Dx11=disabled -Dxshm=disabled -Dxvideo=disabled -Dxi=disabled \
 -Dorc=disabled -Dorc-compiler=disabled -Dtheora=enabled -Dtremor=disabled \
 -Dcdparanoia=disabled -Dlibvisual=disabled -Diso-codes=disabled -Dqt5=disabled \
 -Dtests=disabled -Dexamples=disabled -Dtools=disabled -Dintrospection=disabled -Ddoc=disabled -Dnls=disabled
meson compile -C "$work/build" -j "${TDVP_JOBS:-4}"
DESTDIR="$work/install" meson install -C "$work/build" --no-rebuild
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a "$work/install/usr/lib/"libgst*.so.[0-9]* "$payload/usr/lib/"
cp -a "$work/install/usr/lib/gstreamer-1.0" "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file COPYING
python3 "$repo_root/support/normalize-pkgconfig-build-paths.py" "$work/install" --sysroot "$work/sysroot" --sysroot "$sdk_root/sysroot"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
cp -a "$payload/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
echo "GStreamer base plugin runtime and development projection ready: $payload"
