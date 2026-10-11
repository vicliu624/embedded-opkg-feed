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
[[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 65
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-gudev-source.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
python3 - "$sdk_root" "$work/cross.ini" <<'PY'
import json, shutil, sys
from pathlib import Path
sdk = Path(sys.argv[1]).resolve(strict=True)
text = '[binaries]\n'
for key, tool in (('c', 'gcc'), ('ar', 'ar'), ('strip', 'strip')):
    text += key + ' = ' + json.dumps(str(sdk / 'bin' / ('riscv64-unknown-linux-gnu-' + tool))).replace('"', "'") + '\n'
for tool in ('glib-mkenums', 'glib-genmarshal'):
    script = sdk / 'sysroot/usr/bin' / tool
    assert script.is_file() and script.read_bytes().startswith(b'#!')
    text += tool + ' = ' + json.dumps([shutil.which('python3'), str(script)]).replace('"', "'") + '\n'
text += "pkg-config = '/usr/bin/pkg-config'\n[properties]\nneeds_exe_wrapper = true\n"
text += 'sys_root = ' + json.dumps(str(sdk / 'sysroot')).replace('"', "'") + '\n'
text += "[host_machine]\nsystem = 'linux'\ncpu_family = 'riscv64'\ncpu = 'riscv64'\nendian = 'little'\n"
Path(sys.argv[2]).write_text(text)
PY
export PKG_CONFIG_SYSROOT_DIR="$sdk_root/sysroot"
export PKG_CONFIG_LIBDIR="$sdk_root/sysroot/usr/lib/pkgconfig:$sdk_root/sysroot/usr/share/pkgconfig"
export PKG_CONFIG_PATH=''
meson setup "$work/build" "$source_root" --cross-file "$work/cross.ini" --wrap-mode=nodownload \
 --prefix=/usr --libdir=lib --buildtype=plain --default-library=shared \
 "-Dc_args=--sysroot=$sdk_root/sysroot -march=rv64imafdc -mabi=lp64d -fPIC -O1" \
 "-Dc_link_args=--sysroot=$sdk_root/sysroot -Wl,-rpath-link,$sdk_root/sysroot/usr/lib" \
 -Dtests=disabled -Dintrospection=disabled -Dvapi=disabled -Dgtk_doc=false
meson compile -C "$work/build" -j "${TDVP_JOBS:-4}"
DESTDIR="$work/install" meson install -C "$work/build" --no-rebuild
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$work/install/usr/lib/"libgudev-1.0.so.[0-9]* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload"
python3 "$repo_root/support/normalize-pkgconfig-build-paths.py" "$work/install" --sysroot "$sdk_root/sysroot"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
echo "libgudev runtime and development ready: $payload"
